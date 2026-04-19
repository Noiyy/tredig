extends AudioStreamPlayer

const STREAM_NORMAL_RES := preload("res://assets/music/Mining Town (Loop).wav")
const STREAM_SPED_RES := preload("res://assets/music/Mining Town (Loop)-sped_up.wav")

var _stream_normal: AudioStreamWAV
var _stream_sped: AudioStreamWAV

var _using_sped_up := false

func _ready() -> void:
	_stream_normal = STREAM_NORMAL_RES
	_stream_sped = STREAM_SPED_RES
	stream = _stream_normal
	_using_sped_up = false
	finished.connect(_on_finished)
	if not playing:
		play()


func _on_finished() -> void:
	play(0.0)


## false = main menu (normálna verzia), true = hra (sped up). Pri zmene sa zachová „miesto" v slučke.
func set_gameplay_music(enabled: bool) -> void:
	if enabled == _using_sped_up:
		return
	var pos := get_playback_position() if playing else 0.0
	stop()
	if enabled:
		stream = _stream_sped
		play(_normal_to_sped(pos))
	else:
		stream = _stream_normal
		play(_sped_to_normal(pos))
	_using_sped_up = enabled


func _normal_to_sped(pos_n: float) -> float:
	var len_n := _stream_normal.get_length()
	var len_s := _stream_sped.get_length()
	var p := fposmod(pos_n, len_n)
	return fposmod(p * len_s / len_n, len_s)


func _sped_to_normal(pos_s: float) -> float:
	var len_n := _stream_normal.get_length()
	var len_s := _stream_sped.get_length()
	var p := fposmod(pos_s, len_s)
	return fposmod(p * len_n / len_s, len_n)
