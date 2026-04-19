extends Control

signal reveal_finished

@export var overlay_type: String = "gameover"
@export_range(0.4, 6.0, 0.1) var flood_duration_sec: float = 1.25
@export_range(0.0, 2.0, 0.01) var lava_flow_speed: float = 0.42
@export_range(1.0, 1.5, 0.01) var flood_end_progress: float = 1.08
@export_range(1, 32, 1) var lava_cells_per_tile: int = 4
@export var tile_size: int = 16
@onready var time_label: Label  = $VBoxContainer/TimeLabel
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var sub_title_label: Label = $VBoxContainer/SubTitleLabel
@onready var btn: Button = $VBoxContainer/Button
@onready var vbox: VBoxContainer = $VBoxContainer
@onready var lava_rect: ColorRect = $LavaRect

var flood_tween: Tween
var _flood_progress: float = 0.0
var _flood_phase: float = 0.0
var _lava_time: float = 0.0
var _lava_mat: ShaderMaterial

enum OverlayState {
	IDLE,
	FLOODING,
	REVEALED,
}

var _state: OverlayState = OverlayState.IDLE

func _ready() -> void:
	if lava_rect.material != null:
		# Každý overlay musí mať vlastný ShaderMaterial, inak sa shader parametre
		# (fill_progress, lava_time...) prepíšu aj v druhom overlayi.
		lava_rect.material = lava_rect.material.duplicate()
	_lava_mat = lava_rect.material as ShaderMaterial
	_apply_lava_shader_grid()
	call_deferred("_apply_lava_shader_grid")
	_reset_overlay_visuals()
	set_process(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_lava_shader_grid()

func update_type(type: String) -> void:
	if overlay_type == type: return
	overlay_type = type
	
	if overlay_type == "gameover": 
		title_label.text = "You lose!"
		title_label.modulate = Color("#ff0000")
		sub_title_label.text = "you survived:"
		btn.text = "RESTART"
		
	if overlay_type == "win":
		title_label.text = "You won!"
		title_label.modulate = Color("#00ff00")
		sub_title_label.text = "& reached treasure in:"
		btn.text = "PLAY AGAIN"

func show_game_over(time_sec: float, type: String) -> void:
	update_type(type)
	time_label.text = _format_time_mm_ss(time_sec)
	visible = true
	_start_lava_flood_sequence()

func show_game_over_instant(time_sec: float, type: String) -> void:
	update_type(type)
	time_label.text = _format_time_mm_ss(time_sec)
	visible = true
	_stop_active_tween()
	_flood_phase = 1.0
	_set_flood_progress(flood_end_progress)
	if _lava_mat != null:
		_lava_mat.set_shader_parameter("flow_speed", lava_flow_speed)
		_lava_mat.set_shader_parameter("lava_time", _lava_time)
	vbox.visible = true
	lava_rect.visible = true
	_state = OverlayState.REVEALED
	set_process(true)
	reveal_finished.emit()

func _process(delta: float) -> void:
	if _state == OverlayState.IDLE:
		return
	_lava_time += delta
	if _lava_mat != null:
		_lava_mat.set_shader_parameter("lava_time", _lava_time)

func _start_lava_flood_sequence() -> void:
	_stop_active_tween()
	_reset_overlay_visuals()
	vbox.visible = false
	lava_rect.visible = true
	_state = OverlayState.FLOODING
	set_process(true)

	flood_tween = create_tween()
	flood_tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	flood_tween.tween_method(Callable(self, "_set_flood_phase"), 0.0, 1.0, flood_duration_sec)
	flood_tween.finished.connect(_on_flood_finished)

func _ease_in_out_quint(x: float) -> float:
	if x < 0.5:
		return 16.0 * x * x * x * x * x
	return 1.0 - pow(-2.0 * x + 2.0, 5.0) / 2.0

func _set_flood_phase(value: float) -> void:
	_flood_phase = clampf(value, 0.0, 1.0)
	var shaped := _ease_in_out_quint(_flood_phase)
	_set_flood_progress(lerpf(0.0, flood_end_progress, shaped))

func _set_flood_progress(value: float) -> void:
	_flood_progress = clampf(value, 0.0, flood_end_progress)
	if _lava_mat != null:
		_lava_mat.set_shader_parameter("fill_progress", _flood_progress)

func _on_flood_finished() -> void:
	_flood_phase = 1.0
	_set_flood_progress(flood_end_progress)
	vbox.visible = true
	_state = OverlayState.REVEALED
	set_process(true)
	reveal_finished.emit()

func _apply_lava_shader_grid() -> void:
	if _lava_mat == null:
		return
	var sz := lava_rect.size
	if sz.x <= 0.0 or sz.y <= 0.0:
		return
	var cpp := maxi(1, lava_cells_per_tile)
	var cell_px := float(tile_size) / float(cpp)
	_lava_mat.set_shader_parameter("grid_columns", sz.x / cell_px)
	_lava_mat.set_shader_parameter("grid_rows", maxf(8.0, sz.y / cell_px))

func _reset_overlay_visuals() -> void:
	_flood_phase = 0.0
	_lava_time = 0.0
	_set_flood_progress(0.0)
	if _lava_mat != null:
		_lava_mat.set_shader_parameter("flow_speed", lava_flow_speed)
		_lava_mat.set_shader_parameter("lava_time", _lava_time)
	vbox.visible = false
	lava_rect.visible = true
	_state = OverlayState.IDLE

func _stop_active_tween() -> void:
	if flood_tween != null and flood_tween.is_valid():
		flood_tween.kill()
	flood_tween = null

func _format_time_mm_ss(time_sec: float) -> String:
	var m: int = int(time_sec / 60.0)
	var s: int = int(time_sec) % 60
	return "%02d:%02d" % [m, s]


func _on_restart_button_pressed() -> void:
	get_tree().reload_current_scene()
