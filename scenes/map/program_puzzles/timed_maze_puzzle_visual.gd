extends Node2D
class_name TimedMazePuzzleVisual

var wall_offsets: Array[Vector2i] = []
var start_offset: Vector2i
var goal_offset: Vector2i
var start_active: bool = false
var completed: bool = false
var _pulse_time: float = 0.0


func configure(
		origin_tile: Vector2i,
		wall_tiles: Array[Vector2i],
		start_tile: Vector2i,
		goal_tile: Vector2i
	) -> void:
	wall_offsets.clear()
	for tile: Vector2i in wall_tiles:
		wall_offsets.append(tile - origin_tile)
	start_offset = start_tile - origin_tile
	goal_offset = goal_tile - origin_tile
	queue_redraw()


func set_start_active(value: bool) -> void:
	start_active = value
	queue_redraw()


func mark_completed() -> void:
	completed = true
	start_active = false
	queue_redraw()


func _process(delta: float) -> void:
	_pulse_time += delta
	queue_redraw()


func _draw() -> void:
	var tile_size: float = float(Constants.TILE_SIZE)
	var wall_size: Vector2 = Vector2.ONE * tile_size * 0.92
	for offset: Vector2i in wall_offsets:
		var center: Vector2 = Vector2(offset) * tile_size
		var wall_rect: Rect2 = Rect2(center - wall_size * 0.5, wall_size)
		draw_rect(wall_rect, Color(0.12, 0.13, 0.17, 0.98), true)
		draw_rect(wall_rect.grow(-5.0), Color(0.25, 0.27, 0.34, 0.96), true)
		draw_line(
			wall_rect.position + Vector2(6.0, 9.0),
			wall_rect.end - Vector2(8.0, 12.0),
			Color(0.38, 0.4, 0.48, 0.65),
			2.0
		)
	_draw_start(Vector2(start_offset) * tile_size, tile_size)
	_draw_goal(Vector2(goal_offset) * tile_size, tile_size)


func _draw_start(center: Vector2, tile_size: float) -> void:
	var pulse: float = 0.78 + sin(_pulse_time * 4.0) * 0.16
	var color: Color = Color(0.35, 1.0, 0.82, 1.0) if start_active \
		else Color(1.0, 1.0, 1.0, pulse)
	draw_circle(center, tile_size * 0.44, Color(color.r, color.g, color.b, 0.18))
	draw_rect(
		Rect2(center - Vector2.ONE * tile_size * 0.34, Vector2.ONE * tile_size * 0.68),
		Color(0.88, 0.94, 1.0, 0.92),
		true
	)
	draw_arc(center, tile_size * 0.31, 0.0, TAU, 24, color, 4.0)
	draw_circle(center, tile_size * 0.1, color)


func _draw_goal(center: Vector2, tile_size: float) -> void:
	var pulse: float = 0.7 + sin(_pulse_time * 3.2) * 0.18
	var outline: Color = Color(1.0, 0.76, 0.18, 1.0) if completed \
		else Color(0.58, 0.42, 1.0, pulse)
	draw_circle(center, tile_size * 0.45, Color(outline.r, outline.g, outline.b, 0.16))
	draw_rect(
		Rect2(center - Vector2.ONE * tile_size * 0.35, Vector2.ONE * tile_size * 0.7),
		Color(0.015, 0.018, 0.03, 0.98),
		true
	)
	draw_arc(center, tile_size * 0.32, 0.0, TAU, 24, outline, 4.0)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0.0, -tile_size * 0.18),
		center + Vector2(tile_size * 0.18, 0.0),
		center + Vector2(0.0, tile_size * 0.18),
		center + Vector2(-tile_size * 0.18, 0.0),
	]), outline)
