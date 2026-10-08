extends RefCounted
class_name VillagePlan

var village_id: int = -1
var is_large: bool = false
var bounds: Rect2i = Rect2i()
var interior_bounds: Rect2i = Rect2i()
var gate_tiles: Array[Vector2i] = []
var approach_tiles: Array[Vector2i] = []
var wall_tiles: Array[Vector2i] = []
var resident_spawn_tiles: Array[Vector2i] = []
var pig_spawn_tiles: Array[Vector2i] = []
var loot_spawn_tiles: Array[Vector2i] = []


func _init(
		id: int = -1,
		village_bounds: Rect2i = Rect2i(),
		large_village: bool = false
	) -> void:
	village_id = id
	is_large = large_village
	bounds = village_bounds
	if bounds.size.x >= 3 and bounds.size.y >= 3:
		interior_bounds = Rect2i(bounds.position + Vector2i.ONE, bounds.size - Vector2i(2, 2))


func contains_tile(tile: Vector2i) -> bool:
	return bounds.has_point(tile)


func contains_interior_tile(tile: Vector2i) -> bool:
	return interior_bounds.has_point(tile)


func get_reserved_tiles() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y: int in range(bounds.position.y, bounds.end.y):
		for x: int in range(bounds.position.x, bounds.end.x):
			result.append(Vector2i(x, y))
	for tile: Vector2i in approach_tiles:
		if tile not in result:
			result.append(tile)
	return result
