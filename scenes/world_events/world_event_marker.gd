extends Node2D
class_name WorldEventMarker

@export var event_style: StringName:
	set(value):
		event_style = value
		queue_redraw()
@export var marker_color: Color = Color(1.0, 0.7, 0.2, 1.0):
	set(value):
		marker_color = value
		queue_redraw()
		_update_light()
@export var glowing: bool = false:
	set(value):
		glowing = value
		set_process(glowing)
		_update_light()

@onready var glow_light: PointLight2D = $GlowLight
var _pulse_time: float = 0.0


func _ready() -> void:
	set_process(glowing)
	_update_light()
	queue_redraw()


func configure(style: StringName, color: Color, should_glow: bool) -> void:
	event_style = style
	marker_color = color
	glowing = should_glow


func _process(delta: float) -> void:
	if not glowing:
		return
	_pulse_time += delta
	var pulse: float = (sin(_pulse_time * 3.0) + 1.0) * 0.5
	if is_instance_valid(glow_light):
		glow_light.energy = lerpf(0.75, 1.45, pulse)
	rotation += delta * 0.22


func _draw() -> void:
	match event_style:
		&"resident_attack":
			_draw_alert(Color(1.0, 0.78, 0.12, 0.95))
		&"merchant_ambush":
			_draw_ambush()
		&"escaped_pig":
			_draw_alert(Color(1.0, 0.55, 0.7, 0.92))
		&"meteor":
			_draw_meteor()
		&"village_siege":
			_draw_siege()
		&"caravan":
			_draw_caravan()
		&"portal":
			_draw_portal()
		_:
			draw_circle(Vector2.ZERO, 18.0, marker_color)


func _draw_alert(color: Color) -> void:
	draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 32, color, 4.0)
	draw_line(Vector2(0, -15), Vector2(0, 7), color, 6.0)
	draw_circle(Vector2(0, 16), 3.5, color)


func _draw_ambush() -> void:
	draw_circle(Vector2.ZERO, 25.0, Color(0.45, 0.12, 0.08, 0.35))
	draw_line(Vector2(-18, -18), Vector2(18, 18), marker_color, 6.0)
	draw_line(Vector2(18, -18), Vector2(-18, 18), marker_color, 6.0)


func _draw_meteor() -> void:
	draw_circle(Vector2.ZERO, 31.0, Color(0.12, 0.08, 0.06, 0.78))
	draw_circle(Vector2.ZERO, 18.0, Color(0.55, 0.2, 0.05, 0.96))
	draw_circle(Vector2(-5, -6), 8.0, marker_color)


func _draw_siege() -> void:
	draw_arc(Vector2.ZERO, 34.0, 0.0, TAU, 36, Color(0.9, 0.12, 0.08, 0.85), 6.0)
	for direction: Vector2 in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		draw_colored_polygon(PackedVector2Array([
			direction * 20.0,
			direction.rotated(0.65) * 34.0,
			direction.rotated(-0.65) * 34.0,
		]), marker_color)


func _draw_caravan() -> void:
	draw_rect(Rect2(Vector2(-28, -15), Vector2(56, 28)), marker_color, true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-32, -15), Vector2.ZERO + Vector2(0, -34), Vector2(32, -15),
	]), Color(marker_color.r * 0.75, marker_color.g * 0.75, marker_color.b * 0.75, 1.0))
	draw_circle(Vector2(-18, 18), 8.0, Color(0.16, 0.1, 0.05, 1.0))
	draw_circle(Vector2(18, 18), 8.0, Color(0.16, 0.1, 0.05, 1.0))


func _draw_portal() -> void:
	draw_circle(Vector2.ZERO, 35.0, Color(marker_color.r, marker_color.g, marker_color.b, 0.18))
	draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 48, marker_color, 7.0)
	draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 40, Color(0.8, 0.45, 1.0, 0.95), 4.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -13), Vector2(10, 0), Vector2(0, 13), Vector2(-10, 0),
	]), Color(0.92, 0.72, 1.0, 0.92))


func _update_light() -> void:
	if not is_node_ready() or not is_instance_valid(glow_light):
		return
	glow_light.enabled = glowing
	glow_light.color = marker_color
	glow_light.energy = 1.0 if glowing else 0.0
