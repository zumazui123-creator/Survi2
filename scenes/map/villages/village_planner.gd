extends RefCounted
class_name VillagePlanner


func create_plans(
		map_size: Vector2i,
		definition: VillageDefinition,
		seed: int
	) -> Array[VillagePlan]:
	var plans: Array[VillagePlan] = []
	if definition == null:
		return plans

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed ^ 0x56494C4C
	var requested_count: int = definition.get_village_count(rng)
	for village_index: int in range(requested_count):
		var plan: VillagePlan = _try_create_plan(
			village_index,
			map_size,
			definition,
			rng,
			plans
		)
		if plan != null:
			plans.append(plan)
	return plans


func _try_create_plan(
		village_id: int,
		map_size: Vector2i,
		definition: VillageDefinition,
		rng: RandomNumberGenerator,
		existing_plans: Array[VillagePlan]
	) -> VillagePlan:
	for _attempt: int in range(definition.placement_attempts_per_village):
		var size: Vector2i = definition.get_random_size(rng)
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
		return _build_plan(village_id, bounds, definition, rng)
	return null


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
		rng: RandomNumberGenerator
	) -> VillagePlan:
	var plan: VillagePlan = VillagePlan.new(village_id, bounds)
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
	_shuffle_tiles(available_tiles, rng)

	var resident_count: int = mini(definition.get_resident_count(rng), available_tiles.size())
	for _resident_index: int in range(resident_count):
		plan.resident_spawn_tiles.append(available_tiles.pop_back())
	var pig_count: int = mini(definition.get_pig_count(rng), available_tiles.size())
	for _pig_index: int in range(pig_count):
		plan.pig_spawn_tiles.append(available_tiles.pop_back())
	return plan


func _shuffle_tiles(tiles: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for index: int in range(tiles.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var temporary: Vector2i = tiles[index]
		tiles[index] = tiles[swap_index]
		tiles[swap_index] = temporary
