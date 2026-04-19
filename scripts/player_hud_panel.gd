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

@onready var black_vignette: Control = $BlackVignette
@onready var black_vignette_rect: ColorRect = $BlackVignette/ColorRect
@onready var black_vignette_material = black_vignette_rect.material as ShaderMaterial

var vignette_tween: Tween
var durability_vignette_tween: Tween
var hp_pulse_tween: Tween

var _dur_bar_bg_template: StyleBoxFlat
var _dur_bar_base_pos: Vector2
var _dur_empty_active: bool = false
var _dur_shake_tween: Tween
var _dur_shake_running: bool = false

const DUR_EMPTY_BG := Color("#660000E1")
const DUR_SHAKE_AMP_PX := 3.5
const DUR_SHAKE_HALF_SEC := 0.055

var _exp_shine_host: Control
var _exp_shine_rect: ColorRect
var _exp_level_up_seq_id: int = 0
var _exp_shine_tween: Tween
var _exp_level_up_ui_busy: bool = false
var _pending_after_shine: bool = false
var _pending_exp_max: int = 0
var _pending_exp_val: int = 0

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
	clear_durability_vignette_immediate()


func _ready() -> void:
	# Dva HUD panely (ľavý/pravý) zdieľajú inak rovnaký ShaderMaterial z vnorených scén — duplikácia oddelí intenzitu vignety.
	if vignette_rect.material:
		vignette_rect.material = vignette_rect.material.duplicate()
		vignette_material = vignette_rect.material as ShaderMaterial
	if black_vignette_rect.material:
		black_vignette_rect.material = black_vignette_rect.material.duplicate()
		black_vignette_material = black_vignette_rect.material as ShaderMaterial
	_apply_flip()
	_cache_durability_bar_style()
	_dur_bar_base_pos = dur_bar.position
	call_deferred("_setup_exp_level_up_shine")


func _cache_durability_bar_style() -> void:
	var sb: StyleBox = dur_bar.get_theme_stylebox("background", "ProgressBar")
	if sb is StyleBoxFlat:
		_dur_bar_bg_template = sb.duplicate() as StyleBoxFlat


func set_durability_bar(current: int, max_value: int) -> void:
	dur_bar.max_value = max_value
	dur_bar.value = current
	var empty := current <= 0
	if empty == _dur_empty_active:
		return
	_dur_empty_active = empty
	if empty:
		_apply_durability_empty_visual()
		_start_durability_shake_sequence()
		show_durability_empty_vignette()
	else:
		_restore_durability_visual()
		_stop_durability_shake()
		hide_durability_empty_vignette()


## Pri prázdnej lopate — spustí shake (úder do bloku pri 0 durability), ak už nebeží.
func pulse_durability_empty_shake() -> void:
	if not _dur_empty_active:
		return
	_start_durability_shake_sequence()


func _apply_durability_empty_visual() -> void:
	if _dur_bar_bg_template:
		var s := _dur_bar_bg_template.duplicate() as StyleBoxFlat
		s.bg_color = DUR_EMPTY_BG
		dur_bar.add_theme_stylebox_override("background", s)


func _restore_durability_visual() -> void:
	if _dur_bar_bg_template:
		dur_bar.add_theme_stylebox_override("background", _dur_bar_bg_template.duplicate() as StyleBoxFlat)


func _start_durability_shake_sequence() -> void:
	if _dur_shake_running:
		return
	_dur_shake_running = true
	if _dur_shake_tween and _dur_shake_tween.is_valid():
		_dur_shake_tween.kill()
	dur_bar.position = _dur_bar_base_pos
	var a := DUR_SHAKE_AMP_PX
	var t := DUR_SHAKE_HALF_SEC
	_dur_shake_tween = create_tween()
	_dur_shake_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 3× doprava → doľava, potom návrat na základnú pozíciu
	for _i in 3:
		_dur_shake_tween.tween_property(dur_bar, "position", _dur_bar_base_pos + Vector2(a, 0), t)
		_dur_shake_tween.tween_property(dur_bar, "position", _dur_bar_base_pos + Vector2(-a, 0), t)
	_dur_shake_tween.tween_property(dur_bar, "position", _dur_bar_base_pos, t)
	_dur_shake_tween.finished.connect(_on_durability_shake_finished, CONNECT_ONE_SHOT)


func _on_durability_shake_finished() -> void:
	_dur_shake_tween = null
	_dur_shake_running = false
	dur_bar.position = _dur_bar_base_pos


func _stop_durability_shake() -> void:
	if _dur_shake_tween and _dur_shake_tween.is_valid():
		_dur_shake_tween.kill()
	_dur_shake_tween = null
	_dur_shake_running = false
	dur_bar.position = _dur_bar_base_pos


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
	_pending_after_shine = false
	_exp_level_up_ui_busy = false
	if _exp_shine_tween and _exp_shine_tween.is_valid():
		_exp_shine_tween.kill()
	_exp_shine_tween = null
	if _exp_shine_host:
		_exp_shine_host.visible = false
	exp_bar.cancel_value_tween()


func is_exp_level_up_sequence_active() -> bool:
	return _exp_level_up_ui_busy


## Odlož bežnú zmenu XP baru, kým dobehne shine (inak by invalidate prerušil animáciu).
func queue_deferred_exp_update(exp_needed: int, experience: int) -> void:
	_pending_after_shine = true
	_pending_exp_max = exp_needed
	_pending_exp_val = experience


## Pri level up nechaj starý max na bare, kým neprebehne sekvencia (volá hud pred zmenou max).
func play_exp_level_up_sequence(new_max: int, new_exp: int) -> void:
	# Nový level-up = nový zdroj pravdy; starý pending XP by bol z predošlého levelu.
	_pending_after_shine = false
	if _exp_shine_tween and _exp_shine_tween.is_valid():
		_exp_shine_tween.kill()
	_exp_shine_tween = null
	_exp_level_up_seq_id += 1
	var seq_id := _exp_level_up_seq_id
	_exp_level_up_ui_busy = true

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
	if _pending_after_shine:
		new_max = _pending_exp_max
		new_exp = _pending_exp_val
		_pending_after_shine = false
	exp_bar.max_value = float(new_max)
	exp_bar.value = 0.0
	exp_bar.set_value_animated(float(new_exp))
	_exp_level_up_ui_busy = false


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


func show_durability_empty_vignette() -> void:
	if durability_vignette_tween and durability_vignette_tween.is_valid():
		durability_vignette_tween.kill()
	black_vignette.visible = true
	black_vignette_rect.visible = true
	black_vignette_material.set_shader_parameter("intensity", 0.0)
	durability_vignette_tween = create_tween()
	durability_vignette_tween.tween_property(black_vignette_material, "shader_parameter/intensity", 0.9, 0.3)


func hide_durability_empty_vignette() -> void:
	if durability_vignette_tween and durability_vignette_tween.is_valid():
		durability_vignette_tween.kill()
	black_vignette.visible = true
	black_vignette_rect.visible = true
	durability_vignette_tween = create_tween()
	durability_vignette_tween.tween_method(
		func(i): black_vignette_material.set_shader_parameter("intensity", i),
		black_vignette_material.get_shader_parameter("intensity"), 0.0, 0.3
	)
	durability_vignette_tween.tween_callback(func():
		black_vignette.visible = false
		black_vignette_rect.visible = false
	)


func clear_durability_vignette_immediate() -> void:
	if durability_vignette_tween and durability_vignette_tween.is_valid():
		durability_vignette_tween.kill()
	durability_vignette_tween = null
	black_vignette.visible = false
	black_vignette_rect.visible = false
	black_vignette_material.set_shader_parameter("intensity", 0.0)
