extends VBoxContainer

func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)

	$BackButton.pressed.connect(_on_back_button_pressed)
	$FullscreenCheckBox.toggled.connect(_on_fullscreen_check_box_toggled)
	$MainVolHSlider.value_changed.connect(_on_main_vol_h_slider_value_changed)
	$MusicVolHSlider.value_changed.connect(_on_music_vol_h_slider_value_changed)
	$SFXVolHSlider.value_changed.connect(_on_sfx_vol_h_slider_value_changed)

	_sync_from_system()


func _on_visibility_changed() -> void:
	if visible:
		_sync_from_system()


func _sync_from_system() -> void:
	$FullscreenCheckBox.button_pressed = (
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)
	$MainVolHSlider.value = db_to_linear(
		AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))
	)
	$MusicVolHSlider.value = db_to_linear(
		AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	)
	$SFXVolHSlider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")))


func _on_back_button_pressed() -> void:
	close_settings()


## Called from pause menu when closing settings with Escape.
func close_settings() -> void:
	var parent = get_parent()
	visible = false

	if parent.name == "MainMenu":
		parent.get_node("MainButtons").visible = true
		parent.get_node("MainButtons/SettingsButton").grab_focus()
	elif parent.has_node("PauseOptions"):
		parent.get_node("PauseOptions").visible = true
		parent.get_node("PauseOptions/SettingsButton").grab_focus()


func _on_fullscreen_check_box_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)


func _on_main_vol_h_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Master"), value)


func _on_music_vol_h_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Music"), value)


func _on_sfx_vol_h_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("SFX"), value)
