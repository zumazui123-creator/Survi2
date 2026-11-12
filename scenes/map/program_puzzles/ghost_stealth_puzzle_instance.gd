extends RefCounted
class_name GhostStealthPuzzleInstance

var puzzle_index: int
var definition: GhostStealthPuzzleDefinition
var plan: LandmarkPlan
var route_tiles: Array[Vector2i] = []
var route_offsets: Array[Vector2i] = []
var guard_route_indices: PackedInt32Array = PackedInt32Array()
var treasure_tile: Vector2i
var visual: GhostStealthPuzzleVisual
var announced_peers: Dictionary[int, bool] = {}
var movement_remaining: float = 0.0
var treasure_visible: bool = true
var completed: bool = false


func _init(
		new_index: int,
		new_definition: GhostStealthPuzzleDefinition,
		new_plan: LandmarkPlan
	) -> void:
	puzzle_index = new_index
	definition = new_definition
	plan = new_plan
	treasure_tile = plan.center_tile + definition.treasure_offset
	movement_remaining = definition.movement_interval_seconds


func get_guard_tile(guard_index: int) -> Vector2i:
	if route_tiles.is_empty() or guard_index < 0 \
			or guard_index >= guard_route_indices.size():
		return plan.center_tile
	var route_index: int = posmod(guard_route_indices[guard_index], route_tiles.size())
	return route_tiles[route_index]


func get_guard_facing(guard_index: int) -> Vector2i:
	if route_tiles.size() < 2 or guard_index < 0 \
			or guard_index >= guard_route_indices.size():
		return Vector2i.DOWN
	var route_index: int = posmod(guard_route_indices[guard_index], route_tiles.size())
	var next_index: int = (route_index + 1) % route_tiles.size()
	var delta: Vector2i = route_tiles[next_index] - route_tiles[route_index]
	if delta == Vector2i.ZERO:
		return Vector2i.DOWN
	return Vector2i(signi(delta.x), signi(delta.y))


func advance_guards() -> void:
	if route_tiles.is_empty():
		return
	for guard_index: int in range(guard_route_indices.size()):
		guard_route_indices[guard_index] = (
			guard_route_indices[guard_index] + 1
		) % route_tiles.size()
