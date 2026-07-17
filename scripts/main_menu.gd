extends Node2D

const MENU_NAV_DEADZONE := 0.55
const MENU_NAV_REPEAT_DELAY := 0.32
const MENU_NAV_REPEAT_INTERVAL := 0.08

const _PAGE_COUNT := 4
const _PAGE_HEADINGS := ["HowToHeadingBaseControls", "HowToHeadingProgress", "HowToHeadingProgress", "HowToHeadingGameLoop"]

var _last_main_buttons_focus: Control
var _held_menu_nav_action: StringName = &""
var _menu_nav_repeat_timer := 0.0
var _menu_nav_repeat_wait := MENU_NAV_REPEAT_DELAY
var _current_how_to_page := 1

func _ready() -> void:
	Music.set_gameplay_music(false)
	if _is_expo_sandbox_enabled():
		$MainButtons/QuitButton.visible = false
		$MainButtons/QuitButton.focus_mode = Control.FOCUS_NONE
	UI.decorate_buttons($MainButtons, "menu")
	UI.decorate_button($CreditsMenu/MarginContainer/BackButton)
	UI.decorate_button($HowToMenu/BackButton)
	$MainButtons/PlayButton.grab_focus()
	$HowToMenu/ChevronLeft.gui_input.connect(_on_chevron_left_input)
	$HowToMenu/ChevronRight.gui_input.connect(_on_chevron_right_input)


func _process(delta: float) -> void:
	_tick_controller_menu_navigation_repeat(delta)


func _unhandled_input(event: InputEvent) -> void:
	if $HowToMenu.visible:
		if event.is_action_pressed("ui_left"):
			_navigate_how_to_page(-1)
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("ui_right"):
			_navigate_how_to_page(1)
			get_viewport().set_input_as_handled()
			return

	if not event.is_action_pressed("ui_cancel"):
		return
	if not $SettingsMenu.visible and not $CreditsMenu.visible and not $HowToMenu.visible:
		return

	_on_back_button_pressed()
	get_viewport().set_input_as_handled()

func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file(str("res://scenes/main.tscn"))


func _on_settings_button_pressed() -> void:
	_capture_main_buttons_focus($MainButtons/SettingsButton)
	$MainButtons.visible = false
	$SettingsMenu.visible = true
	$BlackOverlay.visible = true


func _on_credits_button_pressed() -> void:
	_capture_main_buttons_focus($MainButtons/CreditsButton)
	$MainButtons.visible = false
	$CreditsMenu.visible = true
	$BlackOverlay.visible = true


func _on_how_to_button_pressed() -> void:
	_capture_main_buttons_focus($MainButtons/HowToButton)
	$MainButtons.visible = false
	$HowToMenu.visible = true
	$BlackOverlay.visible = true
	_current_how_to_page = 1
	_update_how_to_page()


func _on_quit_button_pressed() -> void:
	if _is_expo_sandbox_enabled():
		return
	get_tree().quit()


func _on_back_button_pressed() -> void:
	var was_settings_open: bool = $SettingsMenu.visible
	var was_credits_open: bool = $CreditsMenu.visible
	var was_how_to_open: bool = $HowToMenu.visible
	$MainButtons.visible = true
	$BlackOverlay.visible = false

	if was_settings_open:
		$SettingsMenu.visible = false
		
	if was_credits_open:
		$CreditsMenu.visible = false
	
	if was_how_to_open:
		$HowToMenu.visible = false

	var fallback := $MainButtons/PlayButton
	if was_settings_open:
		fallback = $MainButtons/SettingsButton
	elif was_credits_open:
		fallback = $MainButtons/CreditsButton
	elif was_how_to_open:
		fallback = $MainButtons/HowToButton
	_restore_main_buttons_focus(
		fallback
	)


func _is_expo_sandbox_enabled() -> bool:
	var sandbox := get_node_or_null("/root/ExpoSandbox")
	return sandbox != null and sandbox.has_method("is_enabled") and bool(sandbox.call("is_enabled"))


func _capture_main_buttons_focus(fallback: Control) -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and $MainButtons.is_ancestor_of(focused):
		_last_main_buttons_focus = focused
		return
	_last_main_buttons_focus = fallback


func _restore_main_buttons_focus(fallback: Control) -> void:
	var target := _last_main_buttons_focus if _last_main_buttons_focus != null else fallback
	if target != null and is_instance_valid(target):
		target.call_deferred("grab_focus")


func _tick_controller_menu_navigation_repeat(delta: float) -> void:
	if not $MainButtons.visible and not $CreditsMenu.visible and not $HowToMenu.visible:
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


func _navigate_how_to_page(direction: int) -> void:
	var new_page := _current_how_to_page + direction
	if new_page < 1 or new_page > _PAGE_COUNT:
		return
	_current_how_to_page = new_page
	_update_how_to_page()


func _update_how_to_page() -> void:
	for i in range(1, _PAGE_COUNT + 1):
		$HowToMenu.get_node(str(i)).visible = (i == _current_how_to_page)
	$HowToMenu/PageNum.text = "%d/%d" % [_current_how_to_page, _PAGE_COUNT]
	$HowToMenu/HeadingTextureRect/Label.text = _PAGE_HEADINGS[_current_how_to_page - 1]
	$HowToMenu/ChevronLeft.modulate = Color(1, 1, 1, 0.5 if _current_how_to_page == 1 else 1.0)
	$HowToMenu/ChevronRight.modulate = Color(1, 1, 1, 0.5 if _current_how_to_page == _PAGE_COUNT else 1.0)


func _on_chevron_left_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_navigate_how_to_page(-1)


func _on_chevron_right_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_navigate_how_to_page(1)


func _on_fullscreen_check_box_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)


func _on_main_vol_h_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Master"), value)


func _on_music_vol_h_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Music"), value)


func _on_sfx_vol_h_slider_3_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("SFX"), value)
