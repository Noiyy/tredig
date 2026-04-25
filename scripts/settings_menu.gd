extends Control

const LavaScript = preload("res://scripts/lava.gd")
const TAB_PREV_BUTTON := JOY_BUTTON_LEFT_SHOULDER
const TAB_NEXT_BUTTON := JOY_BUTTON_RIGHT_SHOULDER
const TAB_ORDER := [&"general", &"controls", &"controller"]
const DEFAULT_FULLSCREEN := false
const DEFAULT_LAVA_SOUND := true
## dB z res://default_bus_layout.tres (Master: engine default 0 dB, v súbore nie je uvedený)
const DEFAULT_MASTER_DB := 0.0
const DEFAULT_MUSIC_DB := -8.798218
const DEFAULT_SFX_DB := -10.0691595
const CONTROLLER_BIND_ACTIONS := [
	{"id": &"up", "label": "Jump", "side": -1},
	{"id": &"left", "label": "Walk Left", "side": -1},
	{"id": &"right", "label": "Walk Right", "side": -1},
	{"id": &"down", "label": "Walk Down", "side": -1},
	{"id": &"ui_cancel", "label": "Pause", "side": 1},
	{"id": &"use", "label": "Dig", "side": 1}
]
const CONTROLLER_STATIC_LABELS := [
	{"id": &"move_left", "label": "Move", "side": 1, "anchor": "LStick"},
	{"id": &"move_right", "label": "Move", "side": 1, "anchor": "LStick"}
]
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
	{"action": "ui_cancel", "label": "Pause"},
]

@onready var general_tab_button: Button = $VBoxContainer/TabsContainer/GeneralTabButton
@onready var controls_tab_button: Button = $VBoxContainer/TabsContainer/ControlsTabButton
@onready var controller_tab_button: Button = $VBoxContainer/TabsContainer/ControllerTabButton

@onready var general_section: VBoxContainer = $VBoxContainer/Sections/GeneralSection
@onready var controls_section: VBoxContainer = $VBoxContainer/Sections/ControlsSection
@onready var controller_section: VBoxContainer = $VBoxContainer/Sections/ControllerSection

@onready var fullscreen_checkbox: CheckBox = $VBoxContainer/Sections/GeneralSection/MarginContainer/VBoxContainer/FullscreenCheckBox
@onready var lava_sound_checkbox: CheckBox = $VBoxContainer/Sections/GeneralSection/MarginContainer/VBoxContainer/LavaSoundCheckBox
@onready var main_volume_slider: HSlider = $VBoxContainer/Sections/GeneralSection/MainVolHSlider
@onready var music_volume_slider: HSlider = $VBoxContainer/Sections/GeneralSection/MusicVolHSlider
@onready var sfx_volume_slider: HSlider = $VBoxContainer/Sections/GeneralSection/SFXVolHSlider
@onready var reset_general_button: Button = $VBoxContainer/Sections/GeneralSection/GeneralHintRow/ResetGeneralButton

@onready var p1_column: VBoxContainer = $VBoxContainer/Sections/ControlsSection/ScrollContainer/ControlsActions/P1Column
@onready var p2_column: VBoxContainer = $VBoxContainer/Sections/ControlsSection/ScrollContainer/ControlsActions/P2Column
@onready var reset_controls_button: Button = $VBoxContainer/Sections/ControlsSection/ControlsHintRow/ResetControlsButton
@onready var controls_scroll_container: ScrollContainer = $VBoxContainer/Sections/ControlsSection/ScrollContainer
@onready var controller_subtabs_row: HBoxContainer = $VBoxContainer/Sections/ControllerSection/ControllerSubTabsRow
@onready var controller_p1_subtab: Button = $VBoxContainer/Sections/ControllerSection/ControllerSubTabsRow/ControllerP1Subtab
@onready var controller_p2_subtab: Button = $VBoxContainer/Sections/ControllerSection/ControllerSubTabsRow/ControllerP2Subtab
@onready var controller_left_column: VBoxContainer = $VBoxContainer/Sections/ControllerSection/ControllerLayout/ControllerLeftPanel/ControllerLeftColumn
@onready var controller_right_column: VBoxContainer = $VBoxContainer/Sections/ControllerSection/ControllerLayout/ControllerRightPanel/ControllerRightColumn
@onready var controller_connector_layer: Control = $ControllerConnectorLayer
@onready var controller_image: TextureRect = $VBoxContainer/Sections/ControllerSection/ControllerLayout/ControllerCenterPanel/ControllerCenterMargin/ControllerImage
@onready var controller_hint_label: Label = $VBoxContainer/Sections/ControllerSection/ControllerHintRow/ControllerHint
@onready var reset_controller_button: Button = $VBoxContainer/Sections/ControllerSection/ControllerHintRow/ResetControllerButton
@onready var controller_edit_button: Button = $VBoxContainer/Sections/ControllerSection/ControllerHintRow/EditControllerButton
@onready var controller_overlay: ColorRect = $ControllerEditOverlay
@onready var controller_overlay_p1_up_button: Button = $ControllerEditOverlay/CenterContainer/PanelContainer/VBoxContainer/Columns/P1Column/P1UpRow/P1UpButton
@onready var controller_overlay_p1_left_button: Button = $ControllerEditOverlay/CenterContainer/PanelContainer/VBoxContainer/Columns/P1Column/P1LeftRow/P1LeftButton
@onready var controller_overlay_p1_right_button: Button = $ControllerEditOverlay/CenterContainer/PanelContainer/VBoxContainer/Columns/P1Column/P1RightRow/P1RightButton
@onready var controller_overlay_p1_down_button: Button = $ControllerEditOverlay/CenterContainer/PanelContainer/VBoxContainer/Columns/P1Column/P1DownRow/P1DownButton
@onready var controller_overlay_p1_use_button: Button = $ControllerEditOverlay/CenterContainer/PanelContainer/VBoxContainer/Columns/P1Column/P1UseRow/P1UseButton
@onready var controller_overlay_p2_up_button: Button = $ControllerEditOverlay/CenterContainer/PanelContainer/VBoxContainer/Columns/P2Column/P2UpRow/P2UpButton
@onready var controller_overlay_p2_left_button: Button = $ControllerEditOverlay/CenterContainer/PanelContainer/VBoxContainer/Columns/P2Column/P2LeftRow/P2LeftButton
@onready var controller_overlay_p2_right_button: Button = $ControllerEditOverlay/CenterContainer/PanelContainer/VBoxContainer/Columns/P2Column/P2RightRow/P2RightButton
@onready var controller_overlay_p2_down_button: Button = $ControllerEditOverlay/CenterContainer/PanelContainer/VBoxContainer/Columns/P2Column/P2DownRow/P2DownButton
@onready var controller_overlay_p2_use_button: Button = $ControllerEditOverlay/CenterContainer/PanelContainer/VBoxContainer/Columns/P2Column/P2UseRow/P2UseButton
@onready var controller_overlay_pause_button: Button = $ControllerEditOverlay/CenterContainer/PanelContainer/VBoxContainer/PauseRow/PauseButton
@onready var controller_overlay_confirm_button: Button = $ControllerEditOverlay/CenterContainer/PanelContainer/VBoxContainer/ButtonsRow/ConfirmButton
@onready var controller_overlay_cancel_button: Button = $ControllerEditOverlay/CenterContainer/PanelContainer/VBoxContainer/ButtonsRow/CancelButton
@onready var controller_overlay_reset_button: Button = $ControllerEditOverlay/CenterContainer/PanelContainer/VBoxContainer/ButtonsRow/ResetButton
@onready var back_button: Button = $VBoxContainer/BackButton

var _rebind_action := ""
var _rebind_button: Button
var _rebind_mode := ""
var _action_buttons: Dictionary = {}
var _controller_action_buttons: Dictionary = {}
var _first_controls_focus_button: Button
var _first_controller_focus_button: Button
var _selected_tab: StringName = &"general"
var _controller_connectors: ControllerConnectorLayer
var _controller_static_move_blocks: Dictionary = {}
## 1 = Player 1 preview, 2 = Player 2
var _controller_preview_slot: int = 1
var _overlay_action_buttons: Dictionary = {}
var _overlay_bindings: Dictionary = {}
var _overlay_rebind_action := ""
var _overlay_rebind_button: Button
var _controller_overlay_open := false

func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	get_viewport().gui_focus_changed.connect(_on_gui_focus_changed)

	back_button.pressed.connect(_on_back_button_pressed)
	general_tab_button.pressed.connect(_on_general_tab_button_pressed)
	controls_tab_button.pressed.connect(_on_controls_tab_button_pressed)
	controller_tab_button.pressed.connect(_on_controller_tab_button_pressed)
	controller_p1_subtab.toggled.connect(_on_controller_p1_subtab_toggled)
	controller_p2_subtab.toggled.connect(_on_controller_p2_subtab_toggled)
	fullscreen_checkbox.toggled.connect(_on_fullscreen_check_box_toggled)
	lava_sound_checkbox.toggled.connect(_on_lava_sound_check_box_toggled)
	main_volume_slider.value_changed.connect(_on_main_vol_h_slider_value_changed)
	music_volume_slider.value_changed.connect(_on_music_vol_h_slider_value_changed)
	sfx_volume_slider.value_changed.connect(_on_sfx_vol_h_slider_value_changed)
	reset_general_button.pressed.connect(_on_reset_general_pressed)

	reset_controls_button.pressed.connect(_on_reset_controls_pressed)
	controller_edit_button.pressed.connect(_on_controller_edit_pressed)
	controller_overlay_confirm_button.pressed.connect(_on_controller_overlay_confirm_pressed)
	controller_overlay_cancel_button.pressed.connect(_on_controller_overlay_cancel_pressed)
	controller_overlay_reset_button.pressed.connect(_on_controller_overlay_reset_pressed)
	_overlay_action_buttons = {
		"p1_up": controller_overlay_p1_up_button,
		"p1_left": controller_overlay_p1_left_button,
		"p1_right": controller_overlay_p1_right_button,
		"p1_down": controller_overlay_p1_down_button,
		"p1_use": controller_overlay_p1_use_button,
		"p2_up": controller_overlay_p2_up_button,
		"p2_left": controller_overlay_p2_left_button,
		"p2_right": controller_overlay_p2_right_button,
		"p2_down": controller_overlay_p2_down_button,
		"p2_use": controller_overlay_p2_use_button,
		"ui_cancel": controller_overlay_pause_button
	}
	for action_name in _overlay_action_buttons.keys():
		var bind_button: Button = _overlay_action_buttons[action_name]
		bind_button.pressed.connect(_on_overlay_action_button_pressed.bind(String(action_name), bind_button))
	_setup_controller_overlay_focus_neighbors()
	controller_hint_label.text = "Current controller bindings preview"
	reset_controller_button.visible = false
	controller_overlay.visible = false
	_build_controls_ui()
	_init_controller_connector_layer()
	_build_controller_ui()
	_set_controller_subtab(1, false)
	_select_tab("general")
	_sync_from_system()


func _on_visibility_changed() -> void:
	if visible:
		_sync_from_system()
		_refresh_controls_ui()
		_refresh_controller_ui()
		_select_tab("general")
		_update_controller_connectors()
		call_deferred("_update_controller_connectors")
		_focus_default_for_current_tab()
	else:
		_cancel_rebind()
		_close_controller_overlay(false)
		_update_controller_connectors()


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

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if _controller_overlay_open:
		if not _overlay_rebind_action.is_empty() and event.is_action_pressed("ui_cancel"):
			_cancel_overlay_rebind()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_cancel"):
			_close_controller_overlay(false)
			get_viewport().set_input_as_handled()
			return
		if _is_tab_next_event(event) or _is_tab_prev_event(event):
			get_viewport().set_input_as_handled()
			return
		return

	if not _rebind_action.is_empty() and event.is_action_pressed("ui_cancel"):
		_cancel_rebind()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		close_settings()
		get_viewport().set_input_as_handled()
		return

	if _is_tab_next_event(event):
		_cycle_tab(1)
		get_viewport().set_input_as_handled()
		return

	if _is_tab_prev_event(event):
		_cycle_tab(-1)
		get_viewport().set_input_as_handled()
		return


## Called from pause menu when closing settings with Escape.
func close_settings() -> void:
	var parent = get_parent()
	_cancel_rebind()
	_close_controller_overlay(false)

	if parent.has_node("MainButtons") and parent.has_method("_on_back_button_pressed"):
		parent.call("_on_back_button_pressed")
		visible = false
		return

	visible = false
	if parent.has_node("MainButtons"):
		parent.get_node("MainButtons").visible = true
		parent.get_node("BlackOverlay").visible = false
		parent.get_node("MainButtons/SettingsButton").grab_focus()
	elif parent.has_node("CenterContainer"):
		parent.get_node("CenterContainer").visible = true
		parent.get_node("TextureRect").visible = true
		parent.get_node("CenterContainer/PauseOptions/SettingsButton").call_deferred("grab_focus")


func _on_fullscreen_check_box_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	UserSettings.save()


func _on_lava_sound_check_box_toggled(toggled_on: bool) -> void:
	LavaScript.set_lava_sound_enabled(toggled_on)
	UserSettings.save()


func _on_main_vol_h_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Master"), value)
	UserSettings.save()


func _on_music_vol_h_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Music"), value)
	UserSettings.save()


func _on_sfx_vol_h_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("SFX"), value)
	UserSettings.save()


func _on_reset_general_pressed() -> void:
	var default_master_linear := db_to_linear(DEFAULT_MASTER_DB)
	var default_music_linear := db_to_linear(DEFAULT_MUSIC_DB)
	var default_sfx_linear := db_to_linear(DEFAULT_SFX_DB)
	fullscreen_checkbox.set_pressed_no_signal(DEFAULT_FULLSCREEN)
	lava_sound_checkbox.set_pressed_no_signal(DEFAULT_LAVA_SOUND)
	main_volume_slider.set_value_no_signal(default_master_linear)
	music_volume_slider.set_value_no_signal(default_music_linear)
	sfx_volume_slider.set_value_no_signal(default_sfx_linear)
	if DEFAULT_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	LavaScript.set_lava_sound_enabled(DEFAULT_LAVA_SOUND)
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Master"), default_master_linear)
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Music"), default_music_linear)
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("SFX"), default_sfx_linear)
	UserSettings.save()


func _on_general_tab_button_pressed() -> void:
	_select_tab("general")


func _on_controls_tab_button_pressed() -> void:
	_select_tab("controls")


func _on_controller_tab_button_pressed() -> void:
	_select_tab("controller")


func _on_controller_p1_subtab_toggled(pressed: bool) -> void:
	if not pressed: return
	_set_controller_subtab(1)


func _on_controller_p2_subtab_toggled(pressed: bool) -> void:
	if not pressed: return
	_set_controller_subtab(2)


## Vizuál minitabov: `ButtonGroup` + `toggle_mode` v sceni; sem len sync + náhľad. `refresh` false po buildi.
func _set_controller_subtab(slot: int, refresh: bool = true) -> void:
	if slot < 1 or slot > 2:
		return
	_controller_preview_slot = slot
	if is_instance_valid(controller_p1_subtab):
		controller_p1_subtab.set_pressed_no_signal(slot == 1)
	if is_instance_valid(controller_p2_subtab):
		controller_p2_subtab.set_pressed_no_signal(slot == 2)
	if refresh:
		_refresh_controller_ui()
	else:
		_update_move_preview_blocks_for_slot()
		## Kĺzna čiara Move: get_global_rect() až po ďalšom layoute po zmene visible
		call_deferred("_update_controller_connectors")


func _select_tab(tab: String) -> void:
	_selected_tab = StringName(tab)
	var show_general := tab == "general"
	var show_controls := tab == "controls"
	var show_controller := tab == "controller"
	if is_instance_valid(controller_subtabs_row):
		controller_subtabs_row.visible = show_controller
	general_section.visible = show_general
	controls_section.visible = show_controls
	controller_section.visible = show_controller
	general_tab_button.disabled = show_general
	controls_tab_button.disabled = show_controls
	controller_tab_button.disabled = show_controller
	_set_tab_selected(general_tab_button, show_general)
	_set_tab_selected(controls_tab_button, show_controls)
	_set_tab_selected(controller_tab_button, show_controller)
	if show_controller:
		_refresh_controller_ui()
		_update_controller_connectors()
		call_deferred("_update_controller_connectors")
	else:
		_update_controller_connectors()
	if visible:
		_focus_default_for_current_tab()


func _set_tab_selected(btn: Button, selected: bool) -> void:
	if selected:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1.0, 1.0, 1.0, 0.18)
		style.border_color = Color(1.0, 1.0, 1.0, 1.0)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
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
	_refresh_controller_ui()
	UserSettings.save()


func _on_reset_controller_pressed() -> void:
	_cancel_rebind()
	InputMap.load_from_project_settings()
	_refresh_controls_ui()
	_refresh_controller_ui()
	UserSettings.save()


func _build_controls_ui() -> void:
	_action_buttons.clear()
	_first_controls_focus_button = null

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
	bind_button.text = _get_keyboard_action_text(action_name)
	bind_button.add_theme_font_size_override("font_size", 12)
	bind_button.pressed.connect(_on_rebind_button_pressed.bind(action_name, bind_button))
	bind_button.focus_entered.connect(_on_focusable_control_focused.bind(bind_button))
	row.add_child(bind_button)

	container.add_child(row)
	_action_buttons[action_name] = bind_button
	if _first_controls_focus_button == null:
		_first_controls_focus_button = bind_button


func _refresh_controls_ui() -> void:
	for action_name: String in _action_buttons:
		var bind_button: Button = _action_buttons[action_name]
		if bind_button == _rebind_button:
			continue
		bind_button.text = _get_keyboard_action_text(action_name)


func _build_controller_ui() -> void:
	_controller_action_buttons.clear()
	_controller_static_move_blocks.clear()
	_first_controller_focus_button = controller_edit_button
	for child in controller_left_column.get_children():
		child.queue_free()
	for child in controller_right_column.get_children():
		child.queue_free()

	var left_entries: Array = []
	var right_entries: Array = []
	for bind_entry in CONTROLLER_BIND_ACTIONS:
		if int(bind_entry["side"]) < 0:
			left_entries.append(bind_entry)
		else:
			right_entries.append(bind_entry)

	_populate_controller_column(controller_left_column, left_entries, -1)
	_populate_controller_column(controller_right_column, right_entries, 1)
	_add_static_controller_labels(controller_left_column, -1)
	_add_static_controller_labels(controller_right_column, 1)

	_update_controller_connectors()


func _populate_controller_column(column: VBoxContainer, entries: Array, side: int) -> void:
	_add_column_spacer(column)
	for bind_entry in entries:
		var action_id: StringName = bind_entry["id"]
		var label_text := str(bind_entry["label"])
		var info_label := _create_controller_action_label(action_id, label_text, side)
		column.add_child(info_label)
		_controller_action_buttons[String(action_id)] = info_label
		_register_connector(action_id, info_label)
		_add_column_spacer(column)


func _add_expander_to(parent: Control) -> void:
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(spacer)


func _add_column_spacer(column: VBoxContainer) -> void:
	_add_expander_to(column)


func _create_controller_action_label(_action_id: StringName, label_text: String, side: int = -1) -> Label:
	var info_label := Label.new()
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label.text = "%s" % [label_text]
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if side < 0 else HORIZONTAL_ALIGNMENT_RIGHT
	info_label.add_theme_font_size_override("font_size", 11)
	return info_label


func _add_static_controller_labels(column: VBoxContainer, side: int) -> void:
	for label_entry in CONTROLLER_STATIC_LABELS:
		if int(label_entry["side"]) != side:
			continue
		var label_id: StringName = label_entry["id"]
		var label_text := str(label_entry["label"])
		var block := VBoxContainer.new()
		block.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_add_expander_to(block)
		var info_label := _create_controller_static_label(label_text, side)
		block.add_child(info_label)
		_add_expander_to(block)
		var anchor_name := str(label_entry["anchor"])
		_register_static_connector(label_id, info_label, anchor_name, side)
		column.add_child(block)
		_controller_static_move_blocks[String(label_id)] = block


func _create_controller_static_label(label_text: String, side: int = -1) -> Label:
	var info_label := Label.new()
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label.text = label_text
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if side < 0 else HORIZONTAL_ALIGNMENT_RIGHT
	info_label.add_theme_font_size_override("font_size", 11)
	return info_label


func _refresh_controller_ui() -> void:
	for action_id_key: String in _controller_action_buttons:
		var info_label: Label = _controller_action_buttons[action_id_key]
		var action_id := StringName(action_id_key)
		info_label.text = "%s" % [_get_controller_action_label(action_id)]
		_register_connector(action_id, info_label)
	_update_move_preview_blocks_for_slot()
	_update_controller_connectors()
	## Po prepnutí P1/P2 (viditeľnosť bloku „Move“) ešte nie je hotový layout v tom istom snímku.
	call_deferred("_update_controller_connectors")


func _update_move_preview_blocks_for_slot() -> void:
	if _controller_static_move_blocks.is_empty():
		return
	if _controller_static_move_blocks.has("move_left"):
		var bl: Control = _controller_static_move_blocks["move_left"] as Control
		if is_instance_valid(bl):
			bl.visible = (_controller_preview_slot == 1)
	if _controller_static_move_blocks.has("move_right"):
		var br: Control = _controller_static_move_blocks["move_right"] as Control
		if is_instance_valid(br):
			br.visible = (_controller_preview_slot == 2)


func _on_rebind_button_pressed(action_name: String, bind_button: Button) -> void:
	_cancel_rebind()
	_rebind_action = action_name
	_rebind_button = bind_button
	_rebind_mode = "keyboard"
	_rebind_button.text = "Press any key..."


func _on_controller_rebind_button_pressed(action_id: StringName, bind_button: Button) -> void:
	_cancel_rebind()
	_rebind_action = String(action_id)
	_rebind_button = bind_button
	_rebind_mode = "controller"
	_rebind_button.text = "%s: Press gamepad..." % _get_controller_action_label(action_id)


func _on_controller_edit_pressed() -> void:
	if controller_overlay == null:
		return
	_close_controller_overlay(false)
	_overlay_bindings = _collect_current_controller_bindings()
	_controller_overlay_open = true
	controller_overlay.visible = true
	_refresh_overlay_action_buttons()
	if controller_overlay_p1_up_button != null:
		controller_overlay_p1_up_button.call_deferred("grab_focus")


func _on_overlay_action_button_pressed(action_name: String, bind_button: Button) -> void:
	_cancel_overlay_rebind()
	_overlay_rebind_action = action_name
	_overlay_rebind_button = bind_button
	_overlay_rebind_button.text = "Press gamepad..."


func _on_controller_overlay_confirm_pressed() -> void:
	_cancel_overlay_rebind()
	_apply_controller_bindings(_overlay_bindings)
	_close_controller_overlay(true)


func _on_controller_overlay_cancel_pressed() -> void:
	_close_controller_overlay(false)


func _on_controller_overlay_reset_pressed() -> void:
	_cancel_overlay_rebind()
	InputMap.load_from_project_settings()
	_refresh_controls_ui()
	_refresh_controller_ui()
	UserSettings.save()
	_close_controller_overlay(true)


func _input(event: InputEvent) -> void:
	if _controller_overlay_open:
		if _handle_controller_overlay_rebind_input(event):
			get_viewport().set_input_as_handled()
		return

	if _rebind_action.is_empty():
		return

	if event.is_action_pressed("ui_cancel"):
		_cancel_rebind()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event == null or not key_event.pressed or key_event.echo:
			return
		if _rebind_mode != "keyboard":
			return

		var rebound_event := InputEventKey.new()
		rebound_event.keycode = key_event.keycode
		rebound_event.physical_keycode = key_event.physical_keycode
		rebound_event.shift_pressed = key_event.shift_pressed
		rebound_event.alt_pressed = key_event.alt_pressed
		rebound_event.ctrl_pressed = key_event.ctrl_pressed
		rebound_event.meta_pressed = key_event.meta_pressed

		_replace_keyboard_binding(_rebind_action, rebound_event)
		_cancel_rebind()
		_refresh_controls_ui()
		_refresh_controller_ui()
		UserSettings.save()
		get_viewport().set_input_as_handled()
		return

	if _rebind_mode != "controller":
		return

	var joy_button_event := event as InputEventJoypadButton
	if joy_button_event != null and joy_button_event.pressed:
		var rebound_button := InputEventJoypadButton.new()
		rebound_button.button_index = joy_button_event.button_index
		rebound_button.device = -1
		_replace_controller_binding_for_all_devices(StringName(_rebind_action), rebound_button)
		_cancel_rebind()
		_refresh_controls_ui()
		_refresh_controller_ui()
		UserSettings.save()
		get_viewport().set_input_as_handled()
		return

	var joy_axis_event := event as InputEventJoypadMotion
	if joy_axis_event != null and absf(joy_axis_event.axis_value) >= 0.5:
		var rebound_axis := InputEventJoypadMotion.new()
		rebound_axis.axis = joy_axis_event.axis
		rebound_axis.axis_value = -1.0 if joy_axis_event.axis_value < 0.0 else 1.0
		rebound_axis.device = -1
		_replace_controller_binding_for_all_devices(StringName(_rebind_action), rebound_axis)
		_cancel_rebind()
		_refresh_controls_ui()
		_refresh_controller_ui()
		UserSettings.save()
		get_viewport().set_input_as_handled()
		return


func _handle_controller_overlay_rebind_input(event: InputEvent) -> bool:
	if _overlay_rebind_action.is_empty():
		return false

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			_cancel_overlay_rebind()
			return true

	if event.is_action_pressed("ui_cancel"):
		_cancel_overlay_rebind()
		return true

	var joy_button_event := event as InputEventJoypadButton
	if joy_button_event != null and joy_button_event.pressed:
		var rebound_button := InputEventJoypadButton.new()
		rebound_button.button_index = joy_button_event.button_index
		rebound_button.device = -1
		_set_overlay_binding(_overlay_rebind_action, rebound_button)
		_cancel_overlay_rebind()
		_refresh_overlay_action_buttons()
		return true

	var joy_axis_event := event as InputEventJoypadMotion
	if joy_axis_event != null and absf(joy_axis_event.axis_value) >= 0.5:
		var rebound_axis := InputEventJoypadMotion.new()
		rebound_axis.axis = joy_axis_event.axis
		rebound_axis.axis_value = -1.0 if joy_axis_event.axis_value < 0.0 else 1.0
		rebound_axis.device = -1
		_set_overlay_binding(_overlay_rebind_action, rebound_axis)
		_cancel_overlay_rebind()
		_refresh_overlay_action_buttons()
		return true

	return false


func _cancel_overlay_rebind() -> void:
	if _overlay_rebind_button != null:
		_overlay_rebind_button.text = _get_display_binding_text_for_action(
			_overlay_rebind_action, _overlay_bindings.get(_overlay_rebind_action, null)
		)
	_overlay_rebind_action = ""
	_overlay_rebind_button = null


func _collect_current_controller_bindings() -> Dictionary:
	var bindings := {}
	for action_name in _overlay_action_buttons.keys():
		bindings[action_name] = _get_controller_event_for_action(String(action_name))
	return bindings


func _set_overlay_binding(action_name: String, event: InputEvent) -> void:
	_overlay_bindings[action_name] = _normalize_controller_event_for_action(action_name, event)


func _refresh_overlay_action_buttons() -> void:
	for action_name in _overlay_action_buttons.keys():
		var button: Button = _overlay_action_buttons[action_name]
		if button == _overlay_rebind_button:
			continue
		button.text = _get_display_binding_text_for_action(
			action_name, _overlay_bindings.get(action_name, null)
		)


func _inputmap_set_single_gamepad_event_for_action(action_name: String, new_controller_event: InputEvent) -> void:
	## Nahrá jediný gamepad vstup; klávesnicu a ostatné (nie joypad) nechá.
	if not InputMap.has_action(action_name):
		return
	var existing_events := InputMap.action_get_events(action_name)
	InputMap.action_erase_events(action_name)
	for existing_event in existing_events:
		if existing_event is InputEventJoypadButton or existing_event is InputEventJoypadMotion:
			continue
		InputMap.action_add_event(action_name, existing_event)
	if new_controller_event != null:
		InputMap.action_add_event(action_name, new_controller_event.duplicate())


func _apply_controller_bindings(bindings: Dictionary) -> void:
	for action_name in bindings.keys():
		var bound_event: InputEvent = bindings[action_name]
		_inputmap_set_single_gamepad_event_for_action(String(action_name), bound_event)
	_refresh_controls_ui()
	_refresh_controller_ui()
	UserSettings.save()


func _close_controller_overlay(refresh_main_ui: bool) -> void:
	_cancel_overlay_rebind()
	_controller_overlay_open = false
	if controller_overlay != null:
		controller_overlay.visible = false
	if controller_edit_button != null and visible:
		controller_edit_button.call_deferred("grab_focus")
	if refresh_main_ui:
		_refresh_controller_ui()
		_update_controller_connectors()


func _cancel_rebind() -> void:
	if _rebind_button != null:
		if _rebind_mode == "keyboard":
			_rebind_button.text = _get_keyboard_action_text(_rebind_action)
		elif _rebind_mode == "controller":
			_rebind_button.text = "%s" % [_get_action_label(_rebind_action)]
	_rebind_action = ""
	_rebind_button = null
	_rebind_mode = ""


func _get_keyboard_action_text(action_name: String) -> String:
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


func _get_controller_action_text(action_id: StringName) -> String:
	if action_id == &"ui_cancel":
		return _get_controller_action_text_for_action("ui_cancel")

	var p1_action := "p1_%s" % String(action_id)
	var p2_action := "p2_%s" % String(action_id)
	var p1_text := _get_controller_action_text_for_action(p1_action)
	var p2_text := _get_controller_action_text_for_action(p2_action)
	if p1_text == p2_text:
		return p1_text
	return "P1 %s | P2 %s" % [p1_text, p2_text]


func _get_controller_preview_text_for_action_id(action_id: StringName) -> String:
	if action_id == &"ui_cancel":
		return _get_controller_action_text_for_action("ui_cancel")
	var prefix := "p1_" if _controller_preview_slot == 1 else "p2_"
	return _get_controller_action_text_for_action(prefix + String(action_id))


func _get_controller_action_text_for_action(action_name: String) -> String:
	return _get_display_binding_text_for_action(action_name, _get_controller_event_for_action(action_name))


func _get_controller_event_for_action(action_name: String) -> InputEvent:
	if not InputMap.has_action(action_name):
		return null
	for action_event in InputMap.action_get_events(action_name):
		if action_event is InputEventJoypadButton or action_event is InputEventJoypadMotion:
			return _normalize_controller_event_for_action(action_name, action_event)
	return null


func _normalize_controller_event_for_action(action_name: String, event: InputEvent) -> InputEvent:
	if event == null:
		return null
	var target_device := _target_device_for_action(action_name)
	var normalized := event.duplicate()
	var joy_button := normalized as InputEventJoypadButton
	if joy_button != null:
		joy_button.device = target_device
		return joy_button
	var joy_axis := normalized as InputEventJoypadMotion
	if joy_axis != null:
		joy_axis.device = target_device
		joy_axis.axis_value = -1.0 if joy_axis.axis_value < 0.0 else 1.0
		return joy_axis
	return normalized


func _target_device_for_action(action_name: String) -> int:
	if action_name.begins_with("p1_"):
		return 0
	if action_name.begins_with("p2_"):
		return 1
	return -1


func _get_display_binding_text_for_action(action_name: String, event: InputEvent) -> String:
	if event == null:
		return "Unassigned"
	var dpad_caption := _get_dpad_caption_if_movement_action(action_name, event)
	if not dpad_caption.is_empty():
		return dpad_caption
	return _get_binding_text_from_event(event)


## Left-stick default bindings are shown as D-pad names/lines; InputMap still uses JOY_AXIS_LEFT_*.
func _get_dpad_caption_if_movement_action(action_name: String, event: InputEvent) -> String:
	var as_btn := event as InputEventJoypadButton
	if as_btn != null:
		match as_btn.button_index:
			JOY_BUTTON_DPAD_UP:
				if action_name.ends_with("_up"):
					return "DPad Up"
			JOY_BUTTON_DPAD_DOWN:
				if action_name.ends_with("_down"):
					return "DPad Down"
			JOY_BUTTON_DPAD_LEFT:
				if action_name.ends_with("_left"):
					return "DPad Left"
			JOY_BUTTON_DPAD_RIGHT:
				if action_name.ends_with("_right"):
					return "DPad Right"
		return ""
	var m := event as InputEventJoypadMotion
	if m == null:
		return ""
	if m.axis == JOY_AXIS_LEFT_X and m.axis_value < 0.0:
		if action_name.ends_with("_left"):
			return "DPad Left"
	elif m.axis == JOY_AXIS_LEFT_X and m.axis_value > 0.0:
		if action_name.ends_with("_right"):
			return "DPad Right"
	elif m.axis == JOY_AXIS_LEFT_Y and m.axis_value < 0.0:
		if action_name.ends_with("_up"):
			return "DPad Up"
	elif m.axis == JOY_AXIS_LEFT_Y and m.axis_value > 0.0:
		if action_name.ends_with("_down"):
			return "DPad Down"
	return ""


func _get_binding_text_from_event(event: InputEvent) -> String:
	if event == null:
		return "Unassigned"
	var joy_button_event := event as InputEventJoypadButton
	if joy_button_event != null:
		return _get_joy_button_label(joy_button_event.button_index)
	var joy_axis_event := event as InputEventJoypadMotion
	if joy_axis_event != null:
		var direction := "+" if joy_axis_event.axis_value >= 0.0 else "-"
		return "%s %s" % [_get_joy_axis_label(joy_axis_event.axis), direction]
	return "Unassigned"


func _get_action_label(action_name: String) -> String:
	for action_entry in CONTROL_ACTIONS:
		if str(action_entry["action"]) == action_name:
			return str(action_entry["label"])
	return action_name


func _replace_keyboard_binding(action_name: String, new_key_event: InputEventKey) -> void:
	var existing_events := InputMap.action_get_events(action_name)
	InputMap.action_erase_events(action_name)
	for existing_event in existing_events:
		if existing_event is InputEventKey:
			continue
		InputMap.action_add_event(action_name, existing_event)
	InputMap.action_add_event(action_name, new_key_event)


func _replace_controller_binding_for_all_devices(action_id: StringName, new_controller_event: InputEvent) -> void:
	for action_name in _resolve_controller_actions(action_id):
		_inputmap_set_single_gamepad_event_for_action(String(action_name), new_controller_event)


func _get_joy_button_label(button_index: int) -> String:
	match button_index:
		JOY_BUTTON_A:
			return "A"
		JOY_BUTTON_B:
			return "B"
		JOY_BUTTON_X:
			return "X"
		JOY_BUTTON_Y:
			return "Y"
		JOY_BUTTON_BACK:
			return "Back"
		JOY_BUTTON_GUIDE:
			return "Guide"
		JOY_BUTTON_START:
			return "Start"
		JOY_BUTTON_LEFT_STICK:
			return "L3"
		JOY_BUTTON_RIGHT_STICK:
			return "R3"
		JOY_BUTTON_LEFT_SHOULDER:
			return "L1"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "R1"
		JOY_BUTTON_DPAD_UP:
			return "DPad Up"
		JOY_BUTTON_DPAD_DOWN:
			return "DPad Down"
		JOY_BUTTON_DPAD_LEFT:
			return "DPad Left"
		JOY_BUTTON_DPAD_RIGHT:
			return "DPad Right"
		_:
			return "Button %d" % button_index


func _get_joy_axis_label(axis: int) -> String:
	match axis:
		JOY_AXIS_LEFT_X:
			return "Left Stick X"
		JOY_AXIS_LEFT_Y:
			return "Left Stick Y"
		JOY_AXIS_RIGHT_X:
			return "Right Stick X"
		JOY_AXIS_RIGHT_Y:
			return "Right Stick Y"
		JOY_AXIS_TRIGGER_LEFT:
			return "L2"
		JOY_AXIS_TRIGGER_RIGHT:
			return "R2"
		_:
			return "Axis %d" % axis


func _cycle_tab(direction: int) -> void:
	var current_index := TAB_ORDER.find(_selected_tab)
	if current_index < 0:
		current_index = 0
	var next_index := posmod(current_index + direction, TAB_ORDER.size())
	_select_tab(String(TAB_ORDER[next_index]))


func _focus_default_for_current_tab() -> void:
	if _controller_overlay_open:
		if controller_overlay_p1_up_button != null:
			controller_overlay_p1_up_button.call_deferred("grab_focus")
		return

	var target: Control = null
	if general_section.visible:
		target = fullscreen_checkbox
	elif controls_section.visible:
		if _first_controls_focus_button != null:
			target = _first_controls_focus_button
		else:
			target = reset_controls_button
	else:
		if _first_controller_focus_button != null:
			target = _first_controller_focus_button
		else:
			target = reset_controller_button

	if target != null:
		target.call_deferred("grab_focus")


func _on_gui_focus_changed(control: Control) -> void:
	if not _controller_overlay_open:
		return
	if control != null and controller_overlay.is_ancestor_of(control):
		return
	if controller_overlay_p1_up_button != null:
		controller_overlay_p1_up_button.call_deferred("grab_focus")


func _setup_controller_overlay_focus_neighbors() -> void:
	controller_overlay_p1_up_button.focus_neighbor_bottom = controller_overlay_p1_left_button.get_path()
	controller_overlay_p1_left_button.focus_neighbor_top = controller_overlay_p1_up_button.get_path()
	controller_overlay_p1_left_button.focus_neighbor_bottom = controller_overlay_p1_right_button.get_path()
	controller_overlay_p1_right_button.focus_neighbor_top = controller_overlay_p1_left_button.get_path()
	controller_overlay_p1_right_button.focus_neighbor_bottom = controller_overlay_p1_down_button.get_path()
	controller_overlay_p1_down_button.focus_neighbor_top = controller_overlay_p1_right_button.get_path()
	controller_overlay_p1_down_button.focus_neighbor_bottom = controller_overlay_p1_use_button.get_path()
	controller_overlay_p1_use_button.focus_neighbor_top = controller_overlay_p1_down_button.get_path()
	controller_overlay_p1_use_button.focus_neighbor_bottom = controller_overlay_pause_button.get_path()

	controller_overlay_p2_up_button.focus_neighbor_bottom = controller_overlay_p2_left_button.get_path()
	controller_overlay_p2_left_button.focus_neighbor_top = controller_overlay_p2_up_button.get_path()
	controller_overlay_p2_left_button.focus_neighbor_bottom = controller_overlay_p2_right_button.get_path()
	controller_overlay_p2_right_button.focus_neighbor_top = controller_overlay_p2_left_button.get_path()
	controller_overlay_p2_right_button.focus_neighbor_bottom = controller_overlay_p2_down_button.get_path()
	controller_overlay_p2_down_button.focus_neighbor_top = controller_overlay_p2_right_button.get_path()
	controller_overlay_p2_down_button.focus_neighbor_bottom = controller_overlay_p2_use_button.get_path()
	controller_overlay_p2_use_button.focus_neighbor_top = controller_overlay_p2_down_button.get_path()
	controller_overlay_p2_use_button.focus_neighbor_bottom = controller_overlay_pause_button.get_path()

	controller_overlay_p1_up_button.focus_neighbor_right = controller_overlay_p2_up_button.get_path()
	controller_overlay_p1_left_button.focus_neighbor_right = controller_overlay_p2_left_button.get_path()
	controller_overlay_p1_right_button.focus_neighbor_right = controller_overlay_p2_right_button.get_path()
	controller_overlay_p1_down_button.focus_neighbor_right = controller_overlay_p2_down_button.get_path()
	controller_overlay_p1_use_button.focus_neighbor_right = controller_overlay_p2_use_button.get_path()

	controller_overlay_p2_up_button.focus_neighbor_left = controller_overlay_p1_up_button.get_path()
	controller_overlay_p2_left_button.focus_neighbor_left = controller_overlay_p1_left_button.get_path()
	controller_overlay_p2_right_button.focus_neighbor_left = controller_overlay_p1_right_button.get_path()
	controller_overlay_p2_down_button.focus_neighbor_left = controller_overlay_p1_down_button.get_path()
	controller_overlay_p2_use_button.focus_neighbor_left = controller_overlay_p1_use_button.get_path()

	controller_overlay_pause_button.focus_neighbor_top = controller_overlay_p1_use_button.get_path()
	controller_overlay_pause_button.focus_neighbor_bottom = controller_overlay_confirm_button.get_path()

	controller_overlay_confirm_button.focus_neighbor_top = controller_overlay_pause_button.get_path()
	controller_overlay_confirm_button.focus_neighbor_right = controller_overlay_cancel_button.get_path()
	controller_overlay_cancel_button.focus_neighbor_top = controller_overlay_pause_button.get_path()
	controller_overlay_cancel_button.focus_neighbor_left = controller_overlay_confirm_button.get_path()
	controller_overlay_cancel_button.focus_neighbor_right = controller_overlay_reset_button.get_path()
	controller_overlay_reset_button.focus_neighbor_top = controller_overlay_pause_button.get_path()
	controller_overlay_reset_button.focus_neighbor_left = controller_overlay_cancel_button.get_path()


func _is_tab_next_event(event: InputEvent) -> bool:
	if _is_action_pressed_if_exists(event, "ui_page_down"):
		return true
	var joy_event := event as InputEventJoypadButton
	return joy_event != null and joy_event.pressed and joy_event.button_index == TAB_NEXT_BUTTON


func _is_tab_prev_event(event: InputEvent) -> bool:
	if _is_action_pressed_if_exists(event, "ui_page_up"):
		return true
	var joy_event := event as InputEventJoypadButton
	return joy_event != null and joy_event.pressed and joy_event.button_index == TAB_PREV_BUTTON


func _is_action_pressed_if_exists(event: InputEvent, action: StringName) -> bool:
	if not InputMap.has_action(action):
		return false
	return event.is_action_pressed(action)


func _on_focusable_control_focused(control: Control) -> void:
	if controls_section.visible and controls_scroll_container.is_ancestor_of(control):
		controls_scroll_container.ensure_control_visible(control)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_controller_connectors()


func _init_controller_connector_layer() -> void:
	if _controller_connectors != null:
		return
	_controller_connectors = ControllerConnectorLayer.new()
	_controller_connectors.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_controller_connectors.set_anchors_preset(Control.PRESET_FULL_RECT)
	controller_connector_layer.add_child(_controller_connectors)


func _register_connector(action_id: StringName, button: Control) -> void:
	if _controller_connectors == null:
		return
	var anchor_node := _get_anchor_node_for_action(action_id)
	var side := -1 if _is_controller_left_side(action_id) else 1
	_controller_connectors.set_connector(action_id, button, anchor_node, side)


func _register_static_connector(
	label_id: StringName,
	label_control: Control,
	anchor_name: String,
	side: int
) -> void:
	if _controller_connectors == null:
		return
	var anchor_node := _get_anchor_node_by_button_name(anchor_name)
	_controller_connectors.set_connector(label_id, label_control, anchor_node, side)


func _update_controller_connectors() -> void:
	if _controller_connectors == null:
		return
	_controller_connectors.visible = visible and _selected_tab == &"controller" and controller_section.visible
	_controller_connectors.queue_redraw()


func _get_anchor_node_for_action(action_id: StringName) -> Control:
	## Po zmene mapovania musí korešpondovať so skutočným tlačidlom/osou; pre predvolený
	## ľavý analóg (štyri smery) ponecháme čiaru na D-pade (readability).
	if action_id == &"up" or action_id == &"down" or action_id == &"left" or action_id == &"right":
		return _get_movement_action_anchor_node(action_id)
	if action_id == &"ui_cancel":
		var ac := _get_first_joypad_anchor_for_map_action("ui_cancel")
		if ac != null:
			return ac
		return _get_default_anchor_node(&"ui_cancel")
	if action_id == &"use":
		var u := "p1_use" if _controller_preview_slot == 1 else "p2_use"
		var ad := _get_first_joypad_anchor_for_map_action(u)
		if ad != null:
			return ad
		return _get_default_anchor_node(&"use")
	return null


func _get_first_joypad_anchor_for_map_action(map_action: String) -> Control:
	if not InputMap.has_action(map_action):
		return null
	for ev in InputMap.action_get_events(map_action):
		if not (ev is InputEventJoypadButton or ev is InputEventJoypadMotion):
			continue
		var a := _get_anchor_node_for_event(ev)
		if a != null:
			return a
	return null


func _is_left_stick_axis_event(m: InputEventJoypadMotion) -> bool:
	return m.axis == JOY_AXIS_LEFT_X or m.axis == JOY_AXIS_LEFT_Y


func _get_movement_action_anchor_node(action_id: StringName) -> Control:
	var map_action := "p1_%s" % String(action_id) if _controller_preview_slot == 1 else "p2_%s" % String(action_id)
	if not InputMap.has_action(map_action):
		return _get_default_anchor_node(action_id)
	for ev in InputMap.action_get_events(map_action):
		if not (ev is InputEventJoypadButton or ev is InputEventJoypadMotion):
			continue
		if ev is InputEventJoypadMotion and _is_left_stick_axis_event(ev as InputEventJoypadMotion):
			return _get_default_anchor_node(action_id)
		var a := _get_anchor_node_for_event(ev)
		if a != null:
			return a
	return _get_default_anchor_node(action_id)


func _get_anchor_node_for_event(event: InputEvent) -> Control:
	var joy_button_event := event as InputEventJoypadButton
	if joy_button_event != null:
		return _get_anchor_node_by_button_name(_anchor_name_for_button(joy_button_event.button_index))
	var joy_axis_event := event as InputEventJoypadMotion
	if joy_axis_event != null:
		return _get_anchor_node_by_button_name(_anchor_name_for_axis(joy_axis_event.axis))
	return null


func _anchor_name_for_button(button_index: int) -> String:
	match button_index:
		JOY_BUTTON_A: return "ACross"
		JOY_BUTTON_B: return "BCircle"
		JOY_BUTTON_X: return "XSquare"
		JOY_BUTTON_Y: return "YTriangle"
		JOY_BUTTON_BACK: return "Select"
		JOY_BUTTON_START: return "Start"
		JOY_BUTTON_LEFT_STICK: return "LStick"
		JOY_BUTTON_RIGHT_STICK: return "RStick"
		JOY_BUTTON_LEFT_SHOULDER: return "L1Control"
		JOY_BUTTON_RIGHT_SHOULDER: return "R1Control"
		JOY_BUTTON_DPAD_UP: return "DPadUp"
		JOY_BUTTON_DPAD_DOWN: return "DPadDown"
		JOY_BUTTON_DPAD_LEFT: return "DPadLeft"
		JOY_BUTTON_DPAD_RIGHT: return "DPadRight"
	return ""


func _anchor_name_for_axis(axis: int) -> String:
	match axis:
		JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y: return "LStick"
		JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y: return "RStick"
		JOY_AXIS_TRIGGER_LEFT: return "L2Control"
		JOY_AXIS_TRIGGER_RIGHT: return "R2Control"
	return ""


func _get_anchor_node_by_button_name(anchor_name: String) -> Control:
	if anchor_name.is_empty() or controller_connector_layer == null:
		return null
	return controller_connector_layer.get_node_or_null(anchor_name) as Control


func _get_default_anchor_node(action_id: StringName) -> Control:
	match action_id:
		&"up":
			return _get_anchor_node_by_button_name("DPadUp")
		&"down":
			return _get_anchor_node_by_button_name("DPadDown")
		&"left":
			return _get_anchor_node_by_button_name("DPadLeft")
		&"right":
			return _get_anchor_node_by_button_name("DPadRight")
		&"use":
			return _get_anchor_node_by_button_name("YTriangle")
		&"ui_cancel":
			return _get_anchor_node_by_button_name("BCircle")
	return null


func _resolve_controller_actions(action_id: StringName) -> Array[String]:
	match action_id:
		&"left":
			return ["p1_left", "p2_left"]
		&"right":
			return ["p1_right", "p2_right"]
		&"up":
			return ["p1_up", "p2_up"]
		&"down":
			return ["p1_down", "p2_down"]
		&"use":
			return ["p1_use", "p2_use"]
		&"ui_cancel":
			return ["ui_cancel"]
		_:
			return []


func _action_to_controller_action_id(action_name: String) -> StringName:
	match action_name:
		"p1_left", "p2_left":
			return &"left"
		"p1_right", "p2_right":
			return &"right"
		"p1_up", "p2_up":
			return &"up"
		"p1_down", "p2_down":
			return &"down"
		"p1_use", "p2_use":
			return &"use"
		"ui_cancel":
			return &"ui_cancel"
		_:
			return &"ui_cancel"


func _get_controller_action_label(action_id: StringName) -> String:
	for bind_entry in CONTROLLER_BIND_ACTIONS:
		if bind_entry["id"] == action_id:
			return str(bind_entry["label"])
	return String(action_id)


func _is_controller_left_side(action_id: StringName) -> bool:
	for bind_entry in CONTROLLER_BIND_ACTIONS:
		if bind_entry["id"] == action_id:
			return int(bind_entry["side"]) < 0
	return false


class ControllerConnectorLayer extends Control:
	var _connectors: Dictionary = {}

	func set_connector(
		action_name: StringName,
		button: Control,
		anchor_node: Control,
		side: int
	) -> void:
		_connectors[action_name] = {
			"button": button,
			"anchor_node": anchor_node,
			"side": side
		}
		queue_redraw()

	func _draw() -> void:
		var line_color := Color(0.55, 0.55, 0.55, 0.9)
		var corridor_base := 22.0
		var lane_spacing := 8.0
		var line_width := 0.7
		var inv_transform := get_global_transform_with_canvas().affine_inverse()
		var left_segments: Array = []
		var right_segments: Array = []
		for entry in _connectors.values():
			var button: Control = entry["button"]
			var anchor_node: Control = entry["anchor_node"]
			var side: int = entry["side"]
			if button == null or anchor_node == null:
				continue
			if not is_instance_valid(button) or not is_instance_valid(anchor_node):
				continue
			if not button.is_visible_in_tree() or not anchor_node.is_visible_in_tree():
				continue

			var button_rect := button.get_global_rect()
			var button_y := button_rect.end.y
			var button_edge_x: float = button_rect.position.x if side < 0 else button_rect.end.x

			var segment := {
				"from": inv_transform * Vector2(button_edge_x, button_y),
				"to": inv_transform * anchor_node.get_global_rect().get_center()
			}
			if side < 0:
				left_segments.append(segment)
			else:
				right_segments.append(segment)

		left_segments.sort_custom(_sort_segments_by_target_y)
		right_segments.sort_custom(_sort_segments_by_target_y)
		_draw_segments(left_segments, -1, line_color, line_width, corridor_base, lane_spacing)
		_draw_segments(right_segments, 1, line_color, line_width, corridor_base, lane_spacing)


	func _draw_segments(
		segments: Array,
		side: int,
		line_color: Color,
		line_width: float,
		corridor_base: float,
		lane_spacing: float
	) -> void:
		for idx in range(segments.size()):
			var segment: Dictionary = segments[idx]
			var from_local: Vector2 = segment["from"]
			var to_local: Vector2 = segment["to"]
			var lane_offset := corridor_base + lane_spacing * float(idx)
			var elbow_x := to_local.x - lane_offset if side < 0 else to_local.x + lane_offset
			var elbow_a := Vector2(elbow_x, from_local.y)
			# Keep the final approach on target Y to avoid crossing.
			var elbow_b := Vector2(elbow_x, to_local.y)
			draw_line(from_local, elbow_a, line_color, line_width, true)
			draw_line(elbow_a, elbow_b, line_color, line_width, true)
			draw_line(elbow_b, to_local, line_color, line_width, true)


	func _sort_segments_by_target_y(a: Dictionary, b: Dictionary) -> bool:
		var ay := (a["to"] as Vector2).y
		var by := (b["to"] as Vector2).y
		if is_equal_approx(ay, by):
			return (a["from"] as Vector2).y < (b["from"] as Vector2).y
		return ay < by
