extends Node

var tile_size = 16
var tiles_to_show = 48
var world_left_x = 8 #0
var world_right_x = 640 - 8 #tiles_to_show * tile_size

const SHOVEL_LEVEL_EXPS = [50, 100, 200, 350, 450, 600, 750, 1150, 1300, 1700, 2500]
const MAX_DURABILITY := 1000

var HUD
var players := {}

func _ready() -> void:
	HUD = get_parent().get_node("HUD")

func register_player(player: CharacterBody2D):
	var id = player.name
	players[id] = {
		"experience": 0,
		"shovel_level": 1,
		"damage_per_hit": 1,
		"durability": MAX_DURABILITY
	}
	player.sync_stats_from_manager(players[id])

func change_durability(player: CharacterBody2D, delta_amount: int, restore: bool) -> void:
	var data = players[player.name]
	data.durability = MAX_DURABILITY if restore \
		else clamp(data.durability + delta_amount, 0, MAX_DURABILITY)
	player.sync_stats_from_manager(data)
	HUD.update_player_durability(player, data.durability, MAX_DURABILITY)

func add_player_exp(player: CharacterBody2D, amount: int):
	var data = players[player.name]
	data.experience += amount
	var exp_needed = SHOVEL_LEVEL_EXPS[data.shovel_level - 1]
	var leveled_up := false
	
	while data.experience >= exp_needed and data.shovel_level < SHOVEL_LEVEL_EXPS.size():
		data.experience -= exp_needed
		data.shovel_level += 1
		data.damage_per_hit += 1
		leveled_up = true
		exp_needed = SHOVEL_LEVEL_EXPS[data.shovel_level - 1]
	player.sync_stats_from_manager(data)
	
	if leveled_up:
		player.on_level_up()
		change_durability(player, 0, true)
		
	var player_id := 1 if player.name == "PlayerLeft" else 2
	HUD.update_player_hud(player_id, data.shovel_level, data.experience, leveled_up)


func get_world_x_boundaries():
	return [world_left_x, world_right_x]
	
func get_shovel_level_exps():
	return SHOVEL_LEVEL_EXPS

func get_max_durability():
	return MAX_DURABILITY
