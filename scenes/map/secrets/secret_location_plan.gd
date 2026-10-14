extends RefCounted
class_name SecretLocationPlan

var plan_id: int = -1
var secret_id: StringName = &""
var bounds: Rect2i = Rect2i()
var center_tile: Vector2i = Vector2i.ZERO
var entrance_tile: Vector2i = Vector2i.ZERO
var exit_tile: Vector2i = Vector2i.ZERO
var room_tiles: Array[Vector2i] = []
var terrain_blocked_tiles: Array[Vector2i] = []
var cover_tree_tiles: Array[Vector2i] = []
var barrier_tiles: Array[Vector2i] = []
var access_building_tiles: Array[Vector2i] = []
var loot_tiles: Array[Vector2i] = []


func _init(
		new_plan_id: int = -1,
		new_secret_id: StringName = &"",
		new_bounds: Rect2i = Rect2i()
	) -> void:
	plan_id = new_plan_id
	secret_id = new_secret_id
	bounds = new_bounds
	center_tile = bounds.position + Vector2i(
		floori(float(bounds.size.x) * 0.5),
		floori(float(bounds.size.y) * 0.5)
	)
	entrance_tile = Vector2i(bounds.position.x, center_tile.y)
	exit_tile = Vector2i(bounds.end.x - 1, center_tile.y)


func get_reserved_tiles() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y: int in range(bounds.position.y, bounds.end.y):
		for x: int in range(bounds.position.x, bounds.end.x):
			result.append(Vector2i(x, y))
	for tile: Vector2i in access_building_tiles:
		if tile not in result:
			result.append(tile)
	for tile: Vector2i in cover_tree_tiles:
		if tile not in result:
			result.append(tile)
	for tile: Vector2i in [entrance_tile, exit_tile]:
		if tile not in result:
			result.append(tile)
	return result
