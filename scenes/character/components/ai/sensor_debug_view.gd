extends Node2D
class_name SensorDebugView

@export var fill_color: Color = Color(0.15, 0.72, 1.0, 0.07)
@export var grid_color: Color = Color(0.25, 0.82, 1.0, 0.16)
@export var border_color: Color = Color(0.25, 0.9, 1.0, 0.85)

var radius_tiles: int = 10


func set_visualization_enabled(value: bool) -> void:
	visible = value
	queue_redraw()


func set_radius(value: int) -> void:
	radius_tiles = maxi(value, 1)
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var tile_size: float = float(Constants.TILE_SIZE)
	var half_tile: Vector2 = Vector2.ONE * tile_size * 0.5
	for y in range(-radius_tiles, radius_tiles + 1):
		for x in range(-radius_tiles, radius_tiles + 1):
			if absi(x) + absi(y) > radius_tiles:
				continue
			var center: Vector2 = Vector2(x, y) * tile_size
			var tile_rect: Rect2 = Rect2(center - half_tile, Vector2.ONE * tile_size)
			draw_rect(tile_rect, fill_color, true)
			draw_rect(tile_rect, grid_color, false, 1.0)

	var extent: float = (float(radius_tiles) + 0.5) * tile_size
	var outline: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, -extent),
		Vector2(extent, 0.0),
		Vector2(0.0, extent),
		Vector2(-extent, 0.0),
		Vector2(0.0, -extent),
	])
	draw_polyline(outline, border_color, 2.0, true)
