extends RefCounted
class_name WorldEventPlanner

const INVALID_TILE: Vector2i = Vector2i(-1, -1)
const EVENT_SEED_SALT: int = 0x45564E54


func create_plans(
		map_size: Vector2i,
		definitions: Array[WorldEventDefinition],
		seed_value: int,
		walkable_tiles: Dictionary[Vector2i, bool],
		blocked_tiles: Dictionary[Vector2i, bool],
		village_plans: Array[VillagePlan],
		minimum_events: int,
		maximum_events: int
	) -> Array[WorldEventPlan]:
	var result: Array[WorldEventPlan] = []
	if definitions.is_empty() or walkable_tiles.is_empty():
		return result

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value ^ EVENT_SEED_SALT
	var available_definitions: Array[WorldEventDefinition] = []
	for definition: WorldEventDefinition in definitions:
		if definition != null and not definition.event_id.is_empty():
			available_definitions.append(definition)
	_shuffle_definitions(available_definitions, rng)

	var selected: Array[WorldEventDefinition] = []
	for definition: WorldEventDefinition in available_definitions:
		if definition.always_plan or rng.randf() <= definition.spawn_probability:
			selected.append(definition)

	var lower: int = clampi(minimum_events, 0, available_definitions.size())
	var upper: int = clampi(maxi(maximum_events, lower), lower, available_definitions.size())
	var target_count: int = rng.randi_range(lower, upper) if upper > lower else lower
	for definition: WorldEventDefinition in available_definitions:
		if selected.size() >= target_count:
			break
		if definition not in selected:
			selected.append(definition)
	while selected.size() > target_count:
		var removable_index: int = _find_optional_definition_from_end(selected)
		if removable_index < 0:
			break
		selected.remove_at(removable_index)

	var event_reserved_tiles: Dictionary[Vector2i, bool] = {}
	var used_villages: Dictionary[int, bool] = {}
	for definition: WorldEventDefinition in selected:
		var placement: Dictionary = _find_placement(
			definition,
			map_size,
			rng,
			walkable_tiles,
			blocked_tiles,
			event_reserved_tiles,
			village_plans,
			used_villages
		)
		var center_tile: Vector2i = placement.get("tile", INVALID_TILE)
		if center_tile == INVALID_TILE:
			push_warning("WorldEventPlanner: no free tile for '%s'" % definition.event_id)
			continue
		var village_id: int = int(placement.get("village_id", -1))
		var plan: WorldEventPlan = WorldEventPlan.new(
			definition.event_id,
			center_tile,
			village_id,
			definition.reservation_radius_tiles
		)
		result.append(plan)
		for tile: Vector2i in plan.get_reserved_tiles(map_size):
			event_reserved_tiles[tile] = true
		if village_id >= 0:
			used_villages[village_id] = true
	return result


func _find_placement(
		definition: WorldEventDefinition,
		map_size: Vector2i,
		rng: RandomNumberGenerator,
		walkable_tiles: Dictionary[Vector2i, bool],
		blocked_tiles: Dictionary[Vector2i, bool],
		event_reserved_tiles: Dictionary[Vector2i, bool],
		village_plans: Array[VillagePlan],
		used_villages: Dictionary[int, bool]
	) -> Dictionary:
	if definition.placement != WorldEventDefinition.Placement.WORLD:
		return _find_village_placement(
			definition,
			rng,
			walkable_tiles,
			event_reserved_tiles,
			village_plans,
			used_villages
		)

	var candidates: Array[Vector2i] = []
	for tile: Vector2i in walkable_tiles:
		if blocked_tiles.has(tile) or event_reserved_tiles.has(tile):
			continue
		if tile.x < 4 or tile.y < 4 or tile.x >= map_size.x - 4 or tile.y >= map_size.y - 4:
			continue
		candidates.append(tile)
	_shuffle_tiles(candidates, rng)
	for tile: Vector2i in candidates:
		if _is_area_free(
			tile,
			definition.reservation_radius_tiles,
			walkable_tiles,
			blocked_tiles,
			event_reserved_tiles
		):
			return {"tile": tile, "village_id": -1}
	return {"tile": INVALID_TILE, "village_id": -1}


func _find_village_placement(
		definition: WorldEventDefinition,
		rng: RandomNumberGenerator,
		walkable_tiles: Dictionary[Vector2i, bool],
		event_reserved_tiles: Dictionary[Vector2i, bool],
		village_plans: Array[VillagePlan],
		used_villages: Dictionary[int, bool]
	) -> Dictionary:
	var shuffled_plans: Array[VillagePlan] = []
	shuffled_plans.assign(village_plans)
	_shuffle_villages(shuffled_plans, rng)
	shuffled_plans.sort_custom(func(a: VillagePlan, b: VillagePlan) -> bool:
		return int(used_villages.has(a.village_id)) < int(used_villages.has(b.village_id))
	)
	for village: VillagePlan in shuffled_plans:
		var candidates: Array[Vector2i] = _get_village_candidates(definition, village)
		_shuffle_tiles(candidates, rng)
		for tile: Vector2i in candidates:
			if walkable_tiles.has(tile) and not event_reserved_tiles.has(tile):
				return {"tile": tile, "village_id": village.village_id}
	return {"tile": INVALID_TILE, "village_id": -1}


func _get_village_candidates(
		definition: WorldEventDefinition,
		village: VillagePlan
	) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if definition.placement == WorldEventDefinition.Placement.VILLAGE_INTERIOR:
		result.assign(village.resident_spawn_tiles)
		if result.is_empty():
			result.append(_get_rect_center(village.interior_bounds))
		return result
	result.assign(village.approach_tiles)
	if not result.is_empty():
		return result
	var center: Vector2i = _get_rect_center(village.bounds)
	result.append(Vector2i(village.bounds.position.x - 2, center.y))
	result.append(Vector2i(village.bounds.end.x + 1, center.y))
	result.append(Vector2i(center.x, village.bounds.position.y - 2))
	result.append(Vector2i(center.x, village.bounds.end.y + 1))
	return result


func _get_rect_center(rect: Rect2i) -> Vector2i:
	return rect.position + Vector2i(
		floori(float(rect.size.x) * 0.5),
		floori(float(rect.size.y) * 0.5)
	)


func _is_area_free(
		center: Vector2i,
		radius: int,
		walkable_tiles: Dictionary[Vector2i, bool],
		blocked_tiles: Dictionary[Vector2i, bool],
		event_reserved_tiles: Dictionary[Vector2i, bool]
	) -> bool:
	for y_offset: int in range(-radius, radius + 1):
		for x_offset: int in range(-radius, radius + 1):
			var tile: Vector2i = center + Vector2i(x_offset, y_offset)
			if not walkable_tiles.has(tile) \
					or blocked_tiles.has(tile) \
					or event_reserved_tiles.has(tile):
				return false
	return true


func _find_optional_definition_from_end(
		definitions: Array[WorldEventDefinition]
	) -> int:
	for index: int in range(definitions.size() - 1, -1, -1):
		if not definitions[index].always_plan:
			return index
	return -1


func _shuffle_definitions(
		definitions: Array[WorldEventDefinition],
		rng: RandomNumberGenerator
	) -> void:
	for index: int in range(definitions.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var temporary: WorldEventDefinition = definitions[index]
		definitions[index] = definitions[swap_index]
		definitions[swap_index] = temporary


func _shuffle_villages(
		villages: Array[VillagePlan],
		rng: RandomNumberGenerator
	) -> void:
	for index: int in range(villages.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var temporary: VillagePlan = villages[index]
		villages[index] = villages[swap_index]
		villages[swap_index] = temporary


func _shuffle_tiles(tiles: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for index: int in range(tiles.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var temporary: Vector2i = tiles[index]
		tiles[index] = tiles[swap_index]
		tiles[swap_index] = temporary
