extends StaticBody2D

var game_manager
@onready var win_area: Area2D = $Area2D

func _ready():
	game_manager = get_tree().root.get_node("Main/GameManager")
	
	win_area.body_entered.connect(_on_player_entered)
	win_area.monitoring = true
	win_area.monitorable = true

func _on_player_entered(body):
	if body is CharacterBody2D and (body.name == "PlayerLeft" or body.name == "PlayerRight"):
		body.set_physics_process(false)
		body.set_process(false)
		body.animated_sprite.stop();
		
		game_manager.on_game_won(body.name)
