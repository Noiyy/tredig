extends CanvasLayer

func _focus_resume_button() -> void:
	$CenterContainer/PauseOptions/ContinueButton.call_deferred("grab_focus")

func _ready() -> void:
	visible = false
	get_tree().paused = false
	
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


func _on_menu_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_quit_button_pressed() -> void:
	get_tree().quit()
