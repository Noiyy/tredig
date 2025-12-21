extends Area2D

@export var tile_size := 16
@export var grow_interval_sec := 3.0
@export var damage_interval_sec := 1.0
@export var damage_per_tick := 10

@onready var col_shape: CollisionShape2D = $CollisionShape2D
@onready var lava_rect: ColorRect = $ColorRect

var game_manager
var grow_timer: Timer
var damage_timer: Timer
var bodies_in_lava: Array = []   # hráči, ktorí sú aktuálne v láve

func _ready() -> void:
	game_manager = get_tree().root.get_node("Main/GameManager")
	
	# timer na posúvanie lávy
	grow_timer = Timer.new()
	grow_timer.wait_time = grow_interval_sec
	grow_timer.autostart = true
	grow_timer.one_shot = false
	add_child(grow_timer)
	grow_timer.timeout.connect(_on_grow_timeout)

	# timer na damage každú sekundu
	damage_timer = Timer.new()
	damage_timer.wait_time = damage_interval_sec
	damage_timer.autostart = true
	damage_timer.one_shot = false
	add_child(damage_timer)
	damage_timer.timeout.connect(_on_damage_timeout)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	var rect_shape := col_shape.shape as RectangleShape2D
	rect_shape.size.y = tile_size
	lava_rect.size = rect_shape.size


func _on_grow_timeout() -> void:
	var rect_shape := col_shape.shape as RectangleShape2D

	# posuň Area2D o celý tile dole
	position.y += tile_size

	rect_shape.size.y += tile_size
	col_shape.shape = rect_shape

	lava_rect.size = rect_shape.size
	lava_rect.position.x = 0
	lava_rect.position.y = -rect_shape.size.y * 0.5

func stop_growing() -> void:
	grow_timer.stop()

func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D and body.name.begins_with("Player"):
		if not bodies_in_lava.has(body):
			bodies_in_lava.append(body)

func _on_body_exited(body: Node) -> void:
	bodies_in_lava.erase(body)


func _on_damage_timeout() -> void:
	for body in bodies_in_lava:
		if is_instance_valid(body):
			game_manager.damage_player(body, damage_per_tick)
