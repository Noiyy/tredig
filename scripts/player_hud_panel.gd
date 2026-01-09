extends Control

@export var flipped: bool = false

@onready var exp_bar: ProgressBar  = $ExpProgressBar
@onready var level_label: Label    = $LevelLabel
@onready var modifier_label: Label = $ModifierLabel
@onready var dur_bar: ProgressBar  = $DurabilityBar
@onready var hp_label: Label       = $HPLabel
@onready var bonus1: Control       = $Bonus1
@onready var bonus2: Control       = $Bonus2

@onready var red_vignette: Control = $RedVignette
@onready var vignette_rect: ColorRect = $RedVignette/ColorRect
@onready var vignette_material = vignette_rect.material as ShaderMaterial

func _ready() -> void:
	_apply_flip()


func _apply_flip() -> void:
	if flipped:
		level_label.scale.x = -1
		hp_label.scale.x = -1
		level_label.position.x += level_label.size.x
		hp_label.position.x += hp_label.size.x
		modifier_label.scale.x = -1
		modifier_label.position.x += modifier_label.size.x
		
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		hp_label.horizontal_alignment    = HORIZONTAL_ALIGNMENT_RIGHT
		modifier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		bonus1.scale.x = -1
		bonus1.position.x += bonus1.size.x
		bonus2.scale.x = -1
		bonus2.position.x += bonus2.size.x
		
		vignette_rect.scale.x = -1
		vignette_rect.position.x += vignette_rect.size.x
		
func show_damage_vignette():
	red_vignette.visible = true
	vignette_material.set_shader_parameter("intensity", 0.8)
	#vignette_material.set_shader_parameter("vignette_color", Color(0.8, 0.1, 0.1, 0.3))

func hide_damage_vignette():
	red_vignette.visible = false
	
	var tween = create_tween()
	tween.tween_method(
		func(i): vignette_material.set_shader_parameter("intensity", i),
		vignette_material.get_shader_parameter("intensity"), 0.0, 0.3
	)
	tween.tween_callback(func(): vignette_rect.visible = false)
