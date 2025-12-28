extends RigidBody2D

@onready var pickup_area: Area2D = $Area2D
@onready var color_rect: ColorRect = $ColorRect

@export var exp_amount: int = 10
@export var lifetime: float = 1.5
@export var terrain_type: int = 2

var target_player: CharacterBody2D

func _ready() -> void:
	# krátky život – po 1.5s sa sám zničí
	get_tree().create_timer(lifetime).timeout.connect(_on_timeout)
	pickup_area.body_entered.connect(_on_area_body_entered)
	
	# farba podľa terrain_type
	set_color_by_terrain(terrain_type)

	# trochu horizontálneho rozptylu pri spawne
	linear_velocity = Vector2(randf_range(-8.0, 8.0), 0.0)


func set_color_by_terrain(type: int) -> void:
	terrain_type = type
	match type:
		2:  # IRON
			color_rect.color = Color("#dedede")
		3:  # GOLD
			color_rect.color = Color("#ffd500")
		4:  # EMERALD
			color_rect.color = Color("#75a743")
		5:  # RUBY
			color_rect.color = Color("#a53030")
		6:  # DIAMOND
			color_rect.color = Color("#a4dddb")


func _on_timeout() -> void:
	if is_instance_valid(target_player):
		target_player.add_exp(exp_amount)
	queue_free()
	
func _on_area_body_entered(body: Node) -> void:
	if body is CharacterBody2D and body == target_player:
		_on_timeout()
