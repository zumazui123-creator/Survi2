extends Node2D
class_name PlayerComboEffects

const DEFAULT_EFFECT_DURATION: float = 0.42
const TILE_DISTANCE: float = float(Constants.TILE_SIZE)

var _effect_id: StringName = &""
var _directions: Array[Vector2i] = []
var _elapsed: float = 0.0
var _duration: float = DEFAULT_EFFECT_DURATION


func _ready() -> void:
	set_process(false)


func play_effect(effect_id: StringName, directions: Array[Vector2i], duration: float) -> void:
	_effect_id = effect_id
	_directions = directions.duplicate()
	_elapsed = 0.0
	_duration = maxf(duration, 0.05)
	visible = true
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _duration:
		visible = false
		set_process(false)
		return
	queue_redraw()


func _draw() -> void:
	var progress: float = clampf(_elapsed / _duration, 0.0, 1.0)
	match _effect_id:
		&"sound_wave":
			_draw_sound_wave(progress)
		&"whirlwind":
			_draw_whirlwind(progress)
		&"earthquake":
			_draw_earthquake(progress)
		&"double_strike":
			_draw_double_strike(progress)
		&"cross_explosion":
			_draw_cross_explosion(progress)


func _draw_sound_wave(progress: float) -> void:
	var color: Color = Color(0.35, 0.9, 1.0, 1.0 - progress)
	for direction: Vector2i in _directions:
		var normal: Vector2 = Vector2(direction).normalized()
		var distance: float = lerpf(4.0, TILE_DISTANCE, progress)
		var center: Vector2 = normal * distance
		draw_line(Vector2.ZERO, center, color, 2.0, true)
		draw_arc(center, 6.0 + progress * 9.0, 0.0, TAU, 16, color, 2.0, true)


func _draw_whirlwind(progress: float) -> void:
	var color: Color = Color(0.82, 0.45, 1.0, 1.0 - progress)
	var radius: float = lerpf(8.0, TILE_DISTANCE, progress)
	var rotation: float = progress * TAU * 2.0
	draw_arc(Vector2.ZERO, radius, rotation, rotation + TAU * 0.8, 28, color, 3.0, true)
	draw_arc(Vector2.ZERO, radius * 0.55, -rotation, -rotation + TAU * 0.8, 22, color, 2.0, true)
	for direction: Vector2i in _directions:
		draw_line(Vector2.ZERO, Vector2(direction) * TILE_DISTANCE, color, 1.5, true)


func _draw_earthquake(progress: float) -> void:
	var color: Color = Color(0.78, 0.48, 0.19, 1.0 - progress)
	for direction: Vector2i in _directions:
		var normal: Vector2 = Vector2(direction).normalized()
		var tangent: Vector2 = Vector2(-normal.y, normal.x)
		var distance: float = lerpf(6.0, TILE_DISTANCE, progress)
		var center: Vector2 = normal * distance
		draw_line(center - tangent * 10.0, center + tangent * 10.0, color, 3.0, true)
		draw_circle(center, 4.0 + progress * 5.0, Color(color, color.a * 0.3))


func _draw_double_strike(progress: float) -> void:
	var color: Color = Color(1.0, 0.86, 0.35, 1.0 - progress)
	for direction: Vector2i in _directions:
		var normal: Vector2 = Vector2(direction).normalized()
		var tangent: Vector2 = Vector2(-normal.y, normal.x)
		var slash_count: int = 2 if direction == Vector2i.LEFT else 1
		for slash_index: int in range(slash_count):
			var offset: float = (float(slash_index) - 0.5) * 8.0
			var center: Vector2 = normal * (TILE_DISTANCE * 0.65) + tangent * offset
			draw_line(center - tangent * 10.0, center + tangent * 10.0 + normal * 6.0, color, 3.0, true)


func _draw_cross_explosion(progress: float) -> void:
	var color: Color = Color(1.0, 0.32, 0.16, 1.0 - progress)
	var radius: float = lerpf(6.0, TILE_DISTANCE, progress)
	draw_circle(Vector2.ZERO, radius * 0.28, Color(color, color.a * 0.45))
	for direction: Vector2i in _directions:
		var end: Vector2 = Vector2(direction) * radius
		draw_line(Vector2.ZERO, end, color, 4.0, true)
		draw_circle(end, 4.0 + progress * 4.0, color)
