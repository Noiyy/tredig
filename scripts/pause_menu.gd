extends CanvasLayer

const MENU_NAV_DEADZONE := 0.55
const MENU_NAV_REPEAT_DELAY := 0.32
const MENU_NAV_REPEAT_INTERVAL := 0.08

var _held_menu_nav_action: StringName = &""
var _menu_nav_repeat_timer := 0.0
var _menu_nav_repeat_wait := MENU_NAV_REPEAT_DELAY

func _focus_resume_button() -> void:
	$CenterContainer/PauseOptions/ContinueButton.call_deferred("grab_focus")

func _ready() -> void:
	visible = false
	get_tree().paused = false
	if _is_expo_sandbox_enabled():
		$CenterContainer/PauseOptions/QuitButton.visible = false
		$CenterContainer/PauseOptions/QuitButton.focus_mode = Control.FOCUS_NONE


func _process(delta: float) -> void:
	_tick_controller_menu_navigation_repeat(delta)
	
func _input(_event: InputEvent) -> void:
	if not Input.is_action_just_pressed("ui_cancel"):
		return
	if get_tree().paused:
		if $SettingsMenu.visible:
			## Settings rieši ui_cancel v _unhandled_input / _input (zrušenie bindu, overlay, až back).
			return
		visible = false
		get_tree().paused = false
	else:
		visible = true
		get_tree().paused = true
		_focus_resume_button()

func _on_continue_button_pressed() -> void:
	hide()
	get_tree().paused = false


func _on_settings_button_pressed() -> void:
	$CenterContainer.visible = false
	$TextureRect.visible = false
	$SettingsMenu.visible = true
	$SettingsMenu/VBoxContainer/BackButton.call_deferred("grab_focus")


func _tick_controller_menu_navigation_repeat(delta: float) -> void:
	if not visible or not $CenterContainer.visible or $SettingsMenu.visible:
		_reset_controller_menu_navigation_repeat()
		return

	var action := _get_held_controller_menu_navigation_action()
	if action == &"":
		_reset_controller_menu_navigation_repeat()
		return

	if action != _held_menu_nav_action:
		_held_menu_nav_action = action
		_menu_nav_repeat_timer = 0.0
		_menu_nav_repeat_wait = MENU_NAV_REPEAT_DELAY
		return

	_menu_nav_repeat_timer += delta
	if _menu_nav_repeat_timer < _menu_nav_repeat_wait:
		return

	_menu_nav_repeat_timer = 0.0
	_menu_nav_repeat_wait = MENU_NAV_REPEAT_INTERVAL
	_emit_menu_navigation_action(action)


func _reset_controller_menu_navigation_repeat() -> void:
	_held_menu_nav_action = &""
	_menu_nav_repeat_timer = 0.0
	_menu_nav_repeat_wait = MENU_NAV_REPEAT_DELAY


func _get_held_controller_menu_navigation_action() -> StringName:
	for device in Input.get_connected_joypads():
		var axis_action := _get_held_controller_axis_navigation_action(device)
		if axis_action != &"":
			return axis_action

		if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN):
			return &"ui_down"
		if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP):
			return &"ui_up"
		if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT):
			return &"ui_right"
		if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT):
			return &"ui_left"

	return &""


func _get_held_controller_axis_navigation_action(device: int) -> StringName:
	var x := Input.get_joy_axis(device, JOY_AXIS_LEFT_X)
	var y := Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)
	if absf(y) >= absf(x) and absf(y) >= MENU_NAV_DEADZONE:
		return &"ui_down" if y > 0.0 else &"ui_up"
	if absf(x) >= MENU_NAV_DEADZONE:
		return &"ui_right" if x > 0.0 else &"ui_left"
	return &""


func _emit_menu_navigation_action(action: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)

	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)


func _on_menu_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_quit_button_pressed() -> void:
	if _is_expo_sandbox_enabled():
		return
	get_tree().quit()


func _is_expo_sandbox_enabled() -> bool:
	var sandbox := get_node_or_null("/root/ExpoSandbox")
	return sandbox != null and sandbox.has_method("is_enabled") and bool(sandbox.call("is_enabled"))
