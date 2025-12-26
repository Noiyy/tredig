extends Control

@export var flipped: bool = false

@onready var exp_bar: ProgressBar = $ExpProgressBar
@onready var level_label: Label   = $LevelLabel
@onready var dur_bar: ProgressBar = $DurabilityBar
@onready var hp_label: Label      = $HPLabel
@onready var bonus: Control       = $Bonus

func _ready() -> void:
	_apply_flip()


func _apply_flip() -> void:
	if flipped:
		level_label.scale.x = -1
		hp_label.scale.x = -1
		level_label.position.x += level_label.size.x
		hp_label.position.x += hp_label.size.x
		
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		hp_label.horizontal_alignment    = HORIZONTAL_ALIGNMENT_RIGHT
		
		bonus.scale.x = -1
		bonus.position.x += bonus.size.x
