extends Node2D

signal destroyed_tile

enum TerrainType {
	NORMAL = 1,
	IRON = 2,
	GOLD = 3,
	EMERALD = 4,
	RUBY = 5,
	DIAMOND = 6
}

var bonus_drops = []

@onready var tilemap = get_parent().get_parent().get_node("TileMapLayer") as TileMapLayer
@onready var dmgTilemap = get_parent().get_parent().get_node("TileMapLayerDmgOverlay") as TileMapLayer
@onready var effectTilemap = get_parent().get_parent().get_node("TileMapLayerEffectOverlay") as TileMapLayer
@onready var exp_pickup_scene := preload("res://scenes/pickup.tscn")

var tile_data = {} # key: Vector2 (pozícia tile), value: {"level": int, "hp": int}
var game_manager

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	game_manager = get_tree().root.get_node("Main/GameManager")
	
	bonus_drops = [
		{ "type": game_manager.BonusType.SHARPNESS },
		{ "type": game_manager.BonusType.SSHOVEL },
		{ "type": game_manager.BonusType.SABOTAGE},
		{ "type": game_manager.BonusType.DULLNESS },
		{ "type": game_manager.BonusType.OVERLOAD },
		{ "type": game_manager.BonusType.NONE }
	]

func calculate_tile_dmg_val(current_hp, max_hp, damage_per_hit, max_states=3) -> int:
	 # Ak je damage per hit väčšie alebo rovné max HP, tak sa stav mení o väčšiu hodnotu, ináč štandardne
	var step = damage_per_hit
	var state_count = max_states

	# vypočíta zníženie HP po zásahu
	var new_hp = max(current_hp - step, 0)

	# pamätajte si, že:
	# ak max_hp je 6 a current_hp je 4, range/rúsiť od 0 do 6 alebo upraviť?
	# tu zvolíme pomer hp k max_hp
	var hp_ratio = float(new_hp) / float(max_hp)

	# Prevod na počet štátov
	# napr. ak je max_states=3, rozdelíme na 4 intervaly (0,1,2,3)
	var state_value = int(hp_ratio * (state_count + 1))

	# ak je hodnoty hraničné, tak ho upravíme
	state_value = clamp(state_value, 0, state_count)
	return max_states - state_value

func damage_tile(player: CharacterBody2D):
	var shovel_dir_node := get_parent().get_node("ShovelDirection")
	var area := shovel_dir_node.get_node("Area2D") as Area2D
	
	var area_pos = area.global_position
	var dir_vec := (area_pos - player.global_position).normalized()
	
	# hranice subviewportun pre daného hráča
	var min_x := 0.0
	var max_x := 318.0
	if player.name == "PlayerRight":
		min_x = 322.0
		max_x = 640.0
	
	if area_pos.x < min_x or area_pos.x > max_x:
		AudioManager.play("res://assets/sounds/disabled.wav", "SFXLower", false)
		return  # mimo svojho pásma, nič nenič
	
	var tile_coords = tilemap.local_to_map(tilemap.to_local(area_pos))
	var tileset = tilemap.tile_set
	var tile_data_res: TileData = tilemap.get_cell_tile_data(tile_coords)

	# Skontroluj existenciu dlaždice
	var tile_id = tilemap.get_cell_source_id(tile_coords)
	if tile_id == -1:
		return

	# Zisti typ bloku
	var terrain_type
	if tileset.has_custom_data_layer_by_name("terrainType") and tile_data_res:
		var terrain_layer = tileset.get_custom_data_layer_by_name("terrainType")
		terrain_type = tile_data_res.get_custom_data_by_layer_id(terrain_layer)

	# Level / hardness
	var tile_level := 4
	if tileset.has_custom_data_layer_by_name("hardness") and tile_data_res:
		var hardness_layer = tileset.get_custom_data_layer_by_name("hardness")
		tile_level += int(tile_data_res.get_custom_data_by_layer_id(hardness_layer))
		
	if player.shovel_level + 6 < tile_level:
		AudioManager.play("res://assets/sounds/disabled.wav", "SFXLower", false)
		return
		
	if tile_coords not in tile_data:
		tile_data[tile_coords] = { "level": tile_level, "hp": tile_level }
		
	# Odober hp
	tile_data[tile_coords].hp -= player.damage_per_hit
	if player.durability <= 0:
		AudioManager.play("res://assets/sounds/hit3.wav", "SFXLower")
	else:
		AudioManager.play("res://assets/sounds/hit2.wav", "SFXLower")
	
	#var damage_tile_value = get_max_hp_for_tile(tile_level) - tile_data[tile_coords].hp
	var damage_tile_value = calculate_tile_dmg_val(
		tile_data[tile_coords].hp, 
		tile_level,
		player.damage_per_hit
	)
	
	game_manager.change_durability(player, -10, false)
	
	# SSHOVEL: znič druhý blok v smere kopania
	if game_manager.player_has_bonus(player, game_manager.BonusType.SSHOVEL):
		_damage_second_tile(tile_coords, dir_vec, player)
	
	if tile_data[tile_coords].hp <= 0:
		#tilemap.set_cell(tile_coords, tile_id, tile_coords, -1) # Odstráni tile
		var terrain_set_id = tile_data_res.get_terrain_set() if tile_data_res else 0
		
		tilemap.set_cells_terrain_connect([tile_coords], terrain_set_id, -1, true)
		dmgTilemap.set_cell(tile_coords, tile_id, tile_coords, -1)
		effectTilemap.set_cell(tile_coords, 0, Vector2i(-1, -1))
		tile_data.erase(tile_coords)
		
		destroyed_tile.emit(terrain_type, player)
		drop_items_based_on_tile(terrain_type, player, tile_coords)
		_try_drop_bonus(terrain_type, player)
	else:
		dmgTilemap.set_cell(tile_coords, tile_id, Vector2(damage_tile_value, 0))

func _damage_second_tile(first_coords: Vector2i, dir_vec: Vector2, player: CharacterBody2D) -> void:
	# smer v tile mape (−1, 0, 1) podľa dir_vec
	var step := Vector2i(
		int(round(dir_vec.x)),
		int(round(dir_vec.y))
	)

	if step == Vector2i.ZERO:
		return

	var second_coords := first_coords + step
	var second_global_pos := tilemap.to_global(tilemap.map_to_local(second_coords))
	
	var min_x := 0.0
	var max_x := 318.0
	if player.name == "PlayerRight":
		min_x = 322.0
		max_x = 640.0
	
	# kontrola či nejde poza čiaru
	if second_global_pos.x < min_x or second_global_pos.x > max_x:
		AudioManager.play("res://assets/sounds/disabled.wav", "SFXLower", false)
		return
	
	var tile_id := tilemap.get_cell_source_id(second_coords)
	if tile_id == -1:
		return

	var tileset = tilemap.tile_set
	var tile_data_res: TileData = tilemap.get_cell_tile_data(second_coords)

	var tile_level = 4
	var has_hardness: bool = tileset.has_custom_data_layer_by_name("hardness")
	if has_hardness and tile_data_res:
		var hardness_layer = tileset.get_custom_data_layer_by_name("hardness")
		tile_level += int(tile_data_res.get_custom_data_by_layer_id(hardness_layer))

	var has_terrain_type: bool = tileset.has_custom_data_layer_by_name("terrainType")

	# Zisti typ bloku
	var terrain_type
	if has_terrain_type and tile_data_res:
		var layer_index = tileset.get_custom_data_layer_by_name("terrainType")
		terrain_type = tile_data_res.get_custom_data_by_layer_id(layer_index)

	if second_coords not in tile_data:
		tile_data[second_coords] = {
			"level": tile_level,
			"hp": tile_level
		}

	tile_data[second_coords].hp -= player.damage_per_hit
	if player.durability <= 0:
		AudioManager.play("res://assets/sounds/hit3.wav", "SFXLower")
	else:
		AudioManager.play("res://assets/sounds/hit2.wav", "SFXLower")

	var damage_tile_value := calculate_tile_dmg_val(
		tile_data[second_coords].hp,
		tile_level,
		player.damage_per_hit
	)

	if tile_data[second_coords].hp <= 0:
		#tilemap.set_cell(second_coords, tile_id, second_coords, -1)
		var terrain_set_id = tile_data_res.get_terrain_set() if tile_data_res else 0
		
		tilemap.set_cells_terrain_connect([second_coords], terrain_set_id, -1, true)
		dmgTilemap.set_cell(second_coords, tile_id, second_coords, -1)
		effectTilemap.set_cell(second_coords, 0, Vector2i(-1, -1))
		tile_data.erase(second_coords)

		destroyed_tile.emit(terrain_type, player)
		drop_items_based_on_tile(terrain_type, player, second_coords)
		_try_drop_bonus(terrain_type, player)
	else:
		dmgTilemap.set_cell(second_coords, tile_id, Vector2(damage_tile_value, 0))

func pick_weighted_drop(drop_table):
	var rand = randf()
	var cumulative = 0.0
	
	for drop in drop_table:
		cumulative += drop["chance"]
		if rand < cumulative:
			return drop["exp"]
	# fallback ak nič nepadne, zober prvý item
	return drop_table[0]["exp"]
	
func pick_bonus(list: Array, terrain_type: TerrainType):
	var chance := 0.0
	match terrain_type:
		TerrainType.IRON: chance = 0.05 # 0.05 -> 95% nič
		TerrainType.GOLD: chance = 0.07
		TerrainType.EMERALD: chance = 0.09
		TerrainType.RUBY: chance = 0.12
		TerrainType.DIAMOND: chance = 0.15
		_: chance = 0.0  # ostatné bloky nikdy nedajú bonus

	var r := randf()
	if r >= chance:
		return game_manager.BonusType.NONE

	if list.is_empty():
		return game_manager.BonusType.NONE

	var buffs: Array = [ game_manager.BonusType.SHARPNESS, game_manager.BonusType.SSHOVEL,
		game_manager.BonusType.SABOTAGE ]
	var debuffs: Array = [ game_manager.BonusType.DULLNESS, 
		game_manager.BonusType.OVERLOAD ]
	
   # 67% buff, 33% debuff
	var roll := randf()
	if roll < 0.67 and not buffs.is_empty():
		var index := randi_range(0, buffs.size() - 1)
		return buffs[index]
	elif not debuffs.is_empty():
		var index := randi_range(0, debuffs.size() - 1)
		return debuffs[index]
	
	#var index := randi_range(0, list.size() - 1)
	#return list[index].type

func drop_items_based_on_tile(terrain_type: TerrainType, player: CharacterBody2D,
	tile_coords: Vector2i):
	const AVAILABLE_TILE_TYPES = [TerrainType.IRON, TerrainType.GOLD]
	if !AVAILABLE_TILE_TYPES.has(terrain_type):
		return
	
	var drops
	if terrain_type == TerrainType.IRON:
		drops = [
			{"exp": 10, "chance": 0.3}, # 30%
			{"exp": 20, "chance": 0.2},
			{"exp": 35, "chance": 0.15},
			{"exp": 50, "chance": 0.1} 
		]
	elif terrain_type == TerrainType.GOLD \
		or terrain_type == TerrainType.EMERALD:
		drops = [
			{"exp": 15, "chance": 0.3},
			{"exp": 25, "chance": 0.2},
			{"exp": 50, "chance": 0.15},
			{"exp": 75, "chance": 0.1} 
		]
	elif terrain_type == TerrainType.RUBY:
		drops = [
			{"exp": 15, "chance": 0.3},
			{"exp": 25, "chance": 0.2},
			{"exp": 50, "chance": 0.15},
			{"exp": 75, "chance": 0.1} 
		]
	elif terrain_type == TerrainType.DIAMOND:
		drops = [
			{"exp": 15, "chance": 0.3},
			{"exp": 25, "chance": 0.2},
			{"exp": 50, "chance": 0.15},
			{"exp": 75, "chance": 0.1} 
		]
	
	var exp_value = pick_weighted_drop(drops)
	#player.add_exp(exp_value)
	_spawn_exp_pickups(exp_value, player, tile_coords, terrain_type)

func _try_drop_bonus(terrain_type: TerrainType, player: CharacterBody2D) -> void:
	# ak už hráč má 2 bonusy, nič nové nepadá
	if !game_manager.can_apply_bonus(player):
		return
	
	var p_type = pick_bonus(bonus_drops, terrain_type)
	if p_type == game_manager.BonusType.NONE:
		return
		
	# ak už má tento typ, nepridaj ho
	if game_manager.player_has_bonus(player, p_type):
		return

	game_manager.apply_bonus(player, p_type)


func _spawn_exp_pickups(exp_value: int, player: CharacterBody2D,
	tile_coords: Vector2i, terrain_type: TerrainType) -> void:
	var per_pickup := 10               # 1 štvorec = 10 exp (prispôsob si)
	var count: int = maxi(int(float(exp_value) / float(per_pickup)), 1)

	# svetová pozícia zničenej dlaždice – použij tú, čo máš v damage_tile
	var tile_center_local := tilemap.map_to_local(tile_coords)
	var tile_center_global := tilemap.to_global(tile_center_local)
	var tile_size = game_manager.get_tile_size()
	
	var spawn_pos := tile_center_global - Vector2(0, tile_size * 0.5)
	var level := get_parent().get_parent() 

	for i in count:
		var pickup: RigidBody2D = exp_pickup_scene.instantiate()
		pickup.exp_amount = per_pickup
		pickup.target_player = player
		pickup.terrain_type = terrain_type

		# mierny náhodný offset, nech nepadajú všetky z jedného pixlu
		var offset := Vector2(randf_range(-8, 8), randf_range(-8, 8))
		pickup.global_position = spawn_pos + offset

		level.add_child(pickup)
