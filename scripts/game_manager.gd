extends Node

var tile_size = 16
var tiles_to_show = 48
var world_left_x = 8 #0
var world_right_x = 640 - 8 #tiles_to_show * tile_size

const SHOVEL_LEVEL_EXPS = [50, 100, 200, 350, 450, 600, 750, 1150, 1300, 1700, 2500]
const MAX_HP := 100
const MAX_DURABILITY := 1000

var lava
var HUD
var players := {}

enum BonusType {
	NONE,
	SHARPNESS,
	SSHOVEL,
	SABOTAGE,
	DULLNESS,
	OVERLOAD
}

func _ready() -> void:
	HUD = get_parent().get_node("HUD")
	lava = get_tree().root.get_node("Main/HBoxContainer/LeftSubViewportContainer/LeftSubViewport/Level/Lava")

func register_player(player: CharacterBody2D):
	var id = player.name
	players[id] = {
		"experience": 0,
		"shovel_level": 1,
		"damage_per_hit": 1,
		"durability": MAX_DURABILITY,
		"hp": MAX_HP,
		"ref": player,
		"active_bonus": BonusType.NONE,
	}
	player.sync_stats_from_manager(players[id])

func damage_player(player: CharacterBody2D, amount: int) -> void:
	var data = players[player.name]
	data.hp = max(data.hp - amount, 0)
	player.sync_stats_from_manager(data)
	HUD.update_player_hp(player, data.hp, MAX_HP)
	
	if data.hp == 0 and not player.is_dead:
		player.on_dead()
		_check_game_over()

func _check_game_over() -> void:
	var left  = players["PlayerLeft"].ref
	var right = players["PlayerRight"].ref

	if left.is_dead and right.is_dead:
		_on_both_players_dead()

func _on_both_players_dead() -> void:
	HUD.stop_timer()
	lava.stop_growing()

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

func apply_bonus(player: CharacterBody2D, b_type: int) -> void:
	match b_type:
		BonusType.SHARPNESS:
			_add_timed_stat(player, b_type, "damage", 1, 10.0)
		BonusType.SSHOVEL:
			_add_timed_stat(player, b_type, "sshovel", 1, 10.0)
		BonusType.SABOTAGE:
			_add_timed_stat(player, b_type, "sabotage", 1, 10.0)
		BonusType.DULLNESS:
			_add_timed_stat(player, b_type, "dullness", 1, 10.0)
		BonusType.OVERLOAD:
			_add_overload_debuff(player, 7.0)
	

func _add_timed_stat(player: CharacterBody2D, b_type: BonusType, key: String, delta: float,
 	duration: float) -> void:
	var data = players[player.name]
	if not data.has("effects"):
		data.effects = {}
	if not data.effects.has(key):
		data.effects[key] = 0.0
	data.effects[key] += delta

	# uprav stat v dátach
	match key:
		"damage":
			data.damage_per_hit += int(delta)
		"dullness":
			data.damage_per_hit -= int(delta) if data.damage_per_hit > 1 else 0

	players[player.name].active_bonus = b_type
	player.sync_stats_from_manager(data)
	HUD.update_player_bonus(player, b_type)
	HUD.start_player_bonus_timer(player, duration)

	# plánuj zrušenie
	var t := get_tree().create_timer(duration)
	t.timeout.connect(func():
		if not is_instance_valid(player):
			return
		data.effects[key] -= delta
		
		match key:
			"damage":
				data.damage_per_hit -= int(delta)
			"dullness":
				data.damage_per_hit += int(delta)
				
		players[player.name].active_bonus = BonusType.NONE
		player.sync_stats_from_manager(data)
		HUD.update_player_bonus(player, BonusType.NONE)
	)

func _add_overload_debuff(player: CharacterBody2D, duration: float) -> void:
	var data = players[player.name]
	if not data.has("effects"):
		data.effects = {}

	# označ aktívny bonus
	players[player.name].active_bonus = BonusType.OVERLOAD

	# aplikuj debuff na hráča
	player.set_can_dig(false)
	player.set_speed_multiplier(0.5)  # 50 % rýchlosti

	HUD.update_player_bonus(player, BonusType.OVERLOAD)
	HUD.start_player_bonus_timer(player, duration)

	var t := get_tree().create_timer(duration)
	t.timeout.connect(func():
		if not is_instance_valid(player):
			return

		# zrušenie efektu
		player.set_can_dig(true)
		player.set_speed_multiplier(1.0)

		players[player.name].active_bonus = BonusType.NONE
		player.sync_stats_from_manager(data)  # vráť ostatné staty, ak treba
		HUD.update_player_bonus(player, BonusType.NONE)
	)


func player_has_active_bonus(player: CharacterBody2D) -> bool:
	return players[player.name].get("active_bonus", BonusType.NONE) != BonusType.NONE

func player_has_bonus(player: CharacterBody2D, bonus_type: int) -> bool:
	return players[player.name].get("active_bonus", BonusType.NONE) == bonus_type

func get_world_x_boundaries():
	return [world_left_x, world_right_x]
	
func get_shovel_level_exps():
	return SHOVEL_LEVEL_EXPS

func get_max_durability():
	return MAX_DURABILITY
	
func get_tile_size():
	return tile_size
