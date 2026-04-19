class_name PlayerHUDPanel
extends Control

@export var flipped: bool = false

@onready var exp_bar: ProgressBar  = $ExpProgressBar
@onready var level_label: Label    = $LevelLabel
@onready var modifier_label: Label = $ModifierLabel
@onready var dur_bar: ProgressBar  = $DurabilityBar
@onready var hp_pulse_host: Control  = $HPLabelPulse
@onready var hp_label: Label       = $HPLabelPulse/HPLabel
@onready var bonus1: Control       = $Bonus1
@onready var bonus2: Control       = $Bonus2

@onready var red_vignette: Control = $RedVignette
@onready var vignette_rect: ColorRect = $RedVignette/ColorRect
@onready var vignette_material = vignette_rect.material as ShaderMaterial

var vignette_tween: Tween
var hp_pulse_tween: Tween

var _exp_shine_host: Control
var _exp_shine_rect: ColorRect
var _exp_level_up_seq_id: int = 0
var _exp_shine_tween: Tween

const EXP_LEVEL_UP_HOLD_SEC := 0.22
const EXP_LEVEL_UP_SHINE_SEC := 0.4
const EXP_SHINE_ROT_DEG := -38.0


func pulse_hp_from_lava() -> void:
	if hp_pulse_tween and hp_pulse_tween.is_valid():
		hp_pulse_tween.kill()
	var current_scale := hp_pulse_host.scale
	var big_scale := current_scale * 1.35
	hp_pulse_host.pivot_offset = hp_pulse_host.size / 2.0
	hp_pulse_tween = create_tween()
	hp_pulse_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hp_pulse_tween.tween_property(hp_pulse_host, "scale", big_scale, 0.18)
	hp_pulse_tween.tween_property(hp_pulse_host, "scale", current_scale, 0.35)


func stop_hp_pulse_immediate() -> void:
	if hp_pulse_tween and hp_pulse_tween.is_valid():
		hp_pulse_tween.kill()
	hp_pulse_tween = null
	hp_pulse_host.scale = Vector2.ONE


func clear_damage_fx_immediate() -> void:
	stop_hp_pulse_immediate()
	clear_damage_vignette_immediate()


func _ready() -> void:
	_apply_flip()
	call_deferred("_setup_exp_level_up_shine")


func _setup_exp_level_up_shine() -> void:
	if _exp_shine_host:
		return
	_exp_shine_host = Control.new()
	_exp_shine_host.name = "ExpLevelUpShineHost"
	_exp_shine_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_exp_shine_host.clip_contents = true
	_exp_shine_host.visible = false
	exp_bar.add_child(_exp_shine_host)
	_exp_shine_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_exp_shine_host.offset_left = 0.0
	_exp_shine_host.offset_top = 0.0
	_exp_shine_host.offset_right = 0.0
	_exp_shine_host.offset_bottom = 0.0

	_exp_shine_rect = ColorRect.new()
	_exp_shine_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_exp_shine_rect.color = Color(1.0, 1.0, 1.0, 0.4)
	_exp_shine_host.add_child(_exp_shine_rect)


func invalidate_exp_level_up_sequence() -> void:
	_exp_level_up_seq_id += 1
	if _exp_shine_tween and _exp_shine_tween.is_valid():
		_exp_shine_tween.kill()
	_exp_shine_tween = null
	if _exp_shine_host:
		_exp_shine_host.visible = false
	exp_bar.cancel_value_tween()


## Pri level up nechaj starý max na bare, kým neprebehne sekvencia (volá hud pred zmenou max).
func play_exp_level_up_sequence(new_max: int, new_exp: int) -> void:
	if _exp_shine_tween and _exp_shine_tween.is_valid():
		_exp_shine_tween.kill()
	_exp_shine_tween = null
	_exp_level_up_seq_id += 1
	var seq_id := _exp_level_up_seq_id

	exp_bar.cancel_value_tween()
	exp_bar.value = exp_bar.max_value

	await get_tree().create_timer(EXP_LEVEL_UP_HOLD_SEC).timeout
	if seq_id != _exp_level_up_seq_id:
		return

	if not _exp_shine_host or not _exp_shine_rect:
		_apply_exp_bar_after_level_up(new_max, new_exp)
		return

	await get_tree().process_frame
	if seq_id != _exp_level_up_seq_id:
		return

	var sz: Vector2 = _exp_shine_host.size
	if sz.x < 1.0 or sz.y < 1.0:
		_apply_exp_bar_after_level_up(new_max, new_exp)
		return

	var strip_w: float = maxf(40.0, sz.x * 0.19)
	var strip_h: float = sz.y * 3.0
	_exp_shine_rect.size = Vector2(strip_w, strip_h)
	_exp_shine_rect.pivot_offset = _exp_shine_rect.size / 2.0
	_exp_shine_rect.rotation = deg_to_rad(EXP_SHINE_ROT_DEG)

	var mid_y: float = sz.y * 0.5
	var start_center := Vector2(-strip_w * 0.55, mid_y)
	var end_center := Vector2(sz.x + strip_w * 0.55, mid_y)
	_exp_shine_rect.position = start_center - _exp_shine_rect.pivot_offset

	_exp_shine_host.visible = true

	_exp_shine_tween = create_tween()
	_exp_shine_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_exp_shine_tween.tween_property(
		_exp_shine_rect, "position",
		end_center - _exp_shine_rect.pivot_offset,
		EXP_LEVEL_UP_SHINE_SEC
	)
	# Nepoužívaj await tween.finished — pri kill() sa nemusí emitovať a await by visel.
	await get_tree().create_timer(EXP_LEVEL_UP_SHINE_SEC).timeout
	if seq_id != _exp_level_up_seq_id:
		return

	_exp_shine_tween = null
	_exp_shine_host.visible = false
	_apply_exp_bar_after_level_up(new_max, new_exp)


func _apply_exp_bar_after_level_up(new_max: int, new_exp: int) -> void:
	exp_bar.max_value = float(new_max)
	exp_bar.value = 0.0
	exp_bar.set_value_animated(float(new_exp))


func _apply_flip() -> void:
	if flipped:
		level_label.scale.x = -1
		hp_label.scale.x = -1
		#level_label.position.x += level_label.size.x
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
		
func show_damage_vignette():
	if vignette_tween and vignette_tween.is_valid():
		vignette_tween.kill()
	red_vignette.visible = true
	vignette_material.set_shader_parameter("intensity", 0.0)  # Start na 0

	vignette_tween = create_tween()
	vignette_tween.tween_property(vignette_material, "shader_parameter/intensity", 0.8, 0.3)


func hide_damage_vignette():
	if vignette_tween and vignette_tween.is_valid():
		vignette_tween.kill()
	red_vignette.visible = false

	vignette_tween = create_tween()
	vignette_tween.tween_method(
		func(i): vignette_material.set_shader_parameter("intensity", i),
		vignette_material.get_shader_parameter("intensity"), 0.0, 0.3
	)
	vignette_tween.tween_callback(func(): vignette_rect.visible = false)


func clear_damage_vignette_immediate() -> void:
	if vignette_tween and vignette_tween.is_valid():
		vignette_tween.kill()
	vignette_tween = null
	red_vignette.visible = false
	vignette_rect.visible = false
	vignette_material.set_shader_parameter("intensity", 0.0)
