extends RefCounted
class_name VillagePlanner


func create_plans(
		map_size: Vector2i,
		definition: VillageDefinition,
		seed: int,
		walkable_tiles: Dictionary[Vector2i, bool]
	) -> Array[VillagePlan]:
	var plans: Array[VillagePlan] = []
	if definition == null or walkable_tiles.is_empty():
		return plans

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed ^ 0x56494C4C
	var next_village_id: int = 0
	if definition.generate_large_village:
		var large_plan: VillagePlan = _try_create_plan(
			next_village_id,
			map_size,
			definition,
			rng,
			plans,
			walkable_tiles,
			true
		)
		if large_plan != null:
			plans.append(large_plan)
			next_village_id += 1
		else:
			push_warning("VillagePlanner: no walkable area was large enough for the large village")

	var requested_count: int = definition.get_village_count(rng)
	for _village_index: int in range(requested_count):
		var plan: VillagePlan = _try_create_plan(
			next_village_id,
			map_size,
			definition,
			rng,
			plans,
			walkable_tiles,
			false
		)
		if plan != null:
			plans.append(plan)
			next_village_id += 1
	if plans.size() < requested_count + int(definition.generate_large_village):
		push_warning(
			"VillagePlanner: only %d of %d villages fit on walkable, non-overlapping tiles"
			% [plans.size(), requested_count + int(definition.generate_large_village)]
		)
	return plans


func _try_create_plan(
		village_id: int,
		map_size: Vector2i,
		definition: VillageDefinition,
		rng: RandomNumberGenerator,
		existing_plans: Array[VillagePlan],
		walkable_tiles: Dictionary[Vector2i, bool],
		is_large: bool
	) -> VillagePlan:
	for _attempt: int in range(definition.placement_attempts_per_village):
		var size: Vector2i = definition.get_random_size(rng, is_large)
		var minimum_position: Vector2i = Vector2i.ONE * definition.map_edge_margin_tiles
		var maximum_position: Vector2i = map_size - size - minimum_position
		if maximum_position.x < minimum_position.x or maximum_position.y < minimum_position.y:
			return null
		var position: Vector2i = Vector2i(
			rng.randi_range(minimum_position.x, maximum_position.x),
			rng.randi_range(minimum_position.y, maximum_position.y)
		)
		var bounds: Rect2i = Rect2i(position, size)
		if _overlaps_existing(bounds, existing_plans, definition.village_spacing_tiles):
			continue
		if not _is_area_walkable(bounds.grow(2), walkable_tiles):
			continue
		return _build_plan(village_id, bounds, definition, rng, is_large)
	return _find_fallback_plan(
		village_id,
		map_size,
		definition,
		rng,
		existing_plans,
		walkable_tiles,
		is_large
	)


func _find_fallback_plan(
		village_id: int,
		map_size: Vector2i,
		definition: VillageDefinition,
		rng: RandomNumberGenerator,
		existing_plans: Array[VillagePlan],
		walkable_tiles: Dictionary[Vector2i, bool],
		is_large: bool
	) -> VillagePlan:
	var size: Vector2i = definition.get_minimum_size(is_large)
	var minimum_position: Vector2i = Vector2i.ONE * definition.map_edge_margin_tiles
	var maximum_position: Vector2i = map_size - size - minimum_position
	if maximum_position.x < minimum_position.x or maximum_position.y < minimum_position.y:
		return null

	var candidate_positions: Array[Vector2i] = []
	for y: int in range(minimum_position.y, maximum_position.y + 1):
		for x: int in range(minimum_position.x, maximum_position.x + 1):
			candidate_positions.append(Vector2i(x, y))
	_shuffle_tiles(candidate_positions, rng)
	for position: Vector2i in candidate_positions:
		var bounds: Rect2i = Rect2i(position, size)
		if _overlaps_existing(bounds, existing_plans, definition.village_spacing_tiles):
			continue
		if not _is_area_walkable(bounds.grow(2), walkable_tiles):
			continue
		return _build_plan(village_id, bounds, definition, rng, is_large)
	return null


func _is_area_walkable(
		area: Rect2i,
		walkable_tiles: Dictionary[Vector2i, bool]
	) -> bool:
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			if not walkable_tiles.has(Vector2i(x, y)):
				return false
	return true


func _overlaps_existing(
		bounds: Rect2i,
		existing_plans: Array[VillagePlan],
		spacing: int
	) -> bool:
	var expanded_bounds: Rect2i = bounds.grow(maxi(spacing, 0))
	for plan: VillagePlan in existing_plans:
		if expanded_bounds.intersects(plan.bounds):
			return true
	return false


func _build_plan(
		village_id: int,
		bounds: Rect2i,
		definition: VillageDefinition,
		rng: RandomNumberGenerator,
		is_large: bool
	) -> VillagePlan:
	var plan: VillagePlan = VillagePlan.new(village_id, bounds, is_large)
	var gate_side: int = rng.randi_range(0, 3)
	var center_x: int = bounds.position.x + floori(float(bounds.size.x) / 2.0)
	var center_y: int = bounds.position.y + floori(float(bounds.size.y) / 2.0)
	var gate_tile: Vector2i
	var outward_direction: Vector2i
	match gate_side:
		0:
			gate_tile = Vector2i(center_x, bounds.position.y)
			outward_direction = Vector2i.UP
		1:
			gate_tile = Vector2i(bounds.end.x - 1, center_y)
			outward_direction = Vector2i.RIGHT
		2:
			gate_tile = Vector2i(center_x, bounds.end.y - 1)
			outward_direction = Vector2i.DOWN
		_:
			gate_tile = Vector2i(bounds.position.x, center_y)
			outward_direction = Vector2i.LEFT
	plan.gate_tiles.append(gate_tile)
	plan.approach_tiles.append(gate_tile + outward_direction)
	plan.approach_tiles.append(gate_tile + outward_direction * 2)

	for y: int in range(bounds.position.y, bounds.end.y):
		for x: int in range(bounds.position.x, bounds.end.x):
			var tile: Vector2i = Vector2i(x, y)
			var is_border: bool = x == bounds.position.x \
				or x == bounds.end.x - 1 \
				or y == bounds.position.y \
				or y == bounds.end.y - 1
			if is_border and tile not in plan.gate_tiles:
				plan.wall_tiles.append(tile)

	var available_tiles: Array[Vector2i] = []
	for y: int in range(plan.interior_bounds.position.y, plan.interior_bounds.end.y):
		for x: int in range(plan.interior_bounds.position.x, plan.interior_bounds.end.x):
			available_tiles.append(Vector2i(x, y))
	if is_large:
		_reserve_center_loot_tiles(plan, available_tiles)
	_shuffle_tiles(available_tiles, rng)

	var resident_count: int = mini(
		definition.get_resident_count(rng, is_large),
		available_tiles.size()
	)
	for _resident_index: int in range(resident_count):
		plan.resident_spawn_tiles.append(available_tiles.pop_back())
	var pig_count: int = mini(definition.get_pig_count(rng, is_large), available_tiles.size())
	for _pig_index: int in range(pig_count):
		plan.pig_spawn_tiles.append(available_tiles.pop_back())
	return plan


func _reserve_center_loot_tiles(
		plan: VillagePlan,
		available_tiles: Array[Vector2i]
	) -> void:
	var center: Vector2i = plan.interior_bounds.position + Vector2i(
		floori(float(plan.interior_bounds.size.x) / 2.0),
		floori(float(plan.interior_bounds.size.y) / 2.0)
	)
	var offsets: Array[Vector2i] = [
		Vector2i.ZERO,
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.DOWN,
	]
	for offset: Vector2i in offsets:
		var tile: Vector2i = center + offset
		if plan.contains_interior_tile(tile) and tile in available_tiles:
			plan.loot_spawn_tiles.append(tile)
			available_tiles.erase(tile)


func _shuffle_tiles(tiles: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for index: int in range(tiles.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var temporary: Vector2i = tiles[index]
		tiles[index] = tiles[swap_index]
		tiles[swap_index] = temporary
