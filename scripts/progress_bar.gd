extends ProgressBar

var tween: Tween

func _ready() -> void:
	step = 0.1

func set_value_animated(target: float, duration: float = 0.25) -> void:
	if tween and tween.is_valid():
		tween.kill()  # zruš starý tween, ak ešte beží
	tween = get_tree().create_tween()
	tween.tween_property(self, "value", target, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
