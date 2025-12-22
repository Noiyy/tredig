extends RigidBody2D

@onready var pickup_area: Area2D = $Area2D

@export var exp_amount: int = 10
@export var lifetime: float = 1.0

var target_player: CharacterBody2D

func _ready() -> void:
	# krátky život – po 1s sa sám zničí
	get_tree().create_timer(lifetime).timeout.connect(_on_timeout)
	pickup_area.body_entered.connect(_on_area_body_entered)

	# trochu horizontálneho rozptylu pri spawne
	linear_velocity = Vector2(randf_range(-8.0, 8.0), 0.0)


func _on_timeout() -> void:
	if is_instance_valid(target_player):
		target_player.add_exp(exp_amount)
	queue_free()
	
func _on_area_body_entered(body: Node) -> void:
	if body is CharacterBody2D and body == target_player:
		_on_timeout()
