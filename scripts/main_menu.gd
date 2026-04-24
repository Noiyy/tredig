extends Node2D

var _last_main_buttons_focus: Control

func _ready() -> void:
	Music.set_gameplay_music(false)
	$MainButtons/PlayButton.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if not $SettingsMenu.visible and not $CreditsMenu.visible:
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
	pass # Replace with function body.


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_back_button_pressed() -> void:
	var was_settings_open: bool = $SettingsMenu.visible
	var was_credits_open: bool = $CreditsMenu.visible
	$MainButtons.visible = true
	$BlackOverlay.visible = false

	if was_settings_open:
		$SettingsMenu.visible = false
		
	if was_credits_open:
		$CreditsMenu.visible = false
	_restore_main_buttons_focus(
		$MainButtons/SettingsButton if was_settings_open else $MainButtons/CreditsButton
	)


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
