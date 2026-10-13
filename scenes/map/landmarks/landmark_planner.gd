extends RefCounted
class_name LandmarkPlanner


func create_plans(
		map_size: Vector2i,
		definitions: Array[LandmarkDefinition],
		seed_value: int,
		walkable_tiles: Dictionary[Vector2i, bool],
		water_tiles: Dictionary[Vector2i, bool],
		unavailable_tiles: Dictionary[Vector2i, bool],
		biome_map_data: BiomeMapData = null
	) -> Array[LandmarkPlan]:
	var plans: Array[LandmarkPlan] = []
	var occupied: Dictionary[Vector2i, bool] = {}
	for unavailable_tile: Vector2i in unavailable_tiles:
		occupied[unavailable_tile] = true
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x4C414E44
	var sorted_definitions: Array[LandmarkDefinition] = []
	for definition: LandmarkDefinition in definitions:
		if definition != null:
			sorted_definitions.append(definition)
	sorted_definitions.sort_custom(
		func(a: LandmarkDefinition, b: LandmarkDefinition) -> bool:
			if a.generation_priority != b.generation_priority:
				return a.generation_priority > b.generation_priority
			var a_size: Vector2i = a.get_normalized_size()
			var b_size: Vector2i = b.get_normalized_size()
			return a_size.x * a_size.y > b_size.x * b_size.y
	)
	for definition: LandmarkDefinition in sorted_definitions:
		if definition == null or definition.landmark_id.is_empty():
			continue
		var instance_count: int = definition.get_instance_count(rng)
		for instance_index: int in range(instance_count):
			var plan: LandmarkPlan
			if definition.is_bridge:
				plan = _create_bridge_plan(
					map_size, definition, rng, walkable_tiles, water_tiles, occupied
				)
			else:
				plan = _create_land_plan(
					map_size,
					definition,
					rng,
					walkable_tiles,
					occupied,
					biome_map_data
				)
			if plan == null:
				push_warning(
					"LandmarkPlanner: no free area for %s instance %d" % [
						definition.landmark_id,
						instance_index + 1,
					]
				)
				continue
			plans.append(plan)
			_reserve_plan(plan, definition.spacing_tiles, map_size, occupied)
	return plans


func _create_land_plan(
		map_size: Vector2i,
		definition: LandmarkDefinition,
		rng: RandomNumberGenerator,
		walkable_tiles: Dictionary[Vector2i, bool],
		occupied: Dictionary[Vector2i, bool],
		biome_map_data: BiomeMapData
	) -> LandmarkPlan:
	var size: Vector2i = definition.get_normalized_size()
	var margin: int = maxi(definition.edge_margin_tiles, 1)
	if map_size.x < size.x + margin * 2 or map_size.y < size.y + margin * 2:
		return null
	if biome_map_data != null:
		for biome_id: StringName in definition.allowed_biomes:
			var region_center: Vector2i = biome_map_data.get_guaranteed_region_center(
				biome_id
			)
			if region_center.x < 0:
				continue
			var centered_position: Vector2i = region_center - Vector2i(
				floori(float(size.x) / 2.0),
				floori(float(size.y) / 2.0)
			)
			var centered_bounds: Rect2i = Rect2i(centered_position, size)
			var centered_tiles: Array[Vector2i] = _get_rect_tiles(centered_bounds)
			if _bounds_respect_edge_margin(centered_bounds, map_size, margin) \
					and _tiles_are_available(
						centered_tiles, walkable_tiles, occupied
					) \
					and _matches_biome_requirements(
						centered_bounds,
						definition,
						biome_map_data,
						map_size
					):
				return LandmarkPlan.new(
					definition.landmark_id,
					centered_bounds,
					centered_tiles
				)
			var nearby_plan: LandmarkPlan = _find_near_biome_center(
				region_center,
				size,
				map_size,
				margin,
				definition,
				walkable_tiles,
				occupied,
				biome_map_data
			)
			if nearby_plan != null:
				return nearby_plan
	for _attempt: int in range(definition.placement_attempts):
		var position: Vector2i = Vector2i(
			rng.randi_range(margin, map_size.x - size.x - margin),
			rng.randi_range(margin, map_size.y - size.y - margin)
		)
		var bounds: Rect2i = Rect2i(position, size)
		var tiles: Array[Vector2i] = _get_rect_tiles(bounds)
		if _tiles_are_available(tiles, walkable_tiles, occupied) \
				and _matches_biome_requirements(
					bounds,
					definition,
					biome_map_data,
					map_size
				):
			return LandmarkPlan.new(definition.landmark_id, bounds, tiles)
	return null


func _find_near_biome_center(
		region_center: Vector2i,
		size: Vector2i,
		map_size: Vector2i,
		margin: int,
		definition: LandmarkDefinition,
		walkable_tiles: Dictionary[Vector2i, bool],
		occupied: Dictionary[Vector2i, bool],
		biome_map_data: BiomeMapData
	) -> LandmarkPlan:
	var half_size: Vector2i = Vector2i(
		floori(float(size.x) / 2.0),
		floori(float(size.y) / 2.0)
	)
	for radius: int in range(4, 41, 4):
		for direction: Vector2i in [
			Vector2i.RIGHT,
			Vector2i.DOWN,
			Vector2i.LEFT,
			Vector2i.UP,
			Vector2i(1, 1),
			Vector2i(-1, 1),
			Vector2i(-1, -1),
			Vector2i(1, -1),
		]:
			var position: Vector2i = region_center + direction * radius - half_size
			var bounds: Rect2i = Rect2i(position, size)
			var tiles: Array[Vector2i] = _get_rect_tiles(bounds)
			if _bounds_respect_edge_margin(bounds, map_size, margin) \
					and _tiles_are_available(tiles, walkable_tiles, occupied) \
					and _matches_biome_requirements(
						bounds, definition, biome_map_data, map_size
					):
				return LandmarkPlan.new(definition.landmark_id, bounds, tiles)
	return null


func _bounds_respect_edge_margin(
		bounds: Rect2i,
		map_size: Vector2i,
		margin: int
	) -> bool:
	return bounds.position.x >= margin \
		and bounds.position.y >= margin \
		and bounds.end.x <= map_size.x - margin \
		and bounds.end.y <= map_size.y - margin


func _create_bridge_plan(
		map_size: Vector2i,
		definition: LandmarkDefinition,
		rng: RandomNumberGenerator,
		walkable_tiles: Dictionary[Vector2i, bool],
		water_tiles: Dictionary[Vector2i, bool],
		occupied: Dictionary[Vector2i, bool]
	) -> LandmarkPlan:
	var candidates: Array[Vector2i] = []
	for tile: Vector2i in water_tiles:
		candidates.append(tile)
	_shuffle_tiles(candidates, rng)
	for start: Vector2i in candidates:
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
			for length: int in range(2, 7):
				var before: Vector2i = start - direction
				var after: Vector2i = start + direction * length
				if not _is_inside_map(before, map_size) \
						or not _is_inside_map(after, map_size) \
						or not walkable_tiles.has(before) \
						or not walkable_tiles.has(after):
					continue
				var bridge_tiles: Array[Vector2i] = []
				var valid: bool = true
				for step: int in range(length):
					var tile: Vector2i = start + direction * step
					if not water_tiles.has(tile) or occupied.has(tile):
						valid = false
						break
					bridge_tiles.append(tile)
				if not valid:
					continue
				var minimum: Vector2i = Vector2i(
					mini(before.x, after.x), mini(before.y, after.y)
				)
				var maximum: Vector2i = Vector2i(
					maxi(before.x, after.x), maxi(before.y, after.y)
				)
				var bounds: Rect2i = Rect2i(minimum, maximum - minimum + Vector2i.ONE)
				var plan: LandmarkPlan = LandmarkPlan.new(
					definition.landmark_id, bounds, bridge_tiles
				)
				plan.bridge_tiles.assign(bridge_tiles)
				return plan
	return null


func _tiles_are_available(
		tiles: Array[Vector2i],
		walkable_tiles: Dictionary[Vector2i, bool],
		occupied: Dictionary[Vector2i, bool]
	) -> bool:
	for tile: Vector2i in tiles:
		if not walkable_tiles.has(tile) or occupied.has(tile):
			return false
	return true


func _matches_biome_requirements(
		bounds: Rect2i,
		definition: LandmarkDefinition,
		biome_map_data: BiomeMapData,
		map_size: Vector2i
	) -> bool:
	if biome_map_data == null:
		return true
	var center_tile: Vector2i = bounds.position + Vector2i(
		floori(float(bounds.size.x) / 2.0),
		floori(float(bounds.size.y) / 2.0)
	)
	var center_biome: StringName = biome_map_data.get_biome_id(center_tile)
	if not definition.allowed_biomes.is_empty() \
			and center_biome not in definition.allowed_biomes:
		return false
	if definition.biome_border_margin_tiles <= 0:
		return true
	var protected_bounds: Rect2i = bounds.grow(definition.biome_border_margin_tiles)
	for tile: Vector2i in _get_rect_tiles(protected_bounds):
		if not _is_inside_map(tile, map_size) \
				or biome_map_data.get_biome_id(tile) != center_biome:
			return false
	return true


func _reserve_plan(
		plan: LandmarkPlan,
		spacing: int,
		map_size: Vector2i,
		occupied: Dictionary[Vector2i, bool]
	) -> void:
	var expanded: Rect2i = plan.bounds.grow(maxi(spacing, 0))
	for tile: Vector2i in _get_rect_tiles(expanded):
		if _is_inside_map(tile, map_size):
			occupied[tile] = true


func _get_rect_tiles(bounds: Rect2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y: int in range(bounds.position.y, bounds.end.y):
		for x: int in range(bounds.position.x, bounds.end.x):
			result.append(Vector2i(x, y))
	return result


func _is_inside_map(tile: Vector2i, map_size: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < map_size.x and tile.y < map_size.y


func _shuffle_tiles(tiles: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for index: int in range(tiles.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var temporary: Vector2i = tiles[index]
		tiles[index] = tiles[swap_index]
		tiles[swap_index] = temporary
