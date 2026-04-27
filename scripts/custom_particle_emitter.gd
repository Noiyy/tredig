class_name CustomParticleEmitter2D
extends Node2D

const SHAPE_SYMBOL := "symbol"
const SHAPE_CIRCLE := "circle"
const SHAPE_DROP := "drop"
const SHAPE_TEXTURE := "texture"

const SHOVEL_ICON := preload("res://assets/images/shovel-icon.png")
const DURABILITY_ICON := preload("res://assets/images/durability-icon.png")

const MAX_PARTICLES_PER_EMITTER := 20

var particles: Array[Dictionary] = []
var config: Dictionary = {}

var _age: float = 0.0
var _emit_age: float = 0.0
var _spawn_accum: float = 0.0
var _is_emitting: bool = true


static func spawn(parent: Node, pos: Vector2, particle_config: Dictionary) -> CustomParticleEmitter2D:
	if parent == null:
		return null
	var emitter := CustomParticleEmitter2D.new()
	emitter.config = particle_config.duplicate(true)
	emitter.z_index = int(emitter.config.get("z_index", 95))
	parent.add_child(emitter)
	emitter.global_position = pos
	return emitter


static func spawn_on_player(player: Node2D, particle_config: Dictionary,
	offset: Vector2 = Vector2(0, -14)) -> CustomParticleEmitter2D:
	if player == null or not is_instance_valid(player):
		return null
	return spawn(player.get_parent(), player.global_position + offset, particle_config)


static func preset_dullness() -> Dictionary:
	return {
		"shape": SHAPE_SYMBOL,
		"symbol": "-",
		"colors": [Color(0.58, 0.58, 0.62, 0.95), Color(0.34, 0.34, 0.38, 0.9)],
		"emit_duration": 0.32,
		"particle_lifetime": 0.85,
		"spawn_rate": 16.0,
		"burst_count": 3,
		"direction": Vector2.DOWN,
		"speed_min": 8.0,
		"speed_max": 20.0,
		"spread_degrees": 30.0,
		"gravity": Vector2(0, 9),
		"fade_out": true,
		"scale_min": 0.85,
		"scale_max": 1.2,
		"side_offset": true,
	}


static func preset_overload() -> Dictionary:
	return {
		"shape": SHAPE_DROP,
		"colors": [Color(0.32, 0.78, 1.0, 0.95), Color(0.1, 0.42, 0.95, 0.9)],
		"emit_duration": 0.36,
		"particle_lifetime": 0.9,
		"spawn_rate": 18.0,
		"burst_count": 4,
		"direction": Vector2.DOWN,
		"speed_min": 10.0,
		"speed_max": 24.0,
		"spread_degrees": 22.0,
		"gravity": Vector2(0, 16),
		"fade_out": true,
		"scale_min": 0.8,
		"scale_max": 1.25,
		"side_offset": true,
	}


static func preset_sharpness() -> Dictionary:
	return {
		"shape": SHAPE_SYMBOL,
		"symbol": "x",
		"colors": [Color(0.92, 0.94, 0.96, 0.98), Color(0.62, 0.68, 0.76, 0.92)],
		"emit_duration": 0.32,
		"particle_lifetime": 0.88,
		"spawn_rate": 15.0,
		"burst_count": 3,
		"direction": Vector2.UP,
		"speed_min": 8.0,
		"speed_max": 22.0,
		"spread_degrees": 34.0,
		"gravity": Vector2(0, -3),
		"fade_out": true,
		"scale_min": 0.85,
		"scale_max": 1.2,
	}


static func preset_sshovel() -> Dictionary:
	return {
		"shape": SHAPE_TEXTURE,
		"texture": SHOVEL_ICON,
		"colors": [Color(1, 1, 1, 0.96)],
		"emit_duration": 0.28,
		"particle_lifetime": 0.88,
		"spawn_rate": 12.0,
		"burst_count": 3,
		"direction": Vector2.UP,
		"speed_min": 8.0,
		"speed_max": 20.0,
		"spread_degrees": 28.0,
		"gravity": Vector2(0, -2),
		"fade_out": true,
		"scale_min": 0.75,
		"scale_max": 1.05,
	}


static func preset_heal() -> Dictionary:
	return {
		"shape": SHAPE_SYMBOL,
		"symbol": "+",
		"colors": [Color(0.32, 1.0, 0.44, 0.98), Color(0.12, 0.72, 0.22, 0.92)],
		"emit_duration": 0.34,
		"particle_lifetime": 0.9,
		"spawn_rate": 16.0,
		"burst_count": 4,
		"direction": Vector2.UP,
		"speed_min": 8.0,
		"speed_max": 22.0,
		"spread_degrees": 34.0,
		"gravity": Vector2(0, -3),
		"fade_out": true,
		"scale_min": 0.9,
		"scale_max": 1.35,
	}


static func preset_durability_up() -> Dictionary:
	return {
		"shape": SHAPE_TEXTURE,
		"texture": DURABILITY_ICON,
		"colors": [Color(1, 1, 1, 0.96)],
		"emit_duration": 0.32,
		"particle_lifetime": 0.9,
		"spawn_rate": 13.0,
		"burst_count": 3,
		"direction": Vector2.UP,
		"speed_min": 8.0,
		"speed_max": 20.0,
		"spread_degrees": 30.0,
		"gravity": Vector2(0, -2),
		"fade_out": true,
		"scale_min": 0.72,
		"scale_max": 1.0,
	}


func _ready() -> void:
	_spawn_particles(int(config.get("burst_count", 0)))


func _process(delta: float) -> void:
	_age += delta
	if _is_emitting:
		_emit_age += delta
		var emit_duration := float(config.get("emit_duration", 0.0))
		if _emit_age >= emit_duration:
			_is_emitting = false
		else:
			_spawn_accum += float(config.get("spawn_rate", 0.0)) * delta
			var to_spawn := int(_spawn_accum)
			if to_spawn > 0:
				_spawn_accum -= float(to_spawn)
				_spawn_particles(to_spawn)

	var gravity: Vector2 = config.get("gravity", Vector2.ZERO)
	var drag := float(config.get("drag", 0.0))
	for i in range(particles.size() - 1, -1, -1):
		var p := particles[i]
		p.age += delta
		if p.age >= p.lifetime:
			particles.remove_at(i)
			continue
		p.vel += gravity * delta
		if drag > 0.0:
			p.vel = p.vel.move_toward(Vector2.ZERO, drag * delta)
		p.pos += p.vel * delta
		p.rotation += p.angular_velocity * delta
	queue_redraw()

	if not _is_emitting and particles.is_empty():
		queue_free()


func _draw() -> void:
	var shape: String = config.get("shape", SHAPE_CIRCLE)
	for p in particles:
		var t: float = clampf(p.age / p.lifetime, 0.0, 1.0)
		var fade := 1.0 - t if bool(config.get("fade_out", true)) else 1.0
		var color: Color = p.color
		color.a *= fade
		var size: float = p.size * lerpf(1.0, 0.65, t)
		match shape:
			SHAPE_SYMBOL:
				_draw_symbol(str(config.get("symbol", "+")), p.pos, size, color, p.rotation)
			SHAPE_DROP:
				_draw_drop(p.pos, size, color, p.rotation)
			SHAPE_TEXTURE:
				_draw_texture_particle(p.pos, size, color, p.rotation)
			_:
				draw_circle(p.pos, size * 0.35, color)


func _spawn_particles(count: int) -> void:
	if count <= 0:
		return
	var free_slots := MAX_PARTICLES_PER_EMITTER - particles.size()
	if free_slots <= 0:
		return
	var spawn_count := mini(count, free_slots)
	for i in spawn_count:
		particles.append(_make_particle())


func _make_particle() -> Dictionary:
	var direction: Vector2 = config.get("direction", Vector2.UP)
	if direction == Vector2.ZERO:
		direction = Vector2.UP
	direction = direction.normalized()

	var spread := deg_to_rad(float(config.get("spread_degrees", 0.0)))
	var angle := direction.angle() + randf_range(-spread * 0.5, spread * 0.5)
	var speed := randf_range(float(config.get("speed_min", 10.0)), float(config.get("speed_max", 30.0)))
	var origin_spread := float(config.get("origin_spread", 8.0))
	var colors: Array = config.get("colors", [Color.WHITE])
	var color: Color = colors.pick_random() if not colors.is_empty() else Color.WHITE

	return {
		"pos": Vector2(randf_range(-origin_spread, origin_spread), randf_range(-3.0, 3.0)),
		"vel": Vector2(cos(angle), sin(angle)) * speed,
		"age": 0.0,
		"lifetime": randf_range(
			float(config.get("particle_lifetime", 0.7)) * 0.82,
			float(config.get("particle_lifetime", 0.7)) * 1.12
		),
		"size": randf_range(float(config.get("scale_min", 0.8)), float(config.get("scale_max", 1.2))) * 12.0,
		"color": color,
		"rotation": randf_range(-0.18, 0.18),
		"angular_velocity": randf_range(-1.2, 1.2),
	}


func _draw_symbol(symbol: String, pos: Vector2, size: float, color: Color, particle_rotation: float) -> void:
	var half := size * 0.32
	var thickness := maxf(1.2, size * 0.12)
	var points: Array[Vector2] = []
	match symbol:
		"-":
			points = [Vector2(-half, 0), Vector2(half, 0)]
		"x", "X":
			var p1 := Vector2(-half, -half).rotated(particle_rotation)
			var p2 := Vector2(half, half).rotated(particle_rotation)
			var p3 := Vector2(-half, half).rotated(particle_rotation)
			var p4 := Vector2(half, -half).rotated(particle_rotation)
			draw_line(pos + p1, pos + p2, color, thickness, true)
			draw_line(pos + p3, pos + p4, color, thickness, true)
			return
		_:
			points = [Vector2(-half, 0), Vector2(half, 0)]
			var v1 := Vector2(0, -half).rotated(particle_rotation)
			var v2 := Vector2(0, half).rotated(particle_rotation)
			draw_line(pos + v1, pos + v2, color, thickness, true)
	for point_i in points.size():
		points[point_i] = points[point_i].rotated(particle_rotation)
	draw_line(pos + points[0], pos + points[1], color, thickness, true)


func _draw_drop(pos: Vector2, size: float, color: Color, particle_rotation: float) -> void:
	var r := size * 0.26
	var tip := Vector2(0, -r * 1.5).rotated(particle_rotation)
	var left := Vector2(-r * 0.85, r * 0.25).rotated(particle_rotation)
	var right := Vector2(r * 0.85, r * 0.25).rotated(particle_rotation)
	var bottom := Vector2(0, r * 1.05).rotated(particle_rotation)
	draw_polygon(
		PackedVector2Array([pos + tip, pos + right, pos + bottom, pos + left]),
		PackedColorArray([color])
	)


func _draw_texture_particle(pos: Vector2, size: float, color: Color, particle_rotation: float) -> void:
	var texture: Texture2D = config.get("texture", null)
	if texture == null:
		draw_circle(pos, size * 0.35, color)
		return
	var tex_size := texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var max_dim := maxf(tex_size.x, tex_size.y)
	var draw_size := tex_size * (size / max_dim)
	draw_set_transform(pos, particle_rotation, Vector2.ONE)
	draw_texture_rect(texture, Rect2(-draw_size * 0.5, draw_size), false, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
