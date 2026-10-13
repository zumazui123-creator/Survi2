extends HealingWellBuilding
class_name WorldTreeBuilding

@export_range(0.1, 20.0, 0.5) var hydration_per_tick: float = 4.0
@export_range(0.1, 20.0, 0.5) var food_per_tick: float = 3.0


func _on_regeneration_timer_timeout() -> void:
	super()
	if not multiplayer.is_server() or hp <= 0.0:
		return
	var radius_pixels: float = effect_radius_tiles * float(Constants.TILE_SIZE)
	var radius_squared: float = radius_pixels * radius_pixels
	for candidate: Node in get_tree().get_nodes_in_group(Strings.GROUP_PLAYER):
		var target: Node2D = candidate as Node2D
		if target == null \
				or target.global_position.distance_squared_to(global_position) > radius_squared:
			continue
		var stats: PlayerStats = target.get("status") as PlayerStats
		if stats == null:
			continue
		stats.hydration += hydration_per_tick
		stats.food += food_per_tick
