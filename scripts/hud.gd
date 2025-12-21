extends CanvasLayer

var game_manager
var SHOVEL_LEVEL_EXPS
var elapsed_time: float = 0.0

@onready var left_bar: ProgressBar      = $LeftPlayerHUD/ExpProgressBar
@onready var left_label: Label          = $LeftPlayerHUD/LevelLabel
@onready var right_bar: ProgressBar     = $RightPlayerHUD/ExpProgressBar
@onready var right_label: Label         = $RightPlayerHUD/LevelLabel
@onready var timer_label: Label         = $TimerLabel
@onready var left_dur_bar: ProgressBar  = $LeftPlayerHUD/DurabilityBar
@onready var right_dur_bar: ProgressBar = $RightPlayerHUD/DurabilityBar
@onready var left_hp_label: Label       = $LeftPlayerHUD/HPLabel
@onready var right_hp_label: Label      = $RightPlayerHUD/HPLabel
@onready var left_go                   = $LeftGameOverOverlay
@onready var right_go                   = $RightGameOverOverlay

var left_level_tween: Tween
var right_level_tween: Tween

func _ready():	
	game_manager = get_tree().root.get_node("Main/GameManager")
	SHOVEL_LEVEL_EXPS = game_manager.get_shovel_level_exps()
	
	var max_dur = game_manager.get_max_durability()
	left_dur_bar.max_value = max_dur
	left_dur_bar.value = max_dur
	right_dur_bar.max_value = max_dur
	right_dur_bar.value = max_dur
	
func _process(delta: float) -> void:
	elapsed_time += delta
	timer_label.text = _format_time_mm_ss(elapsed_time)

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
	var base_scale := Vector2.ONE
	var big_scale := base_scale * 1.4

	if label == left_label and left_level_tween and left_level_tween.is_valid():
		left_level_tween.kill()
	if label == right_label and right_level_tween and right_level_tween.is_valid():
		right_level_tween.kill()

	var tween := get_tree().create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", big_scale, 0.22)
	tween.tween_property(label, "scale", base_scale, 0.48)

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

func show_left_game_over(time_sec: float) -> void:
	left_go.show_game_over(time_sec)

func show_right_game_over(time_sec: float) -> void:
	right_go.show_game_over(time_sec)

func get_elapsed_time() -> float:
	return elapsed_time
