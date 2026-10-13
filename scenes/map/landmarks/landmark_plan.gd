extends RefCounted
class_name LandmarkPlan

var landmark_id: StringName
var bounds: Rect2i
var center_tile: Vector2i
var reserved_tiles: Array[Vector2i] = []
var bridge_tiles: Array[Vector2i] = []


func _init(
		new_landmark_id: StringName = &"",
		new_bounds: Rect2i = Rect2i(),
		new_reserved_tiles: Array[Vector2i] = []
	) -> void:
	landmark_id = new_landmark_id
	bounds = new_bounds
	center_tile = bounds.position + Vector2i(
		floori(float(bounds.size.x) * 0.5),
		floori(float(bounds.size.y) * 0.5)
	)
	reserved_tiles.assign(new_reserved_tiles)


func contains_tile(tile: Vector2i) -> bool:
	return bounds.has_point(tile)
