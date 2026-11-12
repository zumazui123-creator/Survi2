extends ProgramPuzzleDefinitionBase
class_name GhostStealthPuzzleDefinition

@export_group("Ghost patrol")
@export var ghost_actor_id: StringName = &"swampGhost"
@export_range(1, 8, 1) var guard_count: int = 3
@export_range(0.15, 3.0, 0.05) var movement_interval_seconds: float = 0.55
@export var patrol_waypoints: Array[Vector2i] = []
@export_group("Ghost sensor")
@export_range(1, 12, 1) var vision_range_tiles: int = 5
@export_range(0, 5, 1) var vision_half_width_tiles: int = 2
@export_group("Treasure")
@export var treasure_offset: Vector2i = Vector2i.ZERO
@export_range(2, 32, 1) var reset_radius_tiles: int = 10


func is_valid() -> bool:
	return is_common_valid() \
		and guard_count > 0 \
		and patrol_waypoints.size() >= 2 \
		and vision_range_tiles > 0


## The same tile mask is used for rendering and authoritative detection.
func get_vision_offsets(facing: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = [Vector2i.ZERO]
	var direction: Vector2i = facing
	if direction == Vector2i.ZERO:
		direction = Vector2i.DOWN
	var side: Vector2i = Vector2i(-direction.y, direction.x)
	for depth: int in range(1, vision_range_tiles + 1):
		var lateral_limit: int = mini(
			vision_half_width_tiles,
			floori(float(depth) * 0.5)
		)
		for lateral: int in range(-lateral_limit, lateral_limit + 1):
			result.append(direction * depth + side * lateral)
	return result
