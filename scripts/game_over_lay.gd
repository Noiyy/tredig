extends Control

@onready var time_label: Label  = $VBoxContainer/TimeLabel

func show_game_over(time_sec: float) -> void:
	visible = true
	time_label.text = _format_time_mm_ss(time_sec)

func _format_time_mm_ss(time_sec: float) -> String:
	var m: int = int(time_sec) / 60
	var s: int = int(time_sec) % 60
	return "%02d:%02d" % [m, s]


func _on_restart_button_pressed() -> void:
	get_tree().reload_current_scene()
