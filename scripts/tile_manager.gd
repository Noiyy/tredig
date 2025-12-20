extends Node2D

signal destroyed_tile

enum TerrainType {
	NORMAL = 1,
	IRON = 2,
	GOLD = 3
}

@onready var tilemap = get_parent().get_parent().get_node("TileMapLayer") as TileMapLayer
@onready var dmgTilemap = get_parent().get_parent().get_node("TileMapLayerDmgOverlay") as TileMapLayer

var tile_data = {} # key: Vector2 (pozícia tile), value: {"level": int, "hp": int}
var game_manager

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	game_manager = get_tree().root.get_node("Main/GameManager")
	
func get_max_hp_for_tile(level: int) -> int:
	return 3 + level

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
	var area_pos = get_parent().get_node("ShovelDirection/Area2D").global_position
	
	# hranice subviewportun pre daného hráča
	var min_x := 0.0
	var max_x := 318.0
	if player.name == "PlayerRight":
		min_x = 322.0
		max_x = 640.0
	
	if area_pos.x < min_x or area_pos.x > max_x:
		return  # mimo svojho pásma, nič nenič
	
	var tile_coords = tilemap.local_to_map(tilemap.to_local(area_pos))
	var tile_atlas_coords = tilemap.get_cell_atlas_coords(tile_coords)
	var tileset = tilemap.tile_set

	# Skontroluj existenciu dlaždice
	var tile_id = tilemap.get_cell_source_id(tile_coords)
	if tile_id != -1:
		var hasTerrainType = tileset.has_custom_data_layer_by_name("terrainType")
		
		# Zisti typ bloku
		var terrain_type
		if hasTerrainType:
			var layer_index = tileset.get_custom_data_layer_by_name("terrainType")
			var tile_data = tilemap.get_cell_tile_data(tile_coords)
			terrain_type = tile_data.get_custom_data_by_layer_id(layer_index)
		
		# inicializuj hp ak neexistuje
		var tile_level = tile_atlas_coords.y+1
		if tile_coords not in tile_data:
			tile_data[tile_coords] = { "level": tile_level, "hp": get_max_hp_for_tile(tile_level) }
			
		# Odober hp
		tile_data[tile_coords].hp -= player.damage_per_hit
		#var damage_tile_value = get_max_hp_for_tile(tile_level) - tile_data[tile_coords].hp
		var damage_tile_value = calculate_tile_dmg_val(
			tile_data[tile_coords].hp, 
			get_max_hp_for_tile(tile_level),
			player.damage_per_hit
		)
		
		game_manager.change_durability(player, -10, false)
		
		if tile_data[tile_coords].hp <= 0:
			tilemap.set_cell(tile_coords, tile_id, tile_coords, -1) # Odstráni tile
			dmgTilemap.set_cell(tile_coords, tile_id, tile_coords, -1)
			tile_data.erase(tile_coords)
			
			destroyed_tile.emit(terrain_type, player)
			drop_items_based_on_tile(terrain_type, player)
		else:
			dmgTilemap.set_cell(tile_coords, tile_id, Vector2(damage_tile_value, 0))

func pick_weighted_drop(drop_table):
	var rand = randf()
	var cumulative = 0.0
	
	for drop in drop_table:
		cumulative += drop["chance"]
		if rand < cumulative:
			return drop["exp"]
	# fallback ak nič nepadne, zober prvý item
	return drop_table[0]["exp"]

func drop_items_based_on_tile(terrain_type: TerrainType, player: CharacterBody2D):
	const AVAILABLE_TILE_TYPES = [2, 3]
	if !AVAILABLE_TILE_TYPES.has(terrain_type):
		return
	
	var drops
	if terrain_type == 2:
		drops = [
			{"exp": 5, "chance": 0.3}, # 30%
			{"exp": 10, "chance": 0.2},
			{"exp": 30, "chance": 0.15},
			{"exp": 50, "chance": 0.1} 
		]
	elif terrain_type == 3:
		drops = [
			{"exp": 15, "chance": 0.3},
			{"exp": 25, "chance": 0.2},
			{"exp": 50, "chance": 0.15},
			{"exp": 75, "chance": 0.1} 
		]
	
	var exp_value = pick_weighted_drop(drops)
	player.add_exp(exp_value)
