extends Node
var num_players = 8
var available = []
var queue = []
var cooldowns: Dictionary = {}  # {sound_path: last_time}
var cooldown_time: float = 0.1  # Sekundy medzi play rovnakého zvuku
var max_instances: int = 5  # Max súčasných pre rovnaký zvuk
var playing_sounds: Dictionary = {}  # {sound_path: počet hrajúcich}

func _ready():
	for i in num_players:
		var player = AudioStreamPlayer.new()
		player.bus = &"SFX"
		player.pitch_scale = randf_range(0.85, 1.15)
		
		add_child(player)
		available.append(player)
		player.finished.connect(_on_stream_finished.bind(player))

func play(sound_path: String, bus_name: String = "SFX", allow_overlap: bool = true):
	var now = Time.get_unix_time_from_system()
	if not allow_overlap and playing_sounds.has(sound_path) and playing_sounds[sound_path] >= max_instances:
		return  # Blokuj spam
	if cooldowns.has(sound_path) and (now - cooldowns[sound_path]) < cooldown_time:
		return  # Cooldown
		
	cooldowns[sound_path] = now
	queue.append([sound_path, bus_name])
	_process(0)  # Spusti hneď

func _process(_delta):
	if not queue.is_empty() and not available.is_empty():
		var sound_data = queue.pop_front()
		var player = available[0]
		player.stream = load(sound_data[0])
		if sound_data.size() > 1:
			player.set_bus(sound_data[1])
			
		playing_sounds[sound_data[0]] = playing_sounds.get(sound_data[0], 0) + 1
		
		player.play()
		available.pop_front()

func _on_stream_finished(stream):
	# Nájdi sound_path podľa streamu (približne, alebo pridaj mapovanie)
	for path in playing_sounds:
		if playing_sounds[path] > 0:
			playing_sounds[path] -= 1
			if playing_sounds[path] == 0:
				playing_sounds.erase(path)
	available.append(stream)
