extends Node2D
class_name MagicPulseEffect

var effect_radius: float = 64.0


func configure(radius: float) -> void:
	effect_radius = maxf(radius, 1.0)
	scale = Vector2(0.15, 0.15)
	modulate = Color(1.0, 1.0, 1.0, 0.9)
	queue_redraw()
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, 0.32).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.38).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)


func _draw() -> void:
	draw_circle(Vector2.ZERO, effect_radius, Color(0.38, 0.12, 0.85, 0.18))
	draw_arc(
		Vector2.ZERO,
		effect_radius,
		0.0,
		TAU,
		64,
		Color(0.72, 0.4, 1.0, 0.9),
		4.0,
		true
	)
	draw_arc(
		Vector2.ZERO,
		effect_radius * 0.62,
		0.0,
		TAU,
		48,
		Color(0.35, 0.82, 1.0, 0.75),
		2.0,
		true
	)

