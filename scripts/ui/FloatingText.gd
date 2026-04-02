extends Label

@export var float_speed: float = 50.0
@export var duration: float = 1.5

func setup(text_content: String, color: Color) -> void:
	text = text_content
	modulate = color
	
	# Create a tween for animation
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 100, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
