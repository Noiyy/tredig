extends CanvasLayer

var game_manager
var SHOVEL_LEVEL_EXPS

@onready var left_bar: ProgressBar  = $LeftPlayerHUD/ExpProgressBar
@onready var left_label: Label      = $LeftPlayerHUD/LevelLabel
@onready var right_bar: ProgressBar = $RightPlayerHUD/ExpProgressBar
@onready var right_label: Label     = $RightPlayerHUD/LevelLabel

func _ready():	
	game_manager = get_tree().root.get_node("Main/GameManager")
	SHOVEL_LEVEL_EXPS = game_manager.get_shovel_level_exps()

func _get_exp_needed_for_level(shovel_level: int) -> int:
	var index: int = clamp(shovel_level - 1, 0, SHOVEL_LEVEL_EXPS.size() - 1)
	return SHOVEL_LEVEL_EXPS[index]


func update_player_hud(player_id: int, shovel_level: int, experience: int) -> void:
	var exp_needed := _get_exp_needed_for_level(shovel_level)

	if player_id == 1:
		left_bar.max_value = exp_needed
		left_bar.value = experience
		left_label.text = "%d" % shovel_level
	elif player_id == 2:
		right_bar.max_value = exp_needed
		right_bar.value = experience
		right_label.text = "%d" % shovel_level
