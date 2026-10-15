extends RefCounted
class_name SecretLocationPlanner


func create_plans(
		map_size: Vector2i,
		definitions: Array[SecretLocationDefinition],
		seed_value: int,
		walkable_tiles: Dictionary[Vector2i, bool],
		water_tiles: Dictionary[Vector2i, bool],
		unavailable_tiles: Dictionary[Vector2i, bool],
		biome_map_data: BiomeMapData
	) -> Array[SecretLocationPlan]:
	var plans: Array[SecretLocationPlan] = []
	var occupied: Dictionary[Vector2i, bool] = {}
	for unavailable_tile: Vector2i in unavailable_tiles:
		occupied[unavailable_tile] = true
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x53454352
	var sorted_definitions: Array[SecretLocationDefinition] = []
	for definition: SecretLocationDefinition in definitions:
		if definition != null and not definition.secret_id.is_empty():
			sorted_definitions.append(definition)
	sorted_definitions.sort_custom(
		func(a: SecretLocationDefinition, b: SecretLocationDefinition) -> bool:
			return a.generation_priority > b.generation_priority
	)
	var next_plan_id: int = 0
	for definition: SecretLocationDefinition in sorted_definitions:
		for _instance_index: int in range(definition.get_instance_count(rng)):
			var plan: SecretLocationPlan = _try_create_plan(
				next_plan_id,
				map_size,
				definition,
				rng,
				walkable_tiles,
				water_tiles,
				occupied,
				biome_map_data
			)
			if plan == null:
				push_warning("SecretLocationPlanner: no area for '%s'" % definition.secret_id)
				continue
			plans.append(plan)
			_reserve(plan, definition.spacing_tiles, map_size, occupied)
			next_plan_id += 1
	return plans


func _try_create_plan(
		plan_id: int,
		map_size: Vector2i,
		definition: SecretLocationDefinition,
		rng: RandomNumberGenerator,
		walkable_tiles: Dictionary[Vector2i, bool],
		water_tiles: Dictionary[Vector2i, bool],
		occupied: Dictionary[Vector2i, bool],
		biome_map_data: BiomeMapData
	) -> SecretLocationPlan:
	var size: Vector2i = definition.get_normalized_size()
	var margin: int = definition.edge_margin_tiles
	if map_size.x <= size.x + margin * 2 or map_size.y <= size.y + margin * 2:
		return null
	for _attempt: int in range(definition.placement_attempts):
		var position: Vector2i = Vector2i(
			rng.randi_range(margin, map_size.x - size.x - margin),
			rng.randi_range(margin, map_size.y - size.y - margin)
		)
		var bounds: Rect2i = Rect2i(position, size)
		if not _matches_biome(bounds, definition, biome_map_data):
			continue
		if not _area_is_available(
				bounds,
				definition.terrain_style,
				walkable_tiles,
				water_tiles,
				occupied
			):
			continue
		var plan: SecretLocationPlan = SecretLocationPlan.new(
			plan_id,
			definition.secret_id,
			bounds
		)
		_configure_plan(plan, definition)
		return plan
	if definition.terrain_style == SecretLocationDefinition.TerrainStyle.ISLAND:
		return _create_island_fallback(
			plan_id,
			map_size,
			definition,
			rng,
			occupied,
			biome_map_data
		)
	return null


func _create_island_fallback(
		plan_id: int,
		map_size: Vector2i,
		definition: SecretLocationDefinition,
		rng: RandomNumberGenerator,
		occupied: Dictionary[Vector2i, bool],
		biome_map_data: BiomeMapData
	) -> SecretLocationPlan:
	var size: Vector2i = definition.get_normalized_size()
	var margin: int = definition.edge_margin_tiles
	for _attempt: int in range(definition.placement_attempts):
		var position: Vector2i = Vector2i(
			rng.randi_range(margin, map_size.x - size.x - margin),
			rng.randi_range(margin, map_size.y - size.y - margin)
		)
		var bounds: Rect2i = Rect2i(position, size)
		if not _matches_biome(bounds, definition, biome_map_data) \
				or _contains_occupied_tile(bounds, occupied):
			continue
		var plan: SecretLocationPlan = SecretLocationPlan.new(
			plan_id,
			definition.secret_id,
			bounds
		)
		_configure_plan(plan, definition)
		return plan
	return null


func _contains_occupied_tile(
		bounds: Rect2i,
		occupied: Dictionary[Vector2i, bool]
	) -> bool:
	for y: int in range(bounds.position.y, bounds.end.y):
		for x: int in range(bounds.position.x, bounds.end.x):
			if occupied.has(Vector2i(x, y)):
				return true
	return false


func _area_is_available(
		bounds: Rect2i,
		terrain_style: int,
		walkable_tiles: Dictionary[Vector2i, bool],
		water_tiles: Dictionary[Vector2i, bool],
		occupied: Dictionary[Vector2i, bool]
	) -> bool:
	var water_count: int = 0
	var tile_count: int = bounds.size.x * bounds.size.y
	for y: int in range(bounds.position.y, bounds.end.y):
		for x: int in range(bounds.position.x, bounds.end.x):
			var tile: Vector2i = Vector2i(x, y)
			if occupied.has(tile):
				return false
			if water_tiles.has(tile):
				water_count += 1
			if terrain_style != SecretLocationDefinition.TerrainStyle.ISLAND \
					and not walkable_tiles.has(tile):
				return false
	if terrain_style == SecretLocationDefinition.TerrainStyle.ISLAND:
		return water_count >= ceili(float(tile_count) * 0.35)
	return true


func _matches_biome(
		bounds: Rect2i,
		definition: SecretLocationDefinition,
		biome_map_data: BiomeMapData
	) -> bool:
	if biome_map_data == null or definition.allowed_biomes.is_empty():
		return true
	var center: Vector2i = bounds.position + Vector2i(
		floori(float(bounds.size.x) * 0.5),
		floori(float(bounds.size.y) * 0.5)
	)
	return biome_map_data.get_biome_id(center) in definition.allowed_biomes


func _configure_plan(
		plan: SecretLocationPlan,
		definition: SecretLocationDefinition
	) -> void:
	match definition.terrain_style:
		SecretLocationDefinition.TerrainStyle.ISLAND:
			_configure_island(plan)
		SecretLocationDefinition.TerrainStyle.CHAMBER:
			_configure_chamber(plan)
		SecretLocationDefinition.TerrainStyle.GAP:
			_configure_gap(plan)
		SecretLocationDefinition.TerrainStyle.PASSAGE:
			_configure_passage(plan)
		_:
			_configure_land_room(plan)

	match definition.access_type:
		SecretLocationDefinition.AccessType.TREE_COVER:
			plan.cover_tree_tiles = [
				plan.entrance_tile,
				plan.entrance_tile + Vector2i.UP,
				plan.entrance_tile + Vector2i.DOWN,
			]
		SecretLocationDefinition.AccessType.DESTRUCTIBLE_WALL:
			plan.barrier_tiles.append(plan.entrance_tile)
		SecretLocationDefinition.AccessType.TELEPORT:
			plan.access_building_tiles = [plan.entrance_tile, plan.exit_tile]
		SecretLocationDefinition.AccessType.JUMP:
			plan.access_building_tiles.append(plan.entrance_tile)
	if definition.boundary_building_id != &"":
		_add_room_boundary(plan)
	if plan.loot_tiles.is_empty():
		plan.loot_tiles.append(plan.center_tile)


func _add_room_boundary(plan: SecretLocationPlan) -> void:
	for y: int in range(plan.bounds.position.y, plan.bounds.end.y):
		for x: int in range(plan.bounds.position.x, plan.bounds.end.x):
			var tile: Vector2i = Vector2i(x, y)
			var border: bool = x == plan.bounds.position.x \
				or x == plan.bounds.end.x - 1 \
				or y == plan.bounds.position.y \
				or y == plan.bounds.end.y - 1
			if border and tile != plan.entrance_tile \
					and tile not in plan.cover_tree_tiles:
				plan.boundary_tiles.append(tile)


func _configure_land_room(plan: SecretLocationPlan) -> void:
	for y: int in range(plan.bounds.position.y + 1, plan.bounds.end.y - 1):
		for x: int in range(plan.bounds.position.x + 1, plan.bounds.end.x - 1):
			plan.room_tiles.append(Vector2i(x, y))
	plan.loot_tiles.append(plan.center_tile)


func _configure_island(plan: SecretLocationPlan) -> void:
	for y: int in range(plan.bounds.position.y, plan.bounds.end.y):
		for x: int in range(plan.bounds.position.x, plan.bounds.end.x):
			var tile: Vector2i = Vector2i(x, y)
			var border: bool = x == plan.bounds.position.x \
				or x == plan.bounds.end.x - 1 \
				or y == plan.bounds.position.y \
				or y == plan.bounds.end.y - 1
			if border:
				plan.terrain_blocked_tiles.append(tile)
			else:
				plan.room_tiles.append(tile)
	plan.entrance_tile = Vector2i(plan.bounds.position.x + 1, plan.center_tile.y)
	plan.exit_tile = Vector2i(plan.bounds.end.x - 2, plan.center_tile.y)
	plan.loot_tiles.append(plan.center_tile)


func _configure_chamber(plan: SecretLocationPlan) -> void:
	_configure_island(plan)
	plan.entrance_tile = Vector2i(plan.bounds.position.x, plan.center_tile.y)
	plan.terrain_blocked_tiles.erase(plan.entrance_tile)
	if plan.entrance_tile not in plan.room_tiles:
		plan.room_tiles.append(plan.entrance_tile)
	plan.exit_tile = plan.center_tile
	plan.access_building_tiles = [plan.entrance_tile, plan.exit_tile]


func _configure_gap(plan: SecretLocationPlan) -> void:
	plan.entrance_tile = Vector2i(plan.bounds.position.x, plan.center_tile.y)
	plan.exit_tile = Vector2i(plan.bounds.end.x - 2, plan.center_tile.y)
	plan.room_tiles = [plan.entrance_tile, plan.exit_tile]
	for x: int in range(plan.entrance_tile.x + 1, plan.exit_tile.x):
		plan.terrain_blocked_tiles.append(Vector2i(x, plan.center_tile.y))
	for isolation_offset: Vector2i in [
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.DOWN,
	]:
		var isolation_tile: Vector2i = plan.exit_tile + isolation_offset
		if isolation_tile not in plan.terrain_blocked_tiles:
			plan.terrain_blocked_tiles.append(isolation_tile)
	plan.loot_tiles.append(plan.exit_tile)


func _configure_passage(plan: SecretLocationPlan) -> void:
	for y: int in range(plan.bounds.position.y, plan.bounds.end.y):
		for x: int in range(plan.bounds.position.x, plan.bounds.end.x):
			var tile: Vector2i = Vector2i(x, y)
			if y == plan.center_tile.y:
				plan.room_tiles.append(tile)
			else:
				plan.barrier_tiles.append(tile)
	plan.loot_tiles.append(plan.center_tile)


func _reserve(
		plan: SecretLocationPlan,
		spacing: int,
		map_size: Vector2i,
		occupied: Dictionary[Vector2i, bool]
	) -> void:
	var expanded: Rect2i = plan.bounds.grow(maxi(spacing, 0))
	for y: int in range(maxi(expanded.position.y, 0), mini(expanded.end.y, map_size.y)):
		for x: int in range(maxi(expanded.position.x, 0), mini(expanded.end.x, map_size.x)):
			occupied[Vector2i(x, y)] = true
