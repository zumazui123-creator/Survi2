extends Node2D
class_name ProgramPuzzleSwitch

enum VisualState {
	IDLE,
	CORRECT,
	WRONG,
	COMPLETED,
}

var switch_number: int = 0
var visual_state: VisualState = VisualState.IDLE
var _pulse_time: float = 0.0
var _reset_remaining: float = 0.0
var _number_label: Label


func _ready() -> void:
	_number_label = Label.new()
	_number_label.position = Vector2(-22.0, -58.0)
	_number_label.size = Vector2(44.0, 36.0)
	_number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_number_label.add_theme_font_size_override("font_size", 24)
	_number_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 1.0))
	_number_label.add_theme_constant_override("outline_size", 6)
	_number_label.visible = false
	add_child(_number_label)
	queue_redraw()


func configure(number: int) -> void:
	switch_number = number
	if is_instance_valid(_number_label):
		_number_label.text = str(number)


func reveal(is_correct: bool) -> void:
	visual_state = VisualState.CORRECT if is_correct else VisualState.WRONG
	_number_label.text = str(switch_number)
	_number_label.visible = true
	_number_label.add_theme_color_override(
		"font_color",
		Color(0.45, 1.0, 0.55, 1.0) if is_correct \
		else Color(1.0, 0.3, 0.25, 1.0)
	)
	if not is_correct:
		_reset_remaining = 1.2
	queue_redraw()


func reset_after(seconds: float) -> void:
	_reset_remaining = maxf(seconds, 0.0)


func reset_visual() -> void:
	visual_state = VisualState.IDLE
	_reset_remaining = 0.0
	if is_instance_valid(_number_label):
		_number_label.visible = false
	queue_redraw()


func mark_completed() -> void:
	visual_state = VisualState.COMPLETED
	_reset_remaining = 0.0
	_number_label.text = str(switch_number)
	_number_label.visible = true
	_number_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25, 1.0))
	queue_redraw()


func _process(delta: float) -> void:
	_pulse_time += delta
	if _reset_remaining > 0.0:
		_reset_remaining -= delta
		if _reset_remaining <= 0.0:
			reset_visual()
	queue_redraw()


func _draw() -> void:
	var pulse: float = 0.72 + sin(_pulse_time * 3.0) * 0.12
	var color: Color = Color(0.88, 0.96, 1.0, pulse)
	match visual_state:
		VisualState.CORRECT:
			color = Color(0.18, 1.0, 0.4, 0.95)
		VisualState.WRONG:
			color = Color(1.0, 0.16, 0.12, 0.95)
		VisualState.COMPLETED:
			color = Color(1.0, 0.72, 0.1, 0.98)
	var half_size: float = float(Constants.TILE_SIZE) * 0.36
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, -half_size),
		Vector2(half_size, 0.0),
		Vector2(0.0, half_size),
		Vector2(-half_size, 0.0),
	])
	draw_circle(Vector2.ZERO, half_size * 1.28, Color(color.r, color.g, color.b, 0.12))
	draw_colored_polygon(points, Color(0.12, 0.16, 0.2, 0.94))
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), color, 5.0)
	draw_circle(Vector2.ZERO, half_size * 0.34, color)
	draw_line(Vector2(-half_size * 0.42, 0.0), Vector2(half_size * 0.42, 0.0), color, 3.0)
	draw_line(Vector2(0.0, -half_size * 0.42), Vector2(0.0, half_size * 0.42), color, 3.0)
