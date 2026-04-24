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
var dur_damage_debuff = 0
 
var HUD
var game_manager
@onready var tile_manager = $TileManager
@onready var death_timer = $DeathTimer
@onready var shovel_highlight = $ShovelDirection/TileHighlight 
@onready var shovel_direction: Node2D = $ShovelDirection
@onready var shovel_area: Area2D = $ShovelDirection/Area2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var broken_shovel_indicator: TextureRect = $Control/BrokenShovelIndicator
@onready var buff_indicator: TextureRect = $Control/BuffIndicator
@onready var debuff_indicator: TextureRect = $Control/DebuffIndicator

var shovel_distance = 14
var last_dir := Vector2.DOWN

var facing_left: bool = false
var is_digging: bool = false
var dig_anim_time: float = 0.0
const DIG_ANIM_DURATION := 0.25
const DIG_REPEAT_INTERVAL := 0.032
var dig_repeat_timer: float = 0.0


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
		AudioManager.play("res://assets/sounds/jump.wav", "SFXLower")

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

func _process(_delta: float) -> void:
	if Input.is_action_pressed(controls.use):
		dig_repeat_timer -= _delta
		if dig_repeat_timer <= 0.0:
			_try_dig()
			dig_repeat_timer = DIG_REPEAT_INTERVAL
	else:
		dig_repeat_timer = 0.0

	var direction = Vector2.ZERO
		
	direction.x = Input.get_action_strength(controls.move_right) - Input.get_action_strength(controls.move_left)
	direction.y = Input.get_action_strength(controls.move_down) - Input.get_action_strength(controls.move_up)
	
	if direction != Vector2.ZERO:
		last_dir = direction.normalized()
		shovel_direction.rotation = last_dir.angle()

	var min_x := 0.0
	var max_x := 318.0
	if self.name == "PlayerRight":
		min_x = 322.0
		max_x = 640.0

	var area_pos = shovel_area.global_position
	if area_pos.x < global_position.x:
		facing_left = true
		animated_sprite.position.x = -6
	else:
		facing_left = false
		animated_sprite.position.x = 6
	animated_sprite.flip_h = facing_left

	# Keep highlight active even when idle, as long as the shovel area points at a tile.
	if area_pos.x < min_x or area_pos.x > max_x:
		shovel_highlight.visible = false
		return

	var tile_coords = tilemap.local_to_map(tilemap.to_local(area_pos))
	var tile_id = tilemap.get_cell_source_id(tile_coords)
	if tile_id == -1:
		shovel_highlight.visible = false
		return

	var tile_level = 4
	var tileset = tilemap.tile_set
	var tile_data_res = tilemap.get_cell_tile_data(tile_coords)
	if tileset.has_custom_data_layer_by_name("hardness") and tile_data_res:
		var level_layer = tileset.get_custom_data_layer_by_name("hardness")
		tile_level += int(tile_data_res.get_custom_data_by_layer_id(level_layer))

	var easy_max = shovel_level + 2
	var medium_max = shovel_level + 4
	var hard_max = shovel_level + 6

	if tile_level <= easy_max:
		shovel_highlight.modulate = Color.WHITE
	elif tile_level <= medium_max:
		shovel_highlight.modulate = Color.YELLOW
	elif tile_level <= hard_max:
		shovel_highlight.modulate = Color.ORANGE
	else:
		shovel_highlight.modulate = Color.RED
	shovel_highlight.modulate.a = 128.0 / 255.0 # alfa

	# Calculate tile center in world space.
	var tile_center_local = tilemap.map_to_local(tile_coords)
	var tile_center_global = tilemap.to_global(tile_center_local)
	shovel_highlight.global_position = tile_center_global

	# Rotation for diagonal tiles.
	if abs(last_dir.x) > 0.5 and abs(last_dir.y) > 0.5:
		if (last_dir.x > 0 and last_dir.y > 0) or (last_dir.x < 0 and last_dir.y < 0):
			shovel_highlight.rotation_degrees = 45
		else:
			shovel_highlight.rotation_degrees = -45
	else:
		shovel_highlight.rotation_degrees = 0

	shovel_highlight.visible = true

func _try_dig() -> void:
	if not can_dig:
		AudioManager.play("res://assets/sounds/disabled.wav", "SFXLower", false)
		return
	# debuffni hrača automaticky keď mu dojde durability
	# obnovenie je v levelup-e
	if durability <= 0 and dur_damage_debuff == 0:
		set_speed_multiplier(0.5)  # 50 % rýchlosti
		set_gravity_multiplier(0.9)
		
		var took = clamp(damage_per_hit - 1, 1, 3)
		if damage_per_hit == 1 && took == 1:
			took = 0
		dur_damage_debuff = took
		damage_per_hit = maxi(damage_per_hit - took, 1)
		game_manager.sync_stat_from_player(name, "damage_per_hit", damage_per_hit)
	
	var anim := "dig_down"
	if abs(last_dir.y) > abs(last_dir.x):
		anim = "dig_up" if last_dir.y < 0 else "dig_down"
	else:
		anim = "dig_horizontal"

	is_digging = true
	dig_anim_time = DIG_ANIM_DURATION
	animated_sprite.flip_h = facing_left
	animated_sprite.play(anim)
	tile_manager.damage_tile(self)
			
func add_exp(amount: int):
	game_manager.add_player_exp(self, amount)
	
func sync_stats_from_manager(data: Dictionary):
	experience = data.experience
	shovel_level = data.shovel_level
	damage_per_hit = maxi(data.damage_per_hit, 1)
	durability = data.durability
	hp = data.hp
	_update_status_indicators()

func apply_stat_change(key: String, delta: float) -> void:
	match key:
		"damage":
			damage_per_hit = maxi(damage_per_hit + int(delta), 1)


func refresh_status_indicators() -> void:
	_update_status_indicators()


func _update_status_indicators() -> void:
	if not is_instance_valid(broken_shovel_indicator):
		return
	var bonuses: Array = []
	if game_manager != null and game_manager.players.has(name):
		bonuses = game_manager.players[name].active_bonuses
	var bt = game_manager.BonusType
	broken_shovel_indicator.visible = durability <= 0
	buff_indicator.visible = bonuses.has(bt.SSHOVEL) or bonuses.has(bt.SHARPNESS)
	debuff_indicator.visible = bonuses.has(bt.DULLNESS) or bonuses.has(bt.OVERLOAD)

func apply_sabotage_effect() -> void:
	AudioManager.play("res://assets/sounds/sabotage.wav")
	var t := get_tree().create_timer(1.0)
	t.timeout.connect(func():
		AudioManager.play("res://assets/sounds/laugh.ogg", "SFX", true, true)
	)
	
	var tile_size = game_manager.get_tile_size()
	var tileset = tile_manager.tilemap.tile_set
	
	var start_x := 0 if name == "PlayerLeft" else int(320.0 / float(tile_size))
	var start_y = int(global_position.y / float(tile_size)) + 1
	
	for y_offset in 3:
		var target_y = start_y + y_offset
		# Sekvenčne spracuj bloky s oneskorenim
		for x_offset in 20:
			_apply_sabotage_to_tile(Vector2i(start_x + x_offset, target_y), tileset)
			await get_tree().create_timer(0.0075).timeout

func _apply_sabotage_to_tile(target_coords: Vector2i, tileset: TileSet) -> void:
	var tile_data_res: TileData = tile_manager.tilemap.get_cell_tile_data(target_coords)
	var tile_id = tile_manager.tilemap.get_cell_source_id(target_coords)
	if tile_id == -1:
		return
	
	var tile_level := 4
	if tileset.has_custom_data_layer_by_name("hardness") and tile_data_res:
		var hardness_layer = tileset.get_custom_data_layer_by_name("hardness")
		tile_level += int(tile_data_res.get_custom_data_by_layer_id(hardness_layer))
	
	if target_coords not in tile_manager.tile_data:
		tile_manager.tile_data[target_coords] = {"level": tile_level, "hp": tile_level}
	
	var td: Dictionary = tile_manager.tile_data[target_coords]
	td.hp += 1
	td.level += 1
	
	var damage_val = tile_manager.calculate_tile_dmg_val(td.hp, tile_level, damage_per_hit)
	tile_manager.dmgTilemap.set_cell(target_coords, tile_id, Vector2(damage_val, 0))
	tile_manager.effectTilemap.set_cell(target_coords, tile_id, Vector2i(1, 0))


func on_level_up():
	print("Shovel level up! Nový level: %d" % shovel_level)
	print(damage_per_hit)
	if durability <= 0 and dur_damage_debuff > 0:
		set_speed_multiplier(1)
		set_gravity_multiplier(1)
		
		damage_per_hit += dur_damage_debuff
		dur_damage_debuff = 0 
		game_manager.sync_stat_from_player(name, "damage_per_hit", damage_per_hit)
	
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
		
	AudioManager.play("res://assets/sounds/death2.wav")
		
	visible = false

func set_can_dig(value: bool) -> void:
	can_dig = value

func set_speed_multiplier(mult: float) -> void:
	SPEED = base_speed * mult

func set_gravity_multiplier(mult: float) -> void:
	JUMP_VELOCITY = base_jump_velocity * mult
