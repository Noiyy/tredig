extends CharacterBody2D

const SPEED = 200.0
const JUMP_VELOCITY = -200.0

var world_left_x = 0
var world_right_x = 0

@export var controls: PlayerControls = null
@export var tilemap: TileMapLayer

@export var damage_per_hit = 1
@export var shovel_level = 1
@export var experience = 0
 
var game_manager
@onready var shovel_highlight = $ShovelDirection/TileHighlight 
var shovel_distance = 14

func _ready():
	if controls == null:
		set_physics_process(false)
	
	game_manager = get_tree().root.get_node("Main/GameManager")
	game_manager.register_player(self)
	
	var x_boundaries = game_manager.get_world_x_boundaries();
	world_left_x = x_boundaries[0];
	world_right_x = x_boundaries[1];

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

	move_and_slide()
	global_position.x = clamp(global_position.x, world_left_x, world_right_x)

func _process(delta: float) -> void:
	var direction = Vector2.ZERO
		
	direction.x = Input.get_action_strength(controls.move_right) - Input.get_action_strength(controls.move_left)
	direction.y = Input.get_action_strength(controls.move_down) - Input.get_action_strength(controls.move_up)
	
	if direction != Vector2.ZERO:
		direction = direction.normalized()
		var distance = shovel_distance
		
		#$"ShovelDirection/Area2D".position = direction * distance
		$ShovelDirection.rotation = direction.angle()
		
		var min_x := 0.0
		var max_x := 318.0
		if self.name == "PlayerRight":
			min_x = 322.0
			max_x = 640.0
	 	# Snap shovel highlight to the nearest tile, show highlight if colliding with tile
		var area_pos = $ShovelDirection/Area2D.global_position
		#area_pos.x = clamp(area_pos.x, min_x, max_x)
		if area_pos.x < min_x or area_pos.x > max_x:
			shovel_highlight.visible = false
			return
		
		var tile_coords = tilemap.local_to_map(tilemap.to_local(area_pos))
		var tile_id = tilemap.get_cell_source_id(tile_coords)

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
		$TileManager.damage_tile(self)
			
func add_exp(amount: int):
	game_manager.add_player_exp(self, amount)
	
func sync_stats_from_manager(data: Dictionary):
	experience = data.experience
	shovel_level = data.shovel_level
	damage_per_hit = data.damage_per_hit

func on_level_up():
	print("Shovel level up! Nový level: %d" % shovel_level)
	print(damage_per_hit)
