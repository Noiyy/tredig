extends Area2D

const DEFAULT_GROW_INTERVAL := 1.8

@export var tile_size := 16
@export var grow_interval_sec := DEFAULT_GROW_INTERVAL
@export var damage_interval_sec := 1.0
@export var damage_per_tick := 10

@onready var col_shape: CollisionShape2D = $CollisionShape2D
@onready var lava_rect: ColorRect = $ColorRect

var game_manager
var grow_timer: Timer
var damage_timer: Timer
var bodies_in_lava: Array = []   # hráči, ktorí sú aktuálne v láve

var last_interval_was_short: bool = false

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


func _on_grow_timeout() -> void:
	var rect_shape := col_shape.shape as RectangleShape2D

	# posuň Area2D o celý tile dole
	position.y += tile_size
	
	_set_next_grow_interval()

func _set_next_grow_interval() -> void:
	if last_interval_was_short:
		grow_timer.wait_time = DEFAULT_GROW_INTERVAL
		last_interval_was_short = false
	else:
		# 25% = normal, 45% = fast, 30% = fastest
		var rand := randf()
		if rand < 0.3:
			grow_timer.wait_time = 0.8
			last_interval_was_short = true
		elif rand < 0.25 + 0.45:
			grow_timer.wait_time = 1.25
			last_interval_was_short = false
		else:
			grow_timer.wait_time = DEFAULT_GROW_INTERVAL
			last_interval_was_short = false

	# Restart timer s novým wait_time (pre ďalšie timeouty)
	grow_timer.start()

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
		if is_instance_valid(body) and body is CharacterBody2D and not body.is_dead:
			game_manager.damage_player(body, damage_per_tick, true)
