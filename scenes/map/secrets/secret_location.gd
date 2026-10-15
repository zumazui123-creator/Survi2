extends Node2D
class_name SecretLocation

var plan_id: int = -1
var secret_id: StringName = &""
var location_type: StringName = &"secret"
var display_name: String = "Geheimer Ort"
var marker_color: Color = Color(0.35, 0.9, 0.95, 1.0)
var _revealed: bool = false


func configure(plan: SecretLocationPlan, definition: SecretLocationDefinition) -> void:
	plan_id = plan.plan_id
	secret_id = plan.secret_id
	location_type = definition.location_type
	display_name = definition.display_name
	marker_color = definition.map_color
	visible = false
	queue_redraw()


func reveal() -> void:
	if _revealed:
		return
	_revealed = true
	visible = true
	queue_redraw()


func is_revealed() -> bool:
	return _revealed


func _draw() -> void:
	if not _revealed:
		return
	var radius: float = float(Constants.TILE_SIZE) * 0.42
	draw_circle(Vector2.ZERO, radius, Color(marker_color, 0.22))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, marker_color, 2.0, true)
	match location_type:
		&"cave", &"underground":
			draw_arc(Vector2.ZERO, radius * 0.65, PI, TAU, 16, marker_color, 3.0, true)
			draw_line(Vector2(-radius * 0.65, 0.0), Vector2(radius * 0.65, 0.0), marker_color, 3.0)
		&"teleporter":
			draw_circle(Vector2.ZERO, radius * 0.55, Color(marker_color, 0.18))
			draw_arc(Vector2.ZERO, radius * 0.55, 0.0, TAU, 16, marker_color, 2.0, true)
		&"island":
			draw_circle(Vector2.ZERO, radius * 0.55, marker_color.darkened(0.25))
		&"jump":
			var arrow: PackedVector2Array = PackedVector2Array([
				Vector2(-radius * 0.5, radius * 0.25),
				Vector2(radius * 0.15, radius * 0.25),
				Vector2(radius * 0.15, radius * 0.55),
				Vector2(radius * 0.7, 0.0),
				Vector2(radius * 0.15, -radius * 0.55),
				Vector2(radius * 0.15, -radius * 0.25),
				Vector2(-radius * 0.5, -radius * 0.25),
			])
			draw_colored_polygon(arrow, marker_color)
		_:
			draw_rect(Rect2(Vector2(-radius * 0.45, -radius * 0.45), Vector2.ONE * radius * 0.9), marker_color, false, 2.0)
