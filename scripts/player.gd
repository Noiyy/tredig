extends CharacterBody2D

var SPEED = 200.0
var JUMP_VELOCITY = -200.0

var world_left_x = 0
var world_right_x = 0

@export var controls: PlayerControls = null
@export var tilemap: TileMapLayer

@export var damage_per_hit = 1
@export var shovel_level = 1
@export var experience = 0
@export var hp = 100
@export var durability = 1000
var is_dead = false
var can_dig: bool = true
var base_speed: float = SPEED
var base_jump_velocity: float = JUMP_VELOCITY
 
var HUD
var game_manager
@onready var tile_manager = $TileManager
@onready var death_timer = $DeathTimer
@onready var shovel_highlight = $ShovelDirection/TileHighlight 
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var shovel_distance = 14
var last_dir := Vector2.DOWN

var facing_left: bool = false
var is_digging: bool = false
var dig_anim_time: float = 0.0
const DIG_ANIM_DURATION := 0.25


func _ready():
	if name == "PlayerLeft":
		animated_sprite.sprite_frames = preload("res://resources/playerL_sprites.tres")
	elif name == "PlayerRight":
		animated_sprite.sprite_frames = preload("res://resources/playerR_sprites.tres")
	
	if controls == null:
		set_physics_process(false)
	
	game_manager = get_tree().root.get_node("Main/GameManager")
	game_manager.register_player(self)
	
	var x_boundaries = game_manager.get_world_x_boundaries();
	world_left_x = x_boundaries[0];
	world_right_x = x_boundaries[1];
	
	HUD = get_tree().root.get_node("Main/HUD")

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed(controls.move_up) and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	var direction := Input.get_axis(controls.move_left, controls.move_right)
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# update dig stavu
	if is_digging:
		dig_anim_time -= delta
		if dig_anim_time <= 0.0:
			is_digging = false

	# animácie podľa stavu
	if is_digging:
		# nechaj bežať aktuálnu dig animáciu, nič neprepínaj
		pass
	elif velocity.x != 0:
		animated_sprite.play("walk")
	else:
		animated_sprite.play("idle")

	move_and_slide()
	global_position.x = clamp(global_position.x, world_left_x, world_right_x)

func _process(delta: float) -> void:
	var direction = Vector2.ZERO
		
	direction.x = Input.get_action_strength(controls.move_right) - Input.get_action_strength(controls.move_left)
	direction.y = Input.get_action_strength(controls.move_down) - Input.get_action_strength(controls.move_up)
	
	if direction != Vector2.ZERO:
		direction = direction.normalized()
		last_dir = direction
		var distance = shovel_distance
		
		#$"ShovelDirection/Area2D".position = direction * distance
		$ShovelDirection.rotation = direction.angle()
		
		var min_x := 0.0
		var max_x := 318.0
		if self.name == "PlayerRight":
			min_x = 322.0
			max_x = 640.0
	 
		var area_pos = $ShovelDirection/Area2D.global_position
		if area_pos.x < global_position.x:
			facing_left = true
			animated_sprite.position.x = -6
		else:
			facing_left = false
			animated_sprite.position.x = 6
		animated_sprite.flip_h = facing_left

		# Snap shovel highlight to the nearest tile, show highlight if colliding with tile
		if area_pos.x < min_x or area_pos.x > max_x:
			shovel_highlight.visible = false
			return
		
		var tile_coords = tilemap.local_to_map(tilemap.to_local(area_pos))
		var tile_id = tilemap.get_cell_source_id(tile_coords)
		
		var tile_level = 4
		var tileset = tilemap.tile_set
		var tile_data_res = tilemap.get_cell_tile_data(tile_coords)
		if tileset.has_custom_data_layer_by_name("hardness") and tile_data_res:
			var level_layer = tileset.get_custom_data_layer_by_name("hardness")
			print("broo ", level_layer)
			tile_level += int(tile_data_res.get_custom_data_by_layer_id(level_layer))

		print("huh ", shovel_level, " a ", tile_level)
		# SKRY Highlight ak hráč je slabší ako blok
		if tile_id != -1 and shovel_level + 6 >= tile_level:
			shovel_highlight.visible = true
		else:
			shovel_highlight.visible = false
			return

		# Calculate tile center in world space
		#var tile_center = tilemap.map_to_local(tile_coords) + Vector2.ZERO / 2
		var tile_center_local = tilemap.map_to_local(tile_coords)
		var tile_center_global = tilemap.to_global(tile_center_local)

		shovel_highlight.global_position = tile_center_global
		#shovel_highlight.global_position = tile_center
		
		# Rotation for diagonal tiles
		if abs(direction.x) > 0.5 and abs(direction.y) > 0.5:
			# Diagonal direction
			if (direction.x > 0 and direction.y > 0) or (direction.x < 0 and direction.y < 0):
				# Bottom-right or top-left => +45°
				shovel_highlight.rotation_degrees = 45
			else:
				# Bottom-left or top-right => -45°
				shovel_highlight.rotation_degrees = -45
		else:
			# Not diagonal (vertical or horizontal) => no rotation
			shovel_highlight.rotation_degrees = 0

		if tile_id != -1:
			shovel_highlight.visible = true
		else:
			shovel_highlight.visible = false
	else:
		shovel_highlight.visible = false

func _input(event):
	if event.is_action_pressed(controls.use, true):
		if not can_dig:
			return
		if durability <= 0: 
			return
			
		var anim := "dig_down"
		if abs(last_dir.y) > abs(last_dir.x):
			anim = "dig_up" if last_dir.y < 0 else "dig_down"
		else:
			anim = "dig_horizontal"

		is_digging = true
		dig_anim_time = DIG_ANIM_DURATION
		animated_sprite.flip_h = facing_left
		#print("! ", anim, " is ", facing_left)
		animated_sprite.play(anim)
		tile_manager.damage_tile(self)
			
func add_exp(amount: int):
	game_manager.add_player_exp(self, amount)
	
func sync_stats_from_manager(data: Dictionary):
	experience = data.experience
	shovel_level = data.shovel_level
	damage_per_hit = data.damage_per_hit
	durability = data.durability
	hp = data.hp
	
func apply_stat_change(key: String, delta: float) -> void:
	match key:
		"damage":
			damage_per_hit += int(delta)

func apply_sabotage_effect() -> void:
	var tile_size = game_manager.get_tile_size()
	var start_x = int(0 if name == "PlayerLeft" else (320 / tile_size))
	var start_y = int(global_position.y / tile_size) + 1  # pod hráčom
	
	# Zvýš HP pre 3 riadky pod hráčom
	for y_offset in 3:
		var target_y = start_y + y_offset
		for x_offset in 20:  # cela šírka pre 1 hráča
			var target_coords = Vector2i(start_x + x_offset, target_y)
			
			var tile_id = tile_manager.tilemap.get_cell_source_id(target_coords)
			if tile_id == -1:
				continue  # žiadny blok, preskoč
			
			var tile_atlas_coords = tile_manager.tilemap.get_cell_atlas_coords(target_coords)
			var tile_level = tile_atlas_coords.y + 1
			
			# Ak nie je v tile_data, vytvor ho
			if target_coords not in tile_manager.tile_data:
				tile_manager.tile_data[target_coords] = {
					"level": tile_level,
					"hp": tile_manager.get_max_hp_for_tile(tile_level)
				}
			
			var tile_data = tile_manager.tile_data[target_coords]
			tile_data.hp += 1
			tile_data.level += 1
		
			# Aktualizuj damage overlay
			var max_hp = tile_manager.get_max_hp_for_tile(tile_data.level)
			var damage_val = tile_manager.calculate_tile_dmg_val(
				tile_data.hp, 
				max_hp, 
				damage_per_hit
			)
			tile_manager.dmgTilemap.set_cell(target_coords, tile_id, Vector2(damage_val, 0))
			tile_manager.effectTilemap.set_cell(target_coords, tile_id, Vector2i(1, 0))

func on_level_up():
	print("Shovel level up! Nový level: %d" % shovel_level)
	print(damage_per_hit)
	
func on_dead():
	set_physics_process(false)
	set_process(false)
	
	is_dead = true
	death_timer.start()

func _on_death_timer_timeout() -> void:
	var elapsed = HUD.get_elapsed_time()
	if name == "PlayerLeft":
		HUD.show_left_game_over(elapsed)
	else:
		HUD.show_right_game_over(elapsed)
		
	visible = false

func set_can_dig(value: bool) -> void:
	can_dig = value

func set_speed_multiplier(mult: float) -> void:
	SPEED = base_speed * mult

func set_gravity_multiplier(mult: float) -> void:
	JUMP_VELOCITY = base_jump_velocity * mult
