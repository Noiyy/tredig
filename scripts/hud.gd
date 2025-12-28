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

@onready var left_bonus1: Control           = $LeftPlayerHUD/Bonus1
@onready var right_bonus1: Control          = $RightPlayerHUD/Bonus1
@onready var left_bonus_icon1: TextureRect  = $LeftPlayerHUD/Bonus1/BonusIcon
@onready var right_bonus_icon1: TextureRect = $RightPlayerHUD/Bonus1/BonusIcon
@onready var left_bonus_timer1: TextureProgressBar  = $LeftPlayerHUD/Bonus1/BonusTimerBar
@onready var right_bonus_timer1: TextureProgressBar = $RightPlayerHUD/Bonus1/BonusTimerBar
@onready var left_bonus2: Control           = $LeftPlayerHUD/Bonus2
@onready var right_bonus2: Control          = $RightPlayerHUD/Bonus2
@onready var left_bonus_icon2: TextureRect  = $LeftPlayerHUD/Bonus2/BonusIcon
@onready var right_bonus_icon2: TextureRect = $RightPlayerHUD/Bonus2/BonusIcon
@onready var left_bonus_timer2: TextureProgressBar  = $LeftPlayerHUD/Bonus2/BonusTimerBar
@onready var right_bonus_timer2: TextureProgressBar = $RightPlayerHUD/Bonus2/BonusTimerBar

# Left player slot 1
var left_bonus1_active: bool = false
var left_bonus1_duration: float = 0.0
var left_bonus1_time_left: float = 0.0

# Left player slot 2  
var left_bonus2_active: bool = false
var left_bonus2_duration: float = 0.0
var left_bonus2_time_left: float = 0.0

# Right player slot 1
var right_bonus1_active: bool = false
var right_bonus1_duration: float = 0.0
var right_bonus1_time_left: float = 0.0

# Right player slot 2
var right_bonus2_active: bool = false
var right_bonus2_duration: float = 0.0
var right_bonus2_time_left: float = 0.0

var left_bonus1_type: int = -1
var left_bonus2_type: int = -1
var right_bonus1_type: int = -1
var right_bonus2_type: int = -1

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
	
	left_bonus_timer1.step = 0.01
	left_bonus_timer2.step = 0.01
	right_bonus_timer1.step = 0.01
	right_bonus_timer2.step = 0.01
	
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
	
	# Zmeň farbu na červenú ak HP <= 30
	if current <= 30:
		label.modulate = Color("#752438")
	else:
		label.modulate = Color.WHITE

func update_player_bonuses(player: CharacterBody2D, bonuses: Array) -> void:
	if player.name == "PlayerLeft":
		var bonus1: Control = left_bonus1
		var icon1: TextureRect = left_bonus_icon1
		var timer_bar1: TextureProgressBar = left_bonus_timer1
		var bonus2: Control = left_bonus2
		var icon2: TextureRect = left_bonus_icon2
		var timer_bar2: TextureProgressBar = left_bonus_timer2
		
		# Aktualizuj slot 1 - podľa typu bonusu v slot 1
		if left_bonus1_type != -1 and bonuses.has(left_bonus1_type):
			var tint_color1 = Color("#31e312be")
			if left_bonus1_type == game_manager.BonusType.OVERLOAD or left_bonus1_type == game_manager.BonusType.DULLNESS:
				tint_color1 = Color("#ff0000be")
			
			icon1.texture = bonus_icons.get(left_bonus1_type, null)
			timer_bar1.tint_progress = tint_color1
			bonus1.visible = true
		else:
			bonus1.visible = false
			icon1.texture = null
			timer_bar1.tint_progress = Color("#31e312be")
		
		# Aktualizuj slot 2 - podľa typu bonusu v slot 2
		if left_bonus2_type != -1 and bonuses.has(left_bonus2_type):
			var tint_color2 = Color("#31e312be")
			if left_bonus2_type == game_manager.BonusType.OVERLOAD or left_bonus2_type == game_manager.BonusType.DULLNESS:
				tint_color2 = Color("#ff0000be")
			
			icon2.texture = bonus_icons.get(left_bonus2_type, null)
			timer_bar2.tint_progress = tint_color2
			bonus2.visible = true
		else:
			bonus2.visible = false
			icon2.texture = null
			timer_bar2.tint_progress = Color("#31e312be")
	
	else:  # Right player
		var bonus1: Control = right_bonus1
		var icon1: TextureRect = right_bonus_icon1
		var timer_bar1: TextureProgressBar = right_bonus_timer1
		var bonus2: Control = right_bonus2
		var icon2: TextureRect = right_bonus_icon2
		var timer_bar2: TextureProgressBar = right_bonus_timer2
		
		# Aktualizuj slot 1
		if right_bonus1_type != -1 and bonuses.has(right_bonus1_type):
			var tint_color1 = Color("#31e312be")
			if right_bonus1_type == game_manager.BonusType.OVERLOAD or right_bonus1_type == game_manager.BonusType.DULLNESS:
				tint_color1 = Color("#ff0000be")
			
			icon1.texture = bonus_icons.get(right_bonus1_type, null)
			timer_bar1.tint_progress = tint_color1
			bonus1.visible = true
		else:
			bonus1.visible = false
			icon1.texture = null
			timer_bar1.tint_progress = Color("#31e312be")
		
		# Aktualizuj slot 2
		if right_bonus2_type != -1 and bonuses.has(right_bonus2_type):
			var tint_color2 = Color("#31e312be")
			if right_bonus2_type == game_manager.BonusType.OVERLOAD or right_bonus2_type == game_manager.BonusType.DULLNESS:
				tint_color2 = Color("#ff0000be")
			
			icon2.texture = bonus_icons.get(right_bonus2_type, null)
			timer_bar2.tint_progress = tint_color2
			bonus2.visible = true
		else:
			bonus2.visible = false
			icon2.texture = null
			timer_bar2.tint_progress = Color("#31e312be")

func _update_bonus_timer(delta: float) -> void:
	# Left player slot 1
	if left_bonus1_active:
		left_bonus1_time_left = max(left_bonus1_time_left - delta, 0.0)
		if left_bonus1_duration > 0.0:
			left_bonus_timer1.value = left_bonus1_time_left / left_bonus1_duration
		if left_bonus1_time_left <= 0.0:
			left_bonus1_active = false
			left_bonus1_type = -1

	# Left player slot 2
	if left_bonus2_active:
		left_bonus2_time_left = max(left_bonus2_time_left - delta, 0.0)
		if left_bonus2_duration > 0.0:
			left_bonus_timer2.value = left_bonus2_time_left / left_bonus2_duration
		if left_bonus2_time_left <= 0.0:
			left_bonus2_active = false
			left_bonus2_type = -1

	# Right player slot 1
	if right_bonus1_active:
		right_bonus1_time_left = max(right_bonus1_time_left - delta, 0.0)
		if right_bonus1_duration > 0.0:
			right_bonus_timer1.value = right_bonus1_time_left / right_bonus1_duration
		if right_bonus1_time_left <= 0.0:
			right_bonus1_active = false
			right_bonus1_type = -1

	# Right player slot 2
	if right_bonus2_active:
		right_bonus2_time_left = max(right_bonus2_time_left - delta, 0.0)
		if right_bonus2_duration > 0.0:
			right_bonus_timer2.value = right_bonus2_time_left / right_bonus2_duration
		if right_bonus2_time_left <= 0.0:
			right_bonus2_active = false
			right_bonus2_type = -1

func start_player_bonus_timer(player: CharacterBody2D, duration: float, bonus_type: int) -> void:
	if player.name == "PlayerLeft":
		if not left_bonus1_active:
			left_bonus1_duration = duration
			left_bonus1_time_left = duration
			left_bonus1_active = true
			left_bonus1_type = bonus_type
			left_bonus1.visible = true
			left_bonus_timer1.value = 1.0
		elif not left_bonus2_active:
			left_bonus2_duration = duration
			left_bonus2_time_left = duration
			left_bonus2_active = true
			left_bonus2_type = bonus_type
			left_bonus2.visible = true
			left_bonus_timer2.value = 1.0
	else:
		if not right_bonus1_active:
			right_bonus1_duration = duration
			right_bonus1_time_left = duration
			right_bonus1_active = true
			right_bonus1_type = bonus_type
			right_bonus1.visible = true
			right_bonus_timer1.value = 1.0
		elif not right_bonus2_active:
			right_bonus2_duration = duration
			right_bonus2_time_left = duration
			right_bonus2_active = true
			right_bonus2_type = bonus_type
			right_bonus2.visible = true
			right_bonus_timer2.value = 1.0

func show_left_game_over(time_sec: float) -> void:
	left_go.show_game_over(time_sec)

func show_right_game_over(time_sec: float) -> void:
	right_go.show_game_over(time_sec)

func get_elapsed_time() -> float:
	return elapsed_time
