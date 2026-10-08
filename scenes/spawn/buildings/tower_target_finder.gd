extends Node
class_name TowerTargetFinder

@export_range(1.0, 20.0, 0.5) var attack_range_tiles: float = 6.0
@export var target_group: StringName = &"sensor_enemy"


func find_nearest(origin: Node2D) -> Node2D:
	if not is_instance_valid(origin):
		return null
	var nearest_target: Node2D
	var nearest_distance_squared: float = INF
	var maximum_distance: float = attack_range_tiles * float(Constants.TILE_SIZE)
	var maximum_distance_squared: float = maximum_distance * maximum_distance
	for candidate: Node in origin.get_tree().get_nodes_in_group(target_group):
		var target: Node2D = candidate as Node2D
		if target == null or target.is_queued_for_deletion() or not target.has_method("getDamage"):
			continue
		var distance_squared: float = origin.global_position.distance_squared_to(target.global_position)
		if distance_squared <= maximum_distance_squared \
				and distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_target = target
	return nearest_target
