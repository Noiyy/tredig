extends Area2D

const DEFAULT_GROW_INTERVAL := 1.8
const LAVA_SHADER := preload("res://scripts/lava_pixel.gdshader")
const LavaEdgeMath = preload("res://scripts/lava_edge_math.gd")

@export var tile_size := 16
## Koľko buniek shadera pripadá na jeden hrubý tile (16 px). 8 = bunka ~2 px, 4 = ~4 px.
@export_range(1, 32, 1) var lava_cells_per_tile := 8
@export var flow_speed := 0.42
@export var edge_height := 0.18
@export var grow_interval_sec := DEFAULT_GROW_INTERVAL
@export var damage_interval_sec := 1.0
@export var damage_per_tick := 10
## Zelený obrys + výplň = presný RectangleShape2D (damage / body_entered), nie orezaný shader.
@export var debug_show_hitbox := false:
	set(v):
		debug_show_hitbox = v
		if is_node_ready():
			_sync_hitbox_debug_overlay()

@onready var col_shape: CollisionShape2D = $CollisionShape2D
@onready var lava_rect: ColorRect = $ColorRect

var game_manager
var grow_timer: Timer
var damage_timer: Timer
var bodies_in_lava: Array = []   # hráči, ktorí sú aktuálne v láve

var last_interval_was_short: bool = false

var _bubble_particles: GPUParticles2D = null
var _hitbox_debug: Node2D = null

## Oblasť lávy v súradniciach Area2D (zhodná s pôvodným RectangleShape2D)
var _lava_bounds: Rect2 = Rect2()
var _column_shapes: Array[CollisionShape2D] = []
var _lava_time: float = 0.0
var _stub_edge_tex: ImageTexture = null
var _edge_img: Image = null
var _edge_tex: ImageTexture = null


func _ensure_stub_edge_tex() -> void:
	if _stub_edge_tex != null:
		return
	var im := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	im.set_pixel(0, 0, Color(0, 1, 0, 1))
	_stub_edge_tex = ImageTexture.create_from_image(im)


class HitboxDebugOverlay extends Node2D:
	func _init() -> void:
		z_index = 100

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var lava := get_parent()
		if lava == null or not lava.has_method("get_debug_collision_rects"):
			return
		var rects: Array = lava.get_debug_collision_rects()
		if rects.is_empty():
			return
		for rvariant in rects:
			var r: Rect2 = rvariant
			draw_rect(r, Color(0.2, 1.0, 0.35, 0.12), true)
			draw_rect(r, Color(0.25, 1.0, 0.45, 0.95), false, 2.0)
		var f := ThemeDB.fallback_font
		var fs := 11
		var first: Rect2 = rects[0]
		draw_string(f, first.position + Vector2(4.0, -4.0), "HITBOX (stĺpce = shader)", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.3, 1.0, 0.45, 0.95))


func _sync_hitbox_debug_overlay() -> void:
	if debug_show_hitbox:
		if _hitbox_debug == null:
			_hitbox_debug = HitboxDebugOverlay.new()
			add_child(_hitbox_debug)
	else:
		if _hitbox_debug != null:
			_hitbox_debug.queue_free()
			_hitbox_debug = null


func get_debug_collision_rects() -> Array:
	var out: Array = []
	for cs in _column_shapes:
		if cs == null or not is_instance_valid(cs) or cs.disabled:
			continue
		var sh := cs.shape as RectangleShape2D
		if sh == null:
			continue
		var half := sh.size * 0.5
		out.append(Rect2(cs.position - half, sh.size))
	return out


func _setup_bubble_particles() -> void:
	_bubble_particles = GPUParticles2D.new()
	_bubble_particles.name = "BubbleParticles"

	var pm := ParticleProcessMaterial.new()
	# emitter: tenký horizontálny pruh pozdĺž hornej hrany rectu
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	var rect_w: float = lava_rect.size.x if lava_rect.size.x > 0.0 else 640.0
	pm.emission_box_extents = Vector3(rect_w * 0.5, 1.0, 0.0)

	# smer: nahor s malým rozptylom
	pm.direction = Vector3(0.0, -1.0, 0.0)
	pm.spread = 18.0
	pm.initial_velocity_min = 12.0
	pm.initial_velocity_max = 36.0
	pm.gravity = Vector3(0.0, 8.0, 0.0)

	# veľkosť: 2–4 px (1 bunka mriežky)
	pm.scale_min = 2.0
	pm.scale_max = 4.0

	# farba: žltooranžová → priehľadná
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.85, 0.3, 0.9))
	grad.set_color(1, Color(0.9, 0.3, 0.05, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	pm.color_ramp = grad_tex

	pm.lifetime_randomness = 0.4

	_bubble_particles.process_material = pm
	_bubble_particles.amount = 28
	_bubble_particles.lifetime = 0.9
	_bubble_particles.explosiveness = 0.0
	_bubble_particles.randomness = 0.6
	_bubble_particles.fixed_fps = 0

	# poloha: na hornom okraji ColorRectu
	_bubble_particles.position = Vector2(lava_rect.size.x * 0.5, lava_rect.position.y)

	add_child(_bubble_particles)


func _make_lava_material(for_rect: ColorRect, use_cpu_edge_lut: bool) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = LAVA_SHADER
	_apply_lava_shader_grid(mat, for_rect)
	_ensure_stub_edge_tex()
	mat.set_shader_parameter("use_cpu_edge_lut", use_cpu_edge_lut)
	mat.set_shader_parameter("edge_lut", _stub_edge_tex)
	mat.set_shader_parameter("edge_lut_width", 1)
	return mat


func _apply_lava_shader_grid(mat: ShaderMaterial, for_rect: ColorRect) -> void:
	var sz := for_rect.size
	if sz.x <= 0.0 or sz.y <= 0.0:
		return
	var cpp := maxi(1, lava_cells_per_tile)
	var cell_px := float(tile_size) / float(cpp)
	mat.set_shader_parameter("columns", sz.x / cell_px)
	mat.set_shader_parameter("rows", maxf(8.0, sz.y / cell_px))
	mat.set_shader_parameter("flow_speed", flow_speed)
	mat.set_shader_parameter("edge_height", edge_height)


func _refresh_lava_material_grids() -> void:
	var m := lava_rect.material
	if m is ShaderMaterial:
		_apply_lava_shader_grid(m, lava_rect)
	var lava_bg := get_parent().get_node_or_null("LavaImgRect")
	if lava_bg is ColorRect and lava_bg.material is ShaderMaterial:
		_apply_lava_shader_grid(lava_bg.material as ShaderMaterial, lava_bg)


func _ensure_column_colliders(ncol: int) -> void:
	if _column_shapes.size() == ncol:
		return
	for c in _column_shapes:
		if is_instance_valid(c):
			c.queue_free()
	_column_shapes.clear()
	for _i in ncol:
		var cs := CollisionShape2D.new()
		cs.shape = RectangleShape2D.new()
		add_child(cs)
		_column_shapes.append(cs)


func _sync_edge_lut_and_collision(sync_t: float) -> void:
	var m := lava_rect.material as ShaderMaterial
	if m == null or _lava_bounds.size.x <= 0.0:
		return
	var cols_f: float = float(m.get_shader_parameter("columns"))
	var edge_h: float = float(m.get_shader_parameter("edge_height"))
	var ncol: int = maxi(1, int(ceil(cols_f)))
	_ensure_column_colliders(ncol)
	if _edge_img == null or _edge_img.get_width() != ncol:
		_edge_img = Image.create(ncol, 1, false, Image.FORMAT_RGBAF)
		_edge_tex = ImageTexture.create_from_image(_edge_img)
	elif _edge_tex == null:
		_edge_tex = ImageTexture.create_from_image(_edge_img)
	var w: float = _lava_bounds.size.x
	var h: float = _lava_bounds.size.y
	var base: Vector2 = _lava_bounds.position
	var cell_w: float = w / cols_f
	for i in ncol:
		var col_norm: float = float(i) / cols_f
		var tb: Vector2 = LavaEdgeMath.column_top_bottom_uv(col_norm, sync_t, edge_h)
		_edge_img.set_pixel(i, 0, Color(tb.x, tb.y, 0.0, 1.0))
		var top_y: float = base.y + tb.x * h
		var bot_y: float = base.y + tb.y * h
		var cy: float = (top_y + bot_y) * 0.5
		var cheight: float = maxf(bot_y - top_y, 1.0)
		var cs: CollisionShape2D = _column_shapes[i]
		var rs: RectangleShape2D = cs.shape as RectangleShape2D
		rs.size = Vector2(cell_w, cheight)
		cs.position = Vector2(base.x + (float(i) + 0.5) * cell_w, cy)
	_edge_tex.set_image(_edge_img)
	m.set_shader_parameter("edge_lut", _edge_tex)
	m.set_shader_parameter("edge_lut_width", ncol)
	m.set_shader_parameter("use_cpu_edge_lut", true)


func _set_lava_sync_on_materials(sync_t: float) -> void:
	var bg := get_parent().get_node_or_null("LavaImgRect")
	for node in [lava_rect, bg]:
		if node is ColorRect:
			var mat: ShaderMaterial = node.material as ShaderMaterial
			if mat:
				mat.set_shader_parameter("lava_sync_time", sync_t)


func _process(delta: float) -> void:
	_lava_time += delta
	var sync_t: float = _lava_time * flow_speed
	_sync_edge_lut_and_collision(sync_t)
	_set_lava_sync_on_materials(sync_t)


func _ready() -> void:
	game_manager = get_tree().root.get_node("Main/GameManager")

	var rs0 := col_shape.shape as RectangleShape2D
	if rs0:
		var h := rs0.size * 0.5
		_lava_bounds = Rect2(col_shape.position - h, rs0.size)
	col_shape.disabled = true
	col_shape.shape = null

	_ensure_stub_edge_tex()
	lava_rect.material = _make_lava_material(lava_rect, true)
	var lava_bg := get_parent().get_node_or_null("LavaImgRect")
	if lava_bg is ColorRect:
		lava_bg.material = _make_lava_material(lava_bg, false)
	call_deferred("_deferred_lava_layout_and_collision")
	call_deferred("_setup_bubble_particles")

	# timer na posúvanie lávy
	grow_timer = Timer.new()
	grow_timer.wait_time = grow_interval_sec
	grow_timer.autostart = true
	grow_timer.one_shot = false
	add_child(grow_timer)
	grow_timer.timeout.connect(_on_grow_timeout)

	# timer na damage každú sekundu
	damage_timer = Timer.new()
	damage_timer.wait_time = damage_interval_sec
	damage_timer.autostart = true
	damage_timer.one_shot = false
	add_child(damage_timer)
	damage_timer.timeout.connect(_on_damage_timeout)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	_sync_hitbox_debug_overlay()


func _deferred_lava_layout_and_collision() -> void:
	_refresh_lava_material_grids()
	_sync_edge_lut_and_collision(_lava_time * flow_speed)


func _on_grow_timeout() -> void:
	# posuň Area2D o celý tile dole
	position.y += tile_size
	
	_set_next_grow_interval()

func _set_next_grow_interval() -> void:
	if last_interval_was_short:
		grow_timer.wait_time = DEFAULT_GROW_INTERVAL
		last_interval_was_short = false
	else:
		# 25% = normal, 45% = fast, 30% = fastest
		var rand := randf()
		if rand < 0.3:
			grow_timer.wait_time = 0.8
			last_interval_was_short = true
		elif rand < 0.25 + 0.45:
			grow_timer.wait_time = 1.25
			last_interval_was_short = false
		else:
			grow_timer.wait_time = DEFAULT_GROW_INTERVAL
			last_interval_was_short = false

	# Restart timer s novým wait_time (pre ďalšie timeouty)
	grow_timer.start()

func stop_growing() -> void:
	grow_timer.stop()

func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D and body.name.begins_with("Player"):
		if not bodies_in_lava.has(body):
			bodies_in_lava.append(body)

func _on_body_exited(body: Node) -> void:
	bodies_in_lava.erase(body)


func _on_damage_timeout() -> void:
	for body in bodies_in_lava:
		if is_instance_valid(body) and body is CharacterBody2D and not body.is_dead:
			game_manager.damage_player(body, damage_per_tick, true)
