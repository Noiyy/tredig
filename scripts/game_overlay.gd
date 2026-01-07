extends Control

@export var overlay_type: String = "gameover"
@onready var time_label: Label  = $VBoxContainer/TimeLabel
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var sub_title_label: Label = $VBoxContainer/SubTitleLabel
@onready var btn: Button = $VBoxContainer/Button

func update_type(type: String) -> void:
	if overlay_type == type: return
	overlay_type = type
	
	if overlay_type == "gameover": 
		title_label.text = "You lose!"
		title_label.modulate = Color("#ff0000")
		sub_title_label.text = "you survived:"
		btn.text = "RESTART"
		
	if overlay_type == "win":
		title_label.text = "You won!"
		title_label.modulate = Color("#00ff00")
		sub_title_label.text = "& reached treasure in:"
		btn.text = "PLAY AGAIN"

func show_game_over(time_sec: float, type: String) -> void:
	update_type(type)
	visible = true
	time_label.text = _format_time_mm_ss(time_sec)

func _format_time_mm_ss(time_sec: float) -> String:
	var m: int = int(time_sec) / 60
	var s: int = int(time_sec) % 60
	return "%02d:%02d" % [m, s]


func _on_restart_button_pressed() -> void:
	get_tree().reload_current_scene()
