extends Node2D

func _ready() -> void:
	Music.set_gameplay_music(false)
	$MainButtons/PlayButton.grab_focus()
	$SettingsMenu/FullscreenCheckBox.button_pressed = true if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN else false
	$SettingsMenu/MainVolHSlider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")))
	$SettingsMenu/MusicVolHSlider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")))
	$SettingsMenu/SFXVolHSlider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")))
	

func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file(str("res://scenes/main.tscn"))


func _on_settings_button_pressed() -> void:
	$MainButtons.visible = false
	$SettingsMenu.visible = true


func _on_credits_button_pressed() -> void:
	$MainButtons.visible = false
	$CreditsMenu.visible = true


func _on_how_to_button_pressed() -> void:
	pass # Replace with function body.


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_back_button_pressed() -> void:
	$MainButtons.visible = true
	if $SettingsMenu.visible:
		$SettingsMenu.visible = false
		$MainButtons/SettingsButton.grab_focus()
		
	if $CreditsMenu.visible:
		$CreditsMenu.visible = false
		$MainButtons/CreditsButton.grab_focus()


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
