extends Node2D
class_name GolemAttackEffect

@export var radius_pixels: float = 64.0
@export var effect_color: Color = Color(1.0, 0.25, 0.08, 0.55)
@export var duration: float = 0.8

var _elapsed: float = 0.0


func configure(radius: float, color: Color, lifetime: float) -> void:
	radius_pixels = radius
	effect_color = color
	duration = maxf(lifetime, 0.05)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	if _elapsed >= duration:
		queue_free()


func _draw() -> void:
	var progress: float = clampf(_elapsed / maxf(duration, 0.05), 0.0, 1.0)
	var pulse_radius: float = radius_pixels * (0.85 + progress * 0.15)
	var color: Color = effect_color
	color.a *= 1.0 - progress * 0.65
	draw_circle(Vector2.ZERO, pulse_radius, color)
	draw_arc(Vector2.ZERO, pulse_radius, 0.0, TAU, 48, Color(color.r, color.g, color.b, 0.95), 3.0)
