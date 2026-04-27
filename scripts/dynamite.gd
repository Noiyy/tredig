extends Node2D

## Single-shot projectile spawned by the DYNAMITE skill. After a short fuse it warns
## the player about the blast area, then damages tiles and players in that radius.

const FUSE_SEC := 2.0
const EXPLOSION_DAMAGE := 6
const PLAYER_DAMAGE := 10
const WARNING_COLOR := Color(1.0, 0.0, 0.0, 0.08)
const WARNING_OUTLINE_COLOR := Color(1.0, 0.12, 0.08, 0.2)
const WARNING_WHITE_COLOR := Color(1.0, 1.0, 1.0, 0.1)
const WARNING_WHITE_OUTLINE_COLOR := Color(1.0, 1.0, 1.0, 0.2)
const PARTICLE_LIFETIME := 0.55

class WarningOverlay extends Node2D:
	var tilemap: TileMapLayer
	var coords: Array[Vector2i] = []
	var tile_size: float = 16.0
	var pulse_time: float = 0.0

	func _process(delta: float) -> void:
		pulse_time += delta
		queue_redraw()

	func _draw() -> void:
		if tilemap == null:
			return
		var blink := (sin(pulse_time * 12.0) + 1.0) * 0.5
		var fill_color := WARNING_COLOR.lerp(WARNING_WHITE_COLOR, blink)
		var outline_color := WARNING_OUTLINE_COLOR.lerp(WARNING_WHITE_OUTLINE_COLOR, blink)
		for coord in coords:
			var center := to_local(tilemap.to_global(tilemap.map_to_local(coord)))
			var rect := Rect2(center - Vector2(tile_size, tile_size) * 0.5, Vector2(tile_size, tile_size))
			draw_rect(rect, fill_color, true)
			draw_rect(rect, outline_color, false, 1.4)


class ExplosionParticles extends Node2D:
	var particles: Array[Dictionary] = []
	var age: float = 0.0
	var lifetime: float = PARTICLE_LIFETIME
	var particle_count: int = 28
	var radial_spread_mult: float = 1.0

	func _ready() -> void:
		for i in particle_count:
			var angle := randf() * TAU
			var speed := randf_range(28.0, 86.0) * radial_spread_mult
			var size := randf_range(2.0, 5.0)
			var start_offset := Vector2(cos(angle), sin(angle)) * randf_range(0.0, 7.0) * radial_spread_mult
			particles.append({
				"pos": start_offset,
				"vel": Vector2(cos(angle), sin(angle)) * speed,
				"size": size,
				"color": Color.WHITE if i % 3 == 0 else Color(randf_range(0.45, 0.72), randf_range(0.45, 0.72), randf_range(0.45, 0.72), 1.0),
			})

	func _process(delta: float) -> void:
		age += delta
		for p in particles:
			p.pos += p.vel * delta
			p.vel *= 0.9
		queue_redraw()
		if age >= lifetime:
			queue_free()

	func _draw() -> void:
		var fade := 1.0 - clampf(age / lifetime, 0.0, 1.0)
		for p in particles:
			var color: Color = p.color
			color.a = fade
			draw_circle(p.pos, p.size * fade, color)

@onready var sprite: Sprite2D = $Sprite2D
@onready var fuse_timer: Timer = $FuseTimer

var _target_coord: Vector2i
var _target_player: CharacterBody2D
var _tile_manager
var _tilemap: TileMapLayer
var _warning_overlay: WarningOverlay
var _game_manager
var _explosion_radius: int = 1

func setup(coord: Vector2i, target_player: CharacterBody2D) -> void:
	_target_coord = coord
	_target_player = target_player
	_explosion_radius = randi_range(1, 3)


func _ready() -> void:
	if _target_player != null:
		_tile_manager = _target_player.get_node_or_null("TileManager")
	if _tile_manager == null:
		_game_manager = get_tree().root.get_node_or_null("Main/GameManager")
		if _game_manager != null and _game_manager.players.has("PlayerLeft"):
			_tile_manager = _game_manager.players["PlayerLeft"].ref.get_node_or_null("TileManager")
	else:
		_game_manager = get_tree().root.get_node_or_null("Main/GameManager")
	if _tile_manager == null:
		queue_free()
		return
	_tilemap = _tile_manager.tilemap

	var landing := _tilemap.to_global(_tilemap.map_to_local(_target_coord))
	global_position = landing + Vector2(0, -32)
	_show_warning_overlay()

	# Toss arc onto target tile.
	var tween := create_tween()
	tween.tween_property(self, "global_position", landing, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "rotation", deg_to_rad(180), 0.45)

	fuse_timer.wait_time = FUSE_SEC
	fuse_timer.one_shot = true
	fuse_timer.timeout.connect(_explode)
	fuse_timer.start()

	# Blink as fuse runs out.
	var blink := create_tween().set_loops()
	blink.tween_property(sprite, "modulate", Color(1.5, 0.8, 0.8), 0.18)
	blink.tween_property(sprite, "modulate", Color.WHITE, 0.18)


func _explode() -> void:
	if _tile_manager == null:
		queue_free()
		return
	AudioManager.play("res://assets/sounds/sabotage.wav")
	_clear_warning_overlay()
	_spawn_explosion_particles()
	var tileset: TileSet = _tilemap.tile_set

	var explosion_coords := _get_explosion_coords()
	for coord in explosion_coords:
		_damage_tile_at(coord, tileset)
	_damage_players_in_radius(explosion_coords)
	queue_free()


func _show_warning_overlay() -> void:
	if _tilemap == null:
		return
	_warning_overlay = WarningOverlay.new()
	_warning_overlay.tilemap = _tilemap
	_warning_overlay.coords = _get_explosion_coords()
	_warning_overlay.tile_size = float(_game_manager.get_tile_size()) if _game_manager != null else 16.0
	_warning_overlay.z_index = 90
	get_parent().add_child(_warning_overlay)


func _clear_warning_overlay() -> void:
	if _warning_overlay != null and is_instance_valid(_warning_overlay):
		_warning_overlay.queue_free()
	_warning_overlay = null


func _spawn_explosion_particles() -> void:
	var particles := ExplosionParticles.new()
	# Bigger blast radius = denser explosion visuals.
	particles.particle_count = 20 + _explosion_radius * 16
	# Bigger radius also spreads particles wider/faster.
	particles.radial_spread_mult = 1.0 + (float(_explosion_radius - 1) * 0.4)
	particles.lifetime = PARTICLE_LIFETIME + (float(_explosion_radius - 1) * 0.08)
	particles.z_index = 100
	get_parent().add_child(particles)
	particles.global_position = _tilemap.to_global(_tilemap.map_to_local(_target_coord))


func _get_explosion_coords() -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	var use_circle := _explosion_radius >= 3
	for dy in range(-_explosion_radius, _explosion_radius + 1):
		for dx in range(-_explosion_radius, _explosion_radius + 1):
			if not use_circle:
				coords.append(_target_coord + Vector2i(dx, dy))
			elif dx * dx + dy * dy <= _explosion_radius * _explosion_radius:
				coords.append(_target_coord + Vector2i(dx, dy))
	return coords


func _damage_players_in_radius(explosion_coords: Array[Vector2i]) -> void:
	if _game_manager == null:
		return
	for data in _game_manager.players.values():
		if not data.has("ref"):
			continue
		var player: CharacterBody2D = data.ref
		if player == null or not is_instance_valid(player) or player.is_dead:
			continue
		var player_coord := _tilemap.local_to_map(_tilemap.to_local(player.global_position))
		if explosion_coords.has(player_coord):
			_game_manager.damage_player(player, PLAYER_DAMAGE, true, true)


func _damage_tile_at(coord: Vector2i, tileset: TileSet) -> void:
	var tile_id := _tilemap.get_cell_source_id(coord)
	if tile_id == -1:
		return
	var tile_data_res: TileData = _tilemap.get_cell_tile_data(coord)
	var tile_level := 4
	if tileset.has_custom_data_layer_by_name("hardness") and tile_data_res:
		var hardness_layer := tileset.get_custom_data_layer_by_name("hardness")
		tile_level += int(tile_data_res.get_custom_data_by_layer_id(hardness_layer))

	if coord not in _tile_manager.tile_data:
		_tile_manager.tile_data[coord] = {"level": tile_level, "hp": tile_level}
	var td: Dictionary = _tile_manager.tile_data[coord]
	td.hp -= EXPLOSION_DAMAGE

	if td.hp <= 0:
		var terrain_set_id: int = tile_data_res.get_terrain_set() if tile_data_res else 0
		_tilemap.set_cells_terrain_connect([coord], terrain_set_id, -1, true)
		_tile_manager.dmgTilemap.set_cell(coord, tile_id, coord, -1)
		_tile_manager.effectTilemap.set_cell(coord, 0, Vector2i(-1, -1))
		_tile_manager.tile_data.erase(coord)
	else:
		var damage_val: int = _tile_manager.calculate_tile_dmg_val(td.hp, tile_level, EXPLOSION_DAMAGE)
		_tile_manager.dmgTilemap.set_cell(coord, tile_id, Vector2(damage_val, 0))
