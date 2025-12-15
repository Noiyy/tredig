extends Control

@onready var players: Array[Dictionary] = [
	{
		sub_viewport = %LeftSubViewport,
		camera = %LeftCamera2D,
		player = %Level/PlayerLeft,
	},
	{
		sub_viewport = %RightSubViewport,
		camera = %RightCamera2D,
		player = %Level/PlayerRight,
	},
]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	players[1].sub_viewport.world_2d = players[0].sub_viewport.world_2d
	
	for info in players:
		var remote_transform := RemoteTransform2D.new()
		remote_transform.remote_path = info.camera.get_path()
		info.player.add_child(remote_transform)
		
	#var world = $HBoxContainer/SubViewportContainer/SubViewport.find_world_2d()
	#$HBoxContainer/SubViewportContainer2/SubViewport.world_2d = world
	#pass
