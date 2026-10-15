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
		var large_role: VillageRoleDefinition = definition.get_large_village_role()
		var large_plan: VillagePlan = _try_create_plan(
			next_village_id,
			map_size,
			definition,
			rng,
			plans,
			walkable_tiles,
			true,
			large_role
		)
		if large_plan != null:
			plans.append(large_plan)
			next_village_id += 1
		else:
			push_warning("VillagePlanner: no walkable area was large enough for the large village")

	var requested_count: int = definition.get_village_count(rng)
	var small_roles: Array[VillageRoleDefinition] = definition.get_small_village_roles()
	_shuffle_roles(small_roles, rng)
	for village_index: int in range(requested_count):
		var role: VillageRoleDefinition = null
		if not small_roles.is_empty():
			role = small_roles[village_index % small_roles.size()]
		var plan: VillagePlan = _try_create_plan(
			next_village_id,
			map_size,
			definition,
			rng,
			plans,
			walkable_tiles,
			false,
			role
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
		is_large: bool,
		role: VillageRoleDefinition
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
		return _build_plan(village_id, bounds, definition, rng, is_large, role)
	return _find_fallback_plan(
		village_id,
		map_size,
		definition,
		rng,
		existing_plans,
		walkable_tiles,
		is_large,
		role
	)


func _find_fallback_plan(
		village_id: int,
		map_size: Vector2i,
		definition: VillageDefinition,
		rng: RandomNumberGenerator,
		existing_plans: Array[VillagePlan],
		walkable_tiles: Dictionary[Vector2i, bool],
		is_large: bool,
		role: VillageRoleDefinition
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
		return _build_plan(village_id, bounds, definition, rng, is_large, role)
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
		is_large: bool,
		role: VillageRoleDefinition
	) -> VillagePlan:
	var planned_role_id: StringName = role.role_id if role != null else &""
	var plan: VillagePlan = VillagePlan.new(village_id, bounds, is_large, planned_role_id)
	if role != null:
		plan.resident_actor_id = role.resident_actor_id
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
			var wall_density: float = role.wall_density if role != null else 1.0
			if is_border and tile not in plan.gate_tiles \
					and rng.randf() <= wall_density:
				plan.wall_tiles.append(tile)

	var available_tiles: Array[Vector2i] = []
	for y: int in range(plan.interior_bounds.position.y, plan.interior_bounds.end.y):
		for x: int in range(plan.interior_bounds.position.x, plan.interior_bounds.end.x):
			available_tiles.append(Vector2i(x, y))
	if role != null and not role.loot.is_empty():
		_reserve_center_loot_tiles(plan, available_tiles)
	elif is_large:
		_reserve_center_loot_tiles(plan, available_tiles)
	if role != null and role.feature_building_id != &"":
		_reserve_feature_tiles(plan, available_tiles, role.feature_building_count)
	_shuffle_tiles(available_tiles, rng)

	var requested_residents: int = role.get_resident_count(rng) \
		if role != null else definition.get_resident_count(rng, is_large)
	var resident_count: int = mini(requested_residents, available_tiles.size())
	for _resident_index: int in range(resident_count):
		plan.resident_spawn_tiles.append(available_tiles.pop_back())
	var requested_pigs: int = role.get_pig_count(rng) \
		if role != null else definition.get_pig_count(rng, is_large)
	var pig_count: int = mini(requested_pigs, available_tiles.size())
	for _pig_index: int in range(pig_count):
		plan.pig_spawn_tiles.append(available_tiles.pop_back())
	var merchant_count: int = mini(
		role.merchant_count if role != null else 0,
		available_tiles.size()
	)
	for _merchant_index: int in range(merchant_count):
		plan.merchant_spawn_tiles.append(available_tiles.pop_back())
	var hostile_count: int = mini(
		role.get_hostile_count(rng) if role != null else 0,
		available_tiles.size()
	)
	for _hostile_index: int in range(hostile_count):
		plan.hostile_spawn_tiles.append(available_tiles.pop_back())
		plan.hostile_actor_ids.append(role.get_random_hostile_actor_id(rng))
	return plan


func _reserve_feature_tiles(
		plan: VillagePlan,
		available_tiles: Array[Vector2i],
		requested_count: int
	) -> void:
	var corners: Array[Vector2i] = [
		plan.interior_bounds.position,
		Vector2i(plan.interior_bounds.end.x - 1, plan.interior_bounds.position.y),
		Vector2i(plan.interior_bounds.position.x, plan.interior_bounds.end.y - 1),
		plan.interior_bounds.end - Vector2i.ONE,
	]
	var feature_count: int = mini(maxi(requested_count, 0), corners.size())
	for index: int in range(feature_count):
		var tile: Vector2i = corners[index]
		if tile in available_tiles:
			plan.feature_building_tiles.append(tile)
			available_tiles.erase(tile)


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


func _shuffle_roles(
		roles: Array[VillageRoleDefinition],
		rng: RandomNumberGenerator
	) -> void:
	for index: int in range(roles.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var temporary: VillageRoleDefinition = roles[index]
		roles[index] = roles[swap_index]
		roles[swap_index] = temporary
