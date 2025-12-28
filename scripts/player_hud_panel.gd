extends Control

@export var flipped: bool = false

@onready var exp_bar: ProgressBar  = $ExpProgressBar
@onready var level_label: Label    = $LevelLabel
@onready var dur_bar: ProgressBar  = $DurabilityBar
@onready var hp_label: Label       = $HPLabel
@onready var bonus1: Control       = $Bonus1
@onready var bonus2: Control       = $Bonus2

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
		
		bonus1.scale.x = -1
		bonus1.position.x += bonus1.size.x
		bonus2.scale.x = -1
		bonus2.position.x += bonus2.size.x
