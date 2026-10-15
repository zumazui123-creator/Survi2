extends RefCounted
class_name WorldEventPlan

var event_id: StringName
var center_tile: Vector2i
var village_id: int = -1
var reservation_radius_tiles: int = 0


func _init(
		planned_event_id: StringName = &"",
		planned_center_tile: Vector2i = Vector2i.ZERO,
		planned_village_id: int = -1,
		planned_reservation_radius: int = 0
	) -> void:
	event_id = planned_event_id
	center_tile = planned_center_tile
	village_id = planned_village_id
	reservation_radius_tiles = maxi(planned_reservation_radius, 0)


func get_key() -> String:
	return "%s:%d:%d" % [String(event_id), center_tile.x, center_tile.y]


func get_reserved_tiles(map_size: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y_offset: int in range(-reservation_radius_tiles, reservation_radius_tiles + 1):
		for x_offset: int in range(-reservation_radius_tiles, reservation_radius_tiles + 1):
			var tile: Vector2i = center_tile + Vector2i(x_offset, y_offset)
			if tile.x < 0 or tile.y < 0 or tile.x >= map_size.x or tile.y >= map_size.y:
				continue
			result.append(tile)
	return result
