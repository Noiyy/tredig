extends VBoxContainer

const LavaScript = preload("res://scripts/lava.gd")
const CONTROL_ACTIONS := [
	{"action": "p1_left", "label": "Player 1 Left"},
	{"action": "p1_right", "label": "Player 1 Right"},
	{"action": "p1_up", "label": "Player 1 Up"},
	{"action": "p1_down", "label": "Player 1 Down"},
	{"action": "p1_use", "label": "Player 1 Use"},
	{"action": "p2_left", "label": "Player 2 Left"},
	{"action": "p2_right", "label": "Player 2 Right"},
	{"action": "p2_up", "label": "Player 2 Up"},
	{"action": "p2_down", "label": "Player 2 Down"},
	{"action": "p2_use", "label": "Player 2 Use"},
	{"action": "pause", "label": "Pause"},
]

@onready var general_tab_button: Button = $TabsContainer/GeneralTabButton
@onready var controls_tab_button: Button = $TabsContainer/ControlsTabButton

@onready var general_section: VBoxContainer = $Sections/GeneralSection
@onready var controls_section: VBoxContainer = $Sections/ControlsSection

@onready var fullscreen_checkbox: CheckBox = $Sections/GeneralSection/MarginContainer/VBoxContainer/FullscreenCheckBox
@onready var lava_sound_checkbox: CheckBox = $Sections/GeneralSection/MarginContainer/VBoxContainer/LavaSoundCheckBox
@onready var main_volume_slider: HSlider = $Sections/GeneralSection/MainVolHSlider
@onready var music_volume_slider: HSlider = $Sections/GeneralSection/MusicVolHSlider
@onready var sfx_volume_slider: HSlider = $Sections/GeneralSection/SFXVolHSlider

@onready var p1_column: VBoxContainer = $Sections/ControlsSection/ScrollContainer/ControlsActions/P1Column
@onready var p2_column: VBoxContainer = $Sections/ControlsSection/ScrollContainer/ControlsActions/P2Column
@onready var reset_controls_button: Button = $Sections/ControlsSection/ControlsHintRow/ResetControlsButton

var _rebind_action := ""
var _rebind_button: Button
var _action_buttons: Dictionary = {}

func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)

	$BackButton.pressed.connect(_on_back_button_pressed)
	general_tab_button.pressed.connect(_on_general_tab_button_pressed)
	controls_tab_button.pressed.connect(_on_controls_tab_button_pressed)
	fullscreen_checkbox.toggled.connect(_on_fullscreen_check_box_toggled)
	lava_sound_checkbox.toggled.connect(_on_lava_sound_check_box_toggled)
	main_volume_slider.value_changed.connect(_on_main_vol_h_slider_value_changed)
	music_volume_slider.value_changed.connect(_on_music_vol_h_slider_value_changed)
	sfx_volume_slider.value_changed.connect(_on_sfx_vol_h_slider_value_changed)

	reset_controls_button.pressed.connect(_on_reset_controls_pressed)
	_build_controls_ui()
	_select_tab("general")
	_sync_from_system()


func _on_visibility_changed() -> void:
	if visible:
		_sync_from_system()
		_refresh_controls_ui()
		_select_tab("general")
	else:
		_cancel_rebind()


func _sync_from_system() -> void:
	var window_mode := DisplayServer.window_get_mode()
	fullscreen_checkbox.button_pressed = (
		window_mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		or window_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)
	lava_sound_checkbox.button_pressed = LavaScript.is_lava_sound_enabled()
	main_volume_slider.value = db_to_linear(
		AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))
	)
	music_volume_slider.value = db_to_linear(
		AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	)
	sfx_volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")))


func _on_back_button_pressed() -> void:
	close_settings()


## Called from pause menu when closing settings with Escape.
func close_settings() -> void:
	var parent = get_parent()
	_cancel_rebind()
	visible = false

	if parent.has_node("MainButtons"):
		parent.get_node("MainButtons").visible = true
		parent.get_node("BlackOverlay").visible = false
		parent.get_node("MainButtons/SettingsButton").grab_focus()
	elif parent.has_node("CenterContainer"):
		parent.get_node("CenterContainer").visible = true
		parent.get_node("TextureRect").visible = true
		parent.get_node("CenterContainer/PauseOptions/SettingsButton").grab_focus()


func _on_fullscreen_check_box_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _on_lava_sound_check_box_toggled(toggled_on: bool) -> void:
	LavaScript.set_lava_sound_enabled(toggled_on)


func _on_main_vol_h_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Master"), value)


func _on_music_vol_h_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Music"), value)


func _on_sfx_vol_h_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("SFX"), value)


func _on_general_tab_button_pressed() -> void:
	_select_tab("general")


func _on_controls_tab_button_pressed() -> void:
	_select_tab("controls")


func _select_tab(tab: String) -> void:
	var show_general := tab == "general"
	general_section.visible = show_general
	controls_section.visible = not show_general
	general_tab_button.disabled = show_general
	controls_tab_button.disabled = not show_general
	_set_tab_selected(general_tab_button, show_general)
	_set_tab_selected(controls_tab_button, not show_general)


func _set_tab_selected(btn: Button, selected: bool) -> void:
	if selected:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1.0, 1.0, 1.0, 0.18)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("disabled", style)
		btn.add_theme_color_override("font_disabled_color", Color(1.0, 1.0, 1.0, 1.0))
	else:
		btn.remove_theme_stylebox_override("disabled")
		btn.remove_theme_color_override("font_disabled_color")


func _on_reset_controls_pressed() -> void:
	_cancel_rebind()
	InputMap.load_from_project_settings()
	_refresh_controls_ui()


func _build_controls_ui() -> void:
	_action_buttons.clear()

	_add_column_header(p1_column, "Player 1", Color("#ff6f6f"))
	_add_column_header(p2_column, "Player 2", Color("#64b5ff"))

	for action_entry in CONTROL_ACTIONS:
		var action_name := str(action_entry["action"])
		var label_text := str(action_entry["label"])

		if action_name.begins_with("p1_"):
			_add_action_row(p1_column, action_name, label_text.trim_prefix("Player 1 "), true)
		elif action_name.begins_with("p2_"):
			_add_action_row(p2_column, action_name, "", false)
		else:
			var pause_row := HBoxContainer.new()
			pause_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			controls_section.add_child(pause_row)
			_add_action_row(pause_row, action_name, label_text, true)


func _add_column_header(column: VBoxContainer, title: String, dot_color: Color) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)

	var dot := Label.new()
	dot.text = "●"
	dot.add_theme_color_override("font_color", dot_color)
	dot.add_theme_font_size_override("font_size", 10)
	header.add_child(dot)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 12)
	header.add_child(title_label)

	column.add_child(header)


func _add_action_row(container: Node, action_name: String, label_text: String, show_label: bool) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if show_label:
		var action_label := Label.new()
		action_label.text = label_text
		action_label.custom_minimum_size = Vector2(60, 0)
		action_label.add_theme_font_size_override("font_size", 12)
		row.add_child(action_label)

	var bind_button := Button.new()
	bind_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bind_button.text = _get_action_text(action_name)
	bind_button.add_theme_font_size_override("font_size", 12)
	bind_button.pressed.connect(_on_rebind_button_pressed.bind(action_name, bind_button))
	row.add_child(bind_button)

	container.add_child(row)
	_action_buttons[action_name] = bind_button


func _refresh_controls_ui() -> void:
	for action_name: String in _action_buttons:
		var bind_button: Button = _action_buttons[action_name]
		if bind_button == _rebind_button:
			continue
		bind_button.text = _get_action_text(action_name)


func _on_rebind_button_pressed(action_name: String, bind_button: Button) -> void:
	_cancel_rebind()
	_rebind_action = action_name
	_rebind_button = bind_button
	_rebind_button.text = "Press any key..."


func _input(event: InputEvent) -> void:
	if _rebind_action.is_empty():
		return

	var key_event := event as InputEventKey
	if key_event == null:
		return
	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == KEY_ESCAPE:
		_cancel_rebind()
		get_viewport().set_input_as_handled()
		return

	var rebound_event := InputEventKey.new()
	rebound_event.keycode = key_event.keycode
	rebound_event.physical_keycode = key_event.physical_keycode
	rebound_event.shift_pressed = key_event.shift_pressed
	rebound_event.alt_pressed = key_event.alt_pressed
	rebound_event.ctrl_pressed = key_event.ctrl_pressed
	rebound_event.meta_pressed = key_event.meta_pressed

	InputMap.action_erase_events(_rebind_action)
	InputMap.action_add_event(_rebind_action, rebound_event)

	_cancel_rebind()
	_refresh_controls_ui()
	get_viewport().set_input_as_handled()


func _cancel_rebind() -> void:
	if _rebind_button != null:
		_rebind_button.text = _get_action_text(_rebind_action)
	_rebind_action = ""
	_rebind_button = null


func _get_action_text(action_name: String) -> String:
	var action_events := InputMap.action_get_events(action_name)
	for action_event in action_events:
		var key_event := action_event as InputEventKey
		if key_event != null:
			var keycode := key_event.physical_keycode
			if keycode == 0:
				keycode = key_event.keycode
			return OS.get_keycode_string(keycode)

	if action_events.is_empty():
		return "Unassigned"
	return action_events[0].as_text()
