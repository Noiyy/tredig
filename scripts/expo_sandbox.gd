extends CanvasLayer

const FEATURE_NAME := "expo_sandbox"
const TRAILER_PATH := "res://assets/images/short_trailer.ogv"
const MENU_IDLE_TIMEOUT_SEC := 60.0
const GAME_IDLE_TIMEOUT_SEC := 90.0
const FULLSCREEN_CHECK_INTERVAL_SEC := 1.0

@onready var blocker: ColorRect = $Blocker
@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer

var _enabled := false
var _idle_time_sec := 0.0
var _fullscreen_check_time_sec := 0.0
var _attract_active := false
var _previous_paused := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_enabled = OS.has_feature(FEATURE_NAME)
	visible = false

	if not _enabled:
		set_process(false)
		set_process_input(false)
		return

	_force_fullscreen()
	_load_trailer_stream()
	video_player.finished.connect(_on_video_player_finished)


func _process(delta: float) -> void:
	if not _enabled or _attract_active:
		return

	_idle_time_sec += delta
	_fullscreen_check_time_sec += delta

	if _fullscreen_check_time_sec >= FULLSCREEN_CHECK_INTERVAL_SEC:
		_fullscreen_check_time_sec = 0.0
		_force_fullscreen()

	if _idle_time_sec >= _get_current_idle_timeout_sec():
		_start_attract_mode()


func _input(event: InputEvent) -> void:
	if not _enabled or not _is_activity_event(event):
		return

	if _attract_active:
		_stop_attract_mode()
		get_viewport().set_input_as_handled()
		return

	_reset_idle_timer()


func is_enabled() -> bool:
	return _enabled


func enforce_fullscreen() -> void:
	if _enabled:
		_force_fullscreen()


func _load_trailer_stream() -> void:
	if not ResourceLoader.exists(TRAILER_PATH):
		push_warning("ExpoSandbox: trailer missing at %s" % TRAILER_PATH)
		return

	var stream := load(TRAILER_PATH)
	if stream is VideoStream:
		video_player.stream = stream
	else:
		push_warning("ExpoSandbox: %s is not a VideoStream resource" % TRAILER_PATH)


func _force_fullscreen() -> void:
	var window_mode := DisplayServer.window_get_mode()
	if (
		window_mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		or window_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	):
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _get_current_idle_timeout_sec() -> float:
	var current_scene := get_tree().current_scene
	if (
		current_scene != null
		and current_scene.scene_file_path == "res://scenes/main.tscn"
		and not _is_match_finished()
	):
		return GAME_IDLE_TIMEOUT_SEC
	return MENU_IDLE_TIMEOUT_SEC


func _is_match_finished() -> bool:
	var hud := get_tree().root.get_node_or_null("Main/HUD")
	if hud == null:
		return false

	var main_menu_button := hud.get_node_or_null("MainMenuButton") as Button
	if main_menu_button != null and main_menu_button.visible:
		return true

	var left_overlay := hud.get_node_or_null("LeftGameOverOverlay") as CanvasItem
	var right_overlay := hud.get_node_or_null("RightGameOverOverlay") as CanvasItem
	return (
		left_overlay != null
		and right_overlay != null
		and left_overlay.visible
		and right_overlay.visible
	)


func _start_attract_mode() -> void:
	if _attract_active:
		return

	_reset_controls_for_expo_video()
	_attract_active = true
	_previous_paused = get_tree().paused
	get_tree().paused = true
	_force_fullscreen()
	visible = true
	blocker.visible = true

	if video_player.stream != null:
		video_player.stop()
		video_player.play()


func _stop_attract_mode() -> void:
	if not _attract_active:
		return

	if video_player.stream != null:
		video_player.stop()
	blocker.visible = false
	visible = false
	get_tree().paused = _previous_paused
	_attract_active = false
	_reset_idle_timer()
	_force_fullscreen()


func _reset_idle_timer() -> void:
	_idle_time_sec = 0.0


func _reset_controls_for_expo_video() -> void:
	InputMap.load_from_project_settings()
	for action in InputMap.get_actions():
		Input.action_release(action)
	Input.flush_buffered_events()
	if Engine.has_singleton("UserSettings"):
		UserSettings.save()


func _is_activity_event(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		return true

	var mouse_button_event := event as InputEventMouseButton
	if mouse_button_event != null:
		return mouse_button_event.pressed

	var key_event := event as InputEventKey
	if key_event != null:
		return key_event.pressed

	var joy_button_event := event as InputEventJoypadButton
	if joy_button_event != null:
		return joy_button_event.pressed

	var joy_motion_event := event as InputEventJoypadMotion
	if joy_motion_event != null:
		return absf(joy_motion_event.axis_value) >= 0.5

	var touch_event := event as InputEventScreenTouch
	if touch_event != null:
		return touch_event.pressed

	if event is InputEventScreenDrag:
		return true

	var action_event := event as InputEventAction
	if action_event != null:
		return action_event.pressed

	return false


func _on_video_player_finished() -> void:
	if _attract_active and video_player.stream != null:
		video_player.play()
