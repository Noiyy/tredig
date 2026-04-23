extends Control

@export var tile_pixel_size: float = 16.0
@export var player_left_color: Color = Color("#ff6f6f")
@export var player_right_color: Color = Color("#64b5ff")
@export var lava_color: Color = Color("#ff7a00")
@export var minimap_background_color: Color = Color(0.0, 0.0, 0.0, 0.15)
@export var terrain_boundary_color: Color = Color(0.72, 0.72, 0.72, 0.15)
@export_range(1.0, 3.0, 0.5) var terrain_boundary_thickness_px: float = 1.0
@export var focus_fill_color: Color = Color(1.0, 1.0, 1.0, 0.07)
@export var focus_outline_color: Color = Color(1.0, 1.0, 1.0, 0.42)
@export var marker_radius: float = 2.25
@export var focus_padding_world: float = 64.0
@export var show_focus_window: bool = false
@export var dead_player_color: Color = Color.WHITE
@export var damage_flash_color: Color = Color("#fff")
@export var damage_flash_duration: float = 0.35
@export var damage_flash_hz: float = 14.0
@export var show_lava_distance_labels: bool = true
@export var distance_label_font_size: int = 5
@export var distance_block_size_px: float = 16.0
@export var distance_label_margin_px: float = 4.0
@export var distance_bracket_color: Color = Color(0.75, 0.75, 0.75, 0.5)
@export var distance_bracket_cap_px: float = 5.0

var _tilemap: TileMapLayer
var _player_left: Node2D
var _player_right: Node2D
var _lava: Node2D
var _world_rect: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0)
var _terrain_texture: ImageTexture
var _last_draw_size: Vector2 = Vector2.ZERO

var _left_pos: Vector2 = Vector2.ZERO
var _right_pos: Vector2 = Vector2.ZERO
var _lava_y: float = 0.0
var _left_last_hp: int = -1
var _right_last_hp: int = -1
var _left_damage_flash_until: float = 0.0
var _right_damage_flash_until: float = 0.0
var _left_lava_distance_px: float = 0.0
var _right_lava_distance_px: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _tilemap != null:
		if size != _last_draw_size:
			_rebuild_terrain_texture()
			queue_redraw()


func configure(
	tilemap: TileMapLayer,
	player_left: Node2D,
	player_right: Node2D,
	lava: Node2D,
	world_left_x: float,
	world_right_x: float,
	world_tile_size: float
) -> void:
	_tilemap = tilemap
	_player_left = player_left
	_player_right = player_right
	_lava = lava
	tile_pixel_size = maxf(1.0, world_tile_size)
	_compute_world_rect(world_left_x, world_right_x)
	_rebuild_terrain_texture()
	queue_redraw()


func update_runtime(player_left_pos: Vector2, player_right_pos: Vector2, lava_y: float) -> void:
	_left_pos = player_left_pos
	_right_pos = player_right_pos
	_lava_y = lava_y
	_left_lava_distance_px = maxf(_left_pos.y - _lava_y, 0.0)
	_right_lava_distance_px = maxf(_right_pos.y - _lava_y, 0.0)
	_update_damage_flash_timers()
	queue_redraw()


func _draw() -> void:
	if _terrain_texture != null:
		draw_texture_rect(_terrain_texture, Rect2(Vector2.ZERO, size), false)

	var lava_a := _world_to_minimap(Vector2(_world_rect.position.x, _lava_y))
	var lava_b := _world_to_minimap(Vector2(_world_rect.position.x + _world_rect.size.x, _lava_y))
	draw_line(
		Vector2(0.0, lava_a.y),
		Vector2(size.x, lava_b.y),
		lava_color,
		1.5
	)

	var left_marker := _world_to_minimap(_left_pos)
	var right_marker := _world_to_minimap(_right_pos)
	var left_color := _resolve_marker_color(_player_left, player_left_color, _left_damage_flash_until)
	var right_color := _resolve_marker_color(_player_right, player_right_color, _right_damage_flash_until)

	draw_circle(left_marker, marker_radius + 1.0, Color(0.0, 0.0, 0.0, 0.7))
	draw_circle(right_marker, marker_radius + 1.0, Color(0.0, 0.0, 0.0, 0.7))
	draw_circle(left_marker, marker_radius, left_color)
	draw_circle(right_marker, marker_radius, right_color)
	_draw_lava_distance_labels(left_marker, right_marker, lava_a.y, left_color, right_color)

	if show_focus_window:
		var y_min_world := minf(_left_pos.y, _right_pos.y) - focus_padding_world
		var y_max_world := maxf(_left_pos.y, _right_pos.y) + focus_padding_world
		var y0 := _world_to_minimap(Vector2(_world_rect.position.x, y_min_world)).y
		var y1 := _world_to_minimap(Vector2(_world_rect.position.x, y_max_world)).y
		var focus_y := clampf(minf(y0, y1), 0.0, size.y)
		var max_focus_h := maxf(2.0, size.y - focus_y)
		var focus_h := clampf(absf(y1 - y0), 2.0, max_focus_h)
		var focus_rect := Rect2(1.0, focus_y, maxf(1.0, size.x - 2.0), focus_h)
		draw_rect(focus_rect, focus_fill_color, true)
		draw_rect(focus_rect, focus_outline_color, false, 1.0)


func _compute_world_rect(world_left_x: float, world_right_x: float) -> void:
	var map_bounds := Rect2(0.0, 0.0, maxf(1.0, world_right_x - world_left_x), 1.0)
	map_bounds.position.x = world_left_x

	if _tilemap != null:
		var used := _tilemap.get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			var top_left_cell := used.position
			var bottom_right_cell := used.position + used.size
			var top_left_world := _tilemap.to_global(_tilemap.map_to_local(top_left_cell))
			var bottom_right_world := _tilemap.to_global(_tilemap.map_to_local(bottom_right_cell))
			map_bounds.position.y = minf(top_left_world.y, bottom_right_world.y) - tile_pixel_size * 0.5
			map_bounds.size.y = maxf(
				tile_pixel_size,
				absf(bottom_right_world.y - top_left_world.y) + tile_pixel_size
			)
		else:
			map_bounds.position.y = 0.0
			map_bounds.size.y = 1000.0
	else:
		map_bounds.position.y = 0.0
		map_bounds.size.y = 1000.0

	_world_rect = map_bounds


func _rebuild_terrain_texture() -> void:
	_last_draw_size = size
	if _tilemap == null or size.x <= 1.0 or size.y <= 1.0:
		_terrain_texture = null
		return

	var tex_w := maxi(1, int(round(size.x)))
	var tex_h := maxi(1, int(round(size.y)))
	var image := Image.create(tex_w, tex_h, false, Image.FORMAT_RGBA8)
	image.fill(minimap_background_color)

	var used := _tilemap.get_used_rect()
	if used.size.y > 1:
		for map_y in range(used.position.y, used.position.y + used.size.y - 1):
			var current_set := _row_primary_terrain_set(map_y, used)
			var next_set := _row_primary_terrain_set(map_y + 1, used)
			if current_set < 0 or next_set < 0 or current_set == next_set:
				continue

			var row_center_world := _tilemap.to_global(_tilemap.map_to_local(Vector2i(used.position.x, map_y)))
			var boundary_world_y := row_center_world.y + tile_pixel_size * 0.5
			var boundary_mini_y := _world_to_minimap(Vector2(_world_rect.position.x, boundary_world_y)).y
			_draw_horizontal_boundary(image, boundary_mini_y)

	_terrain_texture = ImageTexture.create_from_image(image)


func _row_primary_terrain_set(map_y: int, used: Rect2i) -> int:
	var counts := {}
	var best_set := -1
	var best_count := 0
	for x in range(used.position.x, used.position.x + used.size.x):
		var coords := Vector2i(x, map_y)
		if _tilemap.get_cell_source_id(coords) == -1:
			continue
		var tile_data := _tilemap.get_cell_tile_data(coords)
		if tile_data == null:
			continue
		var set_id := tile_data.get_terrain_set()
		if set_id < 0:
			continue
		var count := int(counts.get(set_id, 0)) + 1
		counts[set_id] = count
		if count > best_count:
			best_count = count
			best_set = set_id
	return best_set


func _draw_horizontal_boundary(image: Image, y_mini: float) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var thickness := maxi(1, int(round(terrain_boundary_thickness_px)))
	var y0 := clampi(int(round(y_mini - float(thickness) * 0.5)), 0, h - 1)
	image.fill_rect(Rect2i(0, y0, w, thickness), terrain_boundary_color)


func _is_player_dead(player_ref: Node2D) -> bool:
	if player_ref == null:
		return false
	var dead_value: Variant = player_ref.get("is_dead")
	return dead_value is bool and dead_value


func _resolve_marker_color(player_ref: Node2D, base_color: Color, flash_until: float) -> Color:
	if _is_player_dead(player_ref):
		return dead_player_color

	var now_sec := float(Time.get_ticks_msec()) / 1000.0
	if now_sec < flash_until:
		var phase := int(floor(now_sec * damage_flash_hz))
		if phase % 2 == 0:
			return damage_flash_color
	return base_color


func _update_damage_flash_timers() -> void:
	_left_damage_flash_until = _update_single_damage_flash(
		_player_left,
		_left_last_hp,
		"_left_last_hp",
		_left_damage_flash_until
	)
	_right_damage_flash_until = _update_single_damage_flash(
		_player_right,
		_right_last_hp,
		"_right_last_hp",
		_right_damage_flash_until
	)


func _update_single_damage_flash(
	player_ref: Node2D,
	last_hp: int,
	last_hp_key: String,
	flash_until: float
) -> float:
	if player_ref == null:
		return flash_until

	var hp_variant: Variant = player_ref.get("hp")
	if not (hp_variant is int):
		return flash_until
	var hp_now := int(hp_variant)
	if last_hp >= 0 and hp_now < last_hp:
		var now_sec := float(Time.get_ticks_msec()) / 1000.0
		flash_until = now_sec + damage_flash_duration
	set(last_hp_key, hp_now)
	return flash_until


func _draw_lava_distance_labels(
	left_marker: Vector2,
	right_marker: Vector2,
	lava_line_y: float,
	left_color: Color,
	right_color: Color
) -> void:
	if not show_lava_distance_labels:
		return
	var font := ThemeDB.fallback_font
	if font == null:
		return

	var block_px := maxf(1.0, distance_block_size_px)
	var left_blocks := int(floor(_left_lava_distance_px / block_px))
	var right_blocks := int(floor(_right_lava_distance_px / block_px))
	var left_text := "%db" % left_blocks
	var right_text := "%db" % right_blocks
	var fs := maxi(6, distance_label_font_size)
	var label_y := clampf(lava_line_y, 0.0, size.y)
	var left_bracket_x := -distance_label_margin_px
	var right_bracket_x := size.x + distance_label_margin_px

	if not _is_player_dead(_player_left):
		_draw_distance_bracket(left_bracket_x, left_marker.y, label_y, false)
		var left_text_size := font.get_string_size(left_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var left_text_pos := Vector2(left_bracket_x - distance_label_margin_px - left_text_size.x, label_y)
		draw_string(font, left_text_pos + Vector2(1.0, 1.0), left_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.75))
		draw_string(font, left_text_pos, left_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, left_color)

	if not _is_player_dead(_player_right):
		_draw_distance_bracket(right_bracket_x, right_marker.y, label_y, true)
		var right_text_pos := Vector2(right_bracket_x + distance_label_margin_px, label_y)
		draw_string(font, right_text_pos + Vector2(1.0, 1.0), right_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.75))
		draw_string(font, right_text_pos, right_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, right_color)


func _draw_distance_bracket(x: float, player_y: float, lava_y: float, right_side: bool) -> void:
	var y0 := clampf(player_y, 0.0, size.y)
	var y1 := clampf(lava_y, 0.0, size.y)
	var top := minf(y0, y1)
	var bottom := maxf(y0, y1)
	var cap := maxf(3.0, distance_bracket_cap_px)
	var dir := -1.0 if right_side else 1.0

	draw_line(Vector2(x, top), Vector2(x, bottom), distance_bracket_color, 1.0)
	draw_line(Vector2(x, top), Vector2(x + cap * dir, top), distance_bracket_color, 1.0)
	draw_line(Vector2(x, bottom), Vector2(x + cap * dir, bottom), distance_bracket_color, 1.0)


func _world_to_minimap(world_pos: Vector2) -> Vector2:
	var x_range := maxf(1.0, _world_rect.size.x)
	var y_range := maxf(1.0, _world_rect.size.y)
	var nx := clampf((world_pos.x - _world_rect.position.x) / x_range, 0.0, 1.0)
	var ny := clampf((world_pos.y - _world_rect.position.y) / y_range, 0.0, 1.0)
	return Vector2(nx * size.x, ny * size.y)
