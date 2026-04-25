extends TextureProgressBar

var tween: Tween

func _ready() -> void:
	step = 0.1

func cancel_value_tween() -> void:
	if tween and tween.is_valid():
		tween.kill()
	tween = null


func set_value_animated(target: float, duration: float = 0.25) -> void:
	cancel_value_tween()
	tween = get_tree().create_tween()
	tween.tween_property(self, "value", target, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
