extends RefCounted
class_name BuildingPlacementValidator

enum Result {
	OK,
	UNKNOWN_BUILDING,
	OUT_OF_BOUNDS,
	BLOCKED_BY_TERRAIN_OR_OBJECT,
	BLOCKED_BY_ENTITY,
	BLOCKED_BY_BUILDING,
	NOT_AFFORDABLE,
	SPAWN_FAILED,
}

const BLOCKING_ENTITY_GROUPS: Array[StringName] = [
	&"damageable",
	&"sensor_item",
]


func validate(
		world_map: Map,
		tiles: Array[Vector2i],
		is_building_tile_occupied: Callable
	) -> Result:
	if not is_instance_valid(world_map) or tiles.is_empty():
		return Result.OUT_OF_BOUNDS
	for tile: Vector2i in tiles:
		if not world_map.is_navigation_tile_in_bounds(tile):
			return Result.OUT_OF_BOUNDS
		if is_building_tile_occupied.call(tile):
			return Result.BLOCKED_BY_BUILDING
		if _has_blocking_entity(world_map, tile):
			return Result.BLOCKED_BY_ENTITY
		if not world_map.is_navigation_tile_walkable(tile, true):
			return Result.BLOCKED_BY_TERRAIN_OR_OBJECT
	return Result.OK


static func get_message(result: Result) -> String:
	match result:
		Result.OK:
			return "Das Gebäude kann gebaut werden."
		Result.UNKNOWN_BUILDING:
			return "Der Gebäudetyp ist unbekannt."
		Result.OUT_OF_BOUNDS:
			return "Das Ziel-Tile liegt außerhalb der Karte."
		Result.BLOCKED_BY_TERRAIN_OR_OBJECT:
			return "Das Ziel-Tile wird durch Terrain oder ein Objekt blockiert."
		Result.BLOCKED_BY_ENTITY:
			return "Auf dem Ziel-Tile befindet sich eine Figur oder ein Item."
		Result.BLOCKED_BY_BUILDING:
			return "Auf dem Ziel-Tile steht bereits ein Gebäude."
		Result.NOT_AFFORDABLE:
			return "Es fehlen die benötigten Baumaterialien."
		Result.SPAWN_FAILED:
			return "Das Gebäude konnte nicht erzeugt werden."
	return "Das Gebäude konnte nicht gebaut werden."


func _has_blocking_entity(world_map: Map, tile: Vector2i) -> bool:
	for group_name: StringName in BLOCKING_ENTITY_GROUPS:
		for candidate: Node in world_map.get_tree().get_nodes_in_group(group_name):
			var entity: Node2D = candidate as Node2D
			if entity == null or entity.is_queued_for_deletion():
				continue
			if world_map.world_to_navigation_tile(entity.global_position) == tile:
				return true
	return false
