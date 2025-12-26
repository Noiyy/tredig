extends CanvasLayer

var game_manager
var SHOVEL_LEVEL_EXPS
var elapsed_time: float = 0.0

@onready var left_bar: ProgressBar         = $LeftPlayerHUD/ExpProgressBar
@onready var left_label: Label             = $LeftPlayerHUD/LevelLabel
@onready var right_bar: ProgressBar        = $RightPlayerHUD/ExpProgressBar
@onready var right_label: Label            = $RightPlayerHUD/LevelLabel
@onready var timer_label: Label            = $TimerLabel
@onready var left_dur_bar: ProgressBar     = $LeftPlayerHUD/DurabilityBar
@onready var right_dur_bar: ProgressBar    = $RightPlayerHUD/DurabilityBar
@onready var left_hp_label: Label          = $LeftPlayerHUD/HPLabel
@onready var right_hp_label: Label         = $RightPlayerHUD/HPLabel
@onready var left_go                       = $LeftGameOverOverlay
@onready var right_go                      = $RightGameOverOverlay

@onready var left_bonus_icon: TextureRect  = $LeftPlayerHUD/Bonus/BonusIcon
@onready var right_bonus_icon: TextureRect = $RightPlayerHUD/Bonus/BonusIcon
@onready var left_bonus_timer: TextureProgressBar  = $LeftPlayerHUD/Bonus/BonusTimerBar
@onready var right_bonus_timer: TextureProgressBar = $RightPlayerHUD/Bonus/BonusTimerBar

var left_bonus_duration: float = 0.0
var left_bonus_time_left: float = 0.0
var left_bonus_active: bool = false

var right_bonus_duration: float = 0.0
var right_bonus_time_left: float = 0.0
var right_bonus_active: bool = false

var left_level_tween: Tween
var right_level_tween: Tween

var bonus_icons = {}

func _ready():	
	game_manager = get_tree().root.get_node("Main/GameManager")
	SHOVEL_LEVEL_EXPS = game_manager.get_shovel_level_exps()
	
	var max_dur = game_manager.get_max_durability()
	left_dur_bar.max_value = max_dur
	left_dur_bar.value = max_dur
	right_dur_bar.max_value = max_dur
	right_dur_bar.value = max_dur
	
	bonus_icons = {
		game_manager.BonusType.SHARPNESS: preload("res://assets/images/sharpness.png"),
		game_manager.BonusType.SSHOVEL: preload("res://assets/images/sshovel.png"),
		game_manager.BonusType.SABOTAGE: preload("res://assets/images/sabotage.png"),
		game_manager.BonusType.DULLNESS: preload("res://assets/images/dullness.png"),
		game_manager.BonusType.OVERLOAD: preload("res://assets/images/overload.png"),
	}
	
	left_bonus_timer.step = 0.01
	right_bonus_timer.step = 0.01
	
func _process(delta: float) -> void:
	elapsed_time += delta
	timer_label.text = _format_time_mm_ss(elapsed_time)
	
	_update_bonus_timer(delta)

func stop_timer() -> void:
	set_process(false)

func _format_time_mm_ss(time_sec: float) -> String:
	var minutes: int = int(time_sec) / 60
	var seconds: int = int(time_sec) % 60
	return "%02d:%02d" % [minutes, seconds]

func _get_exp_needed_for_level(shovel_level: int) -> int:
	var index: int = clamp(shovel_level - 1, 0, SHOVEL_LEVEL_EXPS.size() - 1)
	return SHOVEL_LEVEL_EXPS[index]

func _bounce_label(label: Label) -> void:
	var current_scale := label.scale
	var big_scale := current_scale * 1.4

	if label == left_label and left_level_tween and left_level_tween.is_valid():
		left_level_tween.kill()
	if label == right_label and right_level_tween and right_level_tween.is_valid():
		right_level_tween.kill()

	var tween := get_tree().create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", big_scale, 0.22)
	tween.tween_property(label, "scale", current_scale, 0.48)

	if label == left_label:
		left_level_tween = tween
	else:
		right_level_tween = tween

func update_player_hud(player_id: int, shovel_level: int, experience: int,
	leveled_up: bool) -> void:
	var exp_needed := _get_exp_needed_for_level(shovel_level)

	if player_id == 1:
		left_bar.max_value = exp_needed
		left_bar.set_value_animated(experience)
		left_label.text = "%d" % shovel_level
		if leveled_up:
			_bounce_label(left_label)
	elif player_id == 2:
		right_bar.max_value = exp_needed
		right_bar.set_value_animated(experience)
		right_label.text = "%d" % shovel_level
		if leveled_up:
			_bounce_label(right_label)

func update_player_durability(player: CharacterBody2D, current: int, max_value: int) -> void:
	var bar := left_dur_bar if player.name == "PlayerLeft" else right_dur_bar
	bar.max_value = max_value
	bar.value = current

func update_player_hp(player: CharacterBody2D, current: int, max_hp: int) -> void:
	var label := left_hp_label if player.name == "PlayerLeft" else right_hp_label
	label.text = "%d" % current

func update_player_bonus(player: CharacterBody2D, bonus_type: int) -> void:
	var icon: TextureRect = left_bonus_icon \
		if (player.name == "PlayerLeft") \
		else right_bonus_icon

	if bonus_type == game_manager.BonusType.NONE:
		icon.visible = false
		icon.texture = null
		return

	icon.texture = bonus_icons.get(bonus_type, null)
	icon.visible = icon.texture != null

func _update_bonus_timer(delta: float) -> void:
	if left_bonus_active:
		left_bonus_time_left = max(left_bonus_time_left - delta, 0.0)
		if left_bonus_duration > 0.0:
			left_bonus_timer.value = left_bonus_time_left / left_bonus_duration
		if left_bonus_time_left <= 0.0:
			left_bonus_active = false
			left_bonus_timer.visible = false

	if right_bonus_active:
		right_bonus_time_left = max(right_bonus_time_left - delta, 0.0)
		if right_bonus_duration > 0.0:
			right_bonus_timer.value = right_bonus_time_left / right_bonus_duration
		if right_bonus_time_left <= 0.0:
			right_bonus_active = false
			right_bonus_timer.visible = false

func start_player_bonus_timer(player: CharacterBody2D, duration: float) -> void:
	if player.name == "PlayerLeft":
		left_bonus_duration = duration
		left_bonus_time_left = duration
		left_bonus_active = true
		left_bonus_timer.visible = true
		left_bonus_timer.value = 1.0
	else:
		right_bonus_duration = duration
		right_bonus_time_left = duration
		right_bonus_active = true
		right_bonus_timer.visible = true
		right_bonus_timer.value = 1.0


func show_left_game_over(time_sec: float) -> void:
	left_go.show_game_over(time_sec)

func show_right_game_over(time_sec: float) -> void:
	right_go.show_game_over(time_sec)

func get_elapsed_time() -> float:
	return elapsed_time
