extends BuildingEntity
class_name ShieldWallBuilding

@export_range(1.0, 6.0, 0.5) var protection_radius_tiles: float = 1.5
@export_range(0.1, 1.0, 0.05) var protected_damage_multiplier: float = 0.5


func get_damage_multiplier_for(target: BuildingEntity) -> float:
	if not is_instance_valid(target) \
			or target == self \
			or target.builder_peer_id != builder_peer_id \
			or hp <= 0.0:
		return 1.0
	var radius_pixels: float = protection_radius_tiles * float(Constants.TILE_SIZE)
	if global_position.distance_squared_to(target.global_position) > radius_pixels * radius_pixels:
		return 1.0
	return protected_damage_multiplier
