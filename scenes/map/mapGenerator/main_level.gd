extends Node

@export_group("Tree placement")
@export_range(0, 100000, 1) var max_trees_per_map: int = 2500
@export_range(0.0, 1.0, 0.001) var max_tree_map_ratio: float = 0.06
@export var tree_object_ids: PackedStringArray = PackedStringArray([
	"tree0",
	"tree4",
	"tree5",
	"tree6",
])
@export_group("Villages")
@export var village_definition: VillageDefinition
@export_group("Landmarks")
@export var landmark_definitions: Array[LandmarkDefinition] = []
@export_group("World events")
@export var world_event_definitions: Array[WorldEventDefinition] = []
@export_range(0, 20, 1) var minimum_world_events: int = 4
@export_range(0, 20, 1) var maximum_world_events: int = 6
@export_group("Hidden locations")
@export var secret_definitions: Array[SecretLocationDefinition] = []
@export_group("Biomes")
@export var biome_definitions: Array[BiomeDefinition] = []
@export_range(0.0, 0.45, 0.01) var water_elevation_threshold: float = 0.26
@export_range(1, 4, 1) var path_half_width_tiles: int = 1
@export_range(4, 20, 1) var biome_landmark_reservation_radius: int = 12

@onready var map : Map = $".."

var walkable_tiles: Array[Vector2i] = []
var spawnable_tiles: Array[Vector2i] = []
var tree_spawn_data: Array[TreeSpawnData] = []
var village_plans: Array[VillagePlan] = []
var landmark_plans: Array[LandmarkPlan] = []
var world_event_plans: Array[WorldEventPlan] = []
var secret_location_plans: Array[SecretLocationPlan] = []
var _tree_candidate_tiles: Array[Vector2i] = []
var _village_reserved_tiles: Dictionary[Vector2i, bool] = {}
var _landmark_reserved_tiles: Dictionary[Vector2i, bool] = {}
var _world_event_reserved_tiles: Dictionary[Vector2i, bool] = {}
var _secret_reserved_tiles: Dictionary[Vector2i, bool] = {}
var _secret_terrain_blocked_tiles: Dictionary[Vector2i, bool] = {}
var _water_tiles: Dictionary[Vector2i, bool] = {}
var biome_map_data: BiomeMapData
var _biome_definitions_by_id: Dictionary[StringName, BiomeDefinition] = {}

func generateMainMap(levelData : Dictionary):
	walkable_tiles.clear()
	spawnable_tiles.clear()
	tree_spawn_data.clear()
	village_plans.clear()
	landmark_plans.clear()
	world_event_plans.clear()
	secret_location_plans.clear()
	_tree_candidate_tiles.clear()
	_village_reserved_tiles.clear()
	_landmark_reserved_tiles.clear()
	_world_event_reserved_tiles.clear()
	_secret_reserved_tiles.clear()
	_secret_terrain_blocked_tiles.clear()
	_water_tiles.clear()
	generate_terrain(levelData)
	_plan_landmarks()
	_plan_villages()
	_plan_world_events()
	_plan_secret_locations()
	_carve_paths_between_regions()
	_select_tree_spawns()
	map.set_level_options(1)
	map.generate_borders()
	return [
		walkable_tiles,
		spawnable_tiles,
		tree_spawn_data,
		village_plans,
		village_definition,
		landmark_plans,
		world_event_plans,
		secret_location_plans,
	]
	
func generate_terrain(levelData : Dictionary) -> void:
	print("generate_terrain with seed: ", Multihelper.mapSeed)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = Multihelper.mapSeed
	if "size" in levelData:
		map.width = levelData["size"].x
		map.height = levelData["size"].y

	_rebuild_biome_definition_index()
	var biome_generator: BiomeGenerator = BiomeGenerator.new()
	biome_map_data = biome_generator.generate(
		Vector2i(map.width, map.height),
		Multihelper.mapSeed,
		biome_definitions
	)
	map.configure_biome_map(biome_map_data, biome_definitions)

	for y: int in range(map.height):
		for x: int in range(map.width):
			var tile: Vector2i = Vector2i(x, y)
			var biome_id: StringName = biome_map_data.get_biome_id(tile)
			var definition: BiomeDefinition = _biome_definitions_by_id.get(
				biome_id
			) as BiomeDefinition
			var is_frozen_lake: bool = biome_id == &"snow"
			var is_water: bool = biome_map_data.get_elevation(tile) \
				< water_elevation_threshold and not is_frozen_lake
			if is_water:
				var water_index: int = rng.randi_range(0, map.waterCoors.size() - 1)
				map.tile_map.set_cell(
					tile,
					map.tileset_source,
					map.waterCoors[water_index],
					0
				)
				_water_tiles[tile] = true
				continue

			walkable_tiles.append(tile)
			spawnable_tiles.append(tile)
			var tile_coord: Vector2i = Vector2i.ZERO
			if definition != null:
				tile_coord = definition.get_random_ground_atlas(rng)
				if definition.tree_density > 0.0 \
						and rng.randf() <= definition.tree_density:
					_tree_candidate_tiles.append(tile)
			else:
				var grass_index: int = rng.randi_range(0, map.grassAtlasCoords.size() - 1)
				tile_coord = map.grassAtlasCoords[grass_index]
			map.tile_map.set_cell(tile, map.tileset_source, tile_coord, 0)


func _rebuild_biome_definition_index() -> void:
	_biome_definitions_by_id.clear()
	for definition: BiomeDefinition in biome_definitions:
		if definition != null and not definition.biome_id.is_empty():
			_biome_definitions_by_id[definition.biome_id] = definition


func _select_tree_spawns() -> void:
	var tree_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	tree_rng.seed = Multihelper.mapSeed ^ 0x54524545
	var selected_tiles: Array[Vector2i] = []

	# Every forest tile is eligible. The global limits below protect performance
	# without forcing an artificial minimum distance between neighboring trees.
	for candidate_tile: Vector2i in _tree_candidate_tiles:
		selected_tiles.append(candidate_tile)

	_shuffle_tiles(selected_tiles, tree_rng)
	var tree_limit: int = _get_tree_limit(selected_tiles.size())
	if selected_tiles.size() > tree_limit:
		selected_tiles.resize(tree_limit)
	selected_tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)

	for tile: Vector2i in selected_tiles:
		if _village_reserved_tiles.has(tile) \
				or _landmark_reserved_tiles.has(tile) \
				or _world_event_reserved_tiles.has(tile) \
				or _secret_reserved_tiles.has(tile):
			continue
		var available_tree_ids: PackedStringArray = PackedStringArray()
		var definition: BiomeDefinition = map.get_biome_definition_at(tile)
		if definition != null:
			available_tree_ids = definition.get_valid_tree_ids()
		else:
			available_tree_ids = tree_object_ids
		if available_tree_ids.is_empty():
			continue
		var tree_index: int = tree_rng.randi_range(0, available_tree_ids.size() - 1)
		var tree_object_id: String = String(available_tree_ids[tree_index])
		tree_spawn_data.append(TreeSpawnData.new(tile, tree_object_id))
	_append_secret_cover_trees()


func _plan_villages() -> void:
	if village_definition == null:
		return
	var available_village_tiles: Dictionary[Vector2i, bool] = {}
	for tile: Vector2i in walkable_tiles:
		if not _landmark_reserved_tiles.has(tile):
			available_village_tiles[tile] = true
	if biome_map_data != null:
		for center: Vector2i in biome_map_data.get_guaranteed_region_centers():
			for y_offset: int in range(
				-biome_landmark_reservation_radius,
				biome_landmark_reservation_radius + 1
			):
				for x_offset: int in range(
					-biome_landmark_reservation_radius,
					biome_landmark_reservation_radius + 1
				):
					available_village_tiles.erase(
						center + Vector2i(x_offset, y_offset)
					)
	var planner: VillagePlanner = VillagePlanner.new()
	village_plans = planner.create_plans(
		Vector2i(map.width, map.height),
		village_definition,
		Multihelper.mapSeed,
		available_village_tiles
	)
	for plan: VillagePlan in village_plans:
		for tile: Vector2i in plan.get_reserved_tiles():
			if not available_village_tiles.has(tile):
				push_error(
					"Village plan %d contains blocked tile %s" % [plan.village_id, tile]
				)
				continue
			_village_reserved_tiles[tile] = true
			map.set_grass_field(tile)
			# Players and normal spawn waves must begin outside guarded villages.
			spawnable_tiles.erase(tile)


func _plan_landmarks() -> void:
	if landmark_definitions.is_empty():
		return
	var available_tiles: Dictionary[Vector2i, bool] = {}
	for tile: Vector2i in walkable_tiles:
		available_tiles[tile] = true
	var planner: LandmarkPlanner = LandmarkPlanner.new()
	landmark_plans = planner.create_plans(
		Vector2i(map.width, map.height),
		landmark_definitions,
		Multihelper.mapSeed,
		available_tiles,
		_water_tiles,
		_village_reserved_tiles,
		biome_map_data
	)
	for plan: LandmarkPlan in landmark_plans:
		for tile: Vector2i in plan.reserved_tiles:
			_landmark_reserved_tiles[tile] = true
			spawnable_tiles.erase(tile)
			map.set_grass_field(tile)
			_water_tiles.erase(tile)
			if tile not in walkable_tiles:
				walkable_tiles.append(tile)


func _plan_world_events() -> void:
	if world_event_definitions.is_empty():
		return
	var available_tiles: Dictionary[Vector2i, bool] = {}
	for tile: Vector2i in walkable_tiles:
		available_tiles[tile] = true
	var blocked_tiles: Dictionary[Vector2i, bool] = {}
	for tile: Vector2i in _landmark_reserved_tiles:
		blocked_tiles[tile] = true
	for tile: Vector2i in _village_reserved_tiles:
		blocked_tiles[tile] = true
	var planner: WorldEventPlanner = WorldEventPlanner.new()
	world_event_plans = planner.create_plans(
		Vector2i(map.width, map.height),
		world_event_definitions,
		Multihelper.mapSeed,
		available_tiles,
		blocked_tiles,
		village_plans,
		minimum_world_events,
		maximum_world_events
	)
	for plan: WorldEventPlan in world_event_plans:
		for tile: Vector2i in plan.get_reserved_tiles(Vector2i(map.width, map.height)):
			_world_event_reserved_tiles[tile] = true
			spawnable_tiles.erase(tile)
			_tree_candidate_tiles.erase(tile)


func _plan_secret_locations() -> void:
	if secret_definitions.is_empty():
		return
	var walkable_index: Dictionary[Vector2i, bool] = {}
	for tile: Vector2i in walkable_tiles:
		walkable_index[tile] = true
	var blocked_tiles: Dictionary[Vector2i, bool] = {}
	for tile: Vector2i in _landmark_reserved_tiles:
		blocked_tiles[tile] = true
	for tile: Vector2i in _village_reserved_tiles:
		blocked_tiles[tile] = true
	for tile: Vector2i in _world_event_reserved_tiles:
		blocked_tiles[tile] = true
	var planner: SecretLocationPlanner = SecretLocationPlanner.new()
	secret_location_plans = planner.create_plans(
		Vector2i(map.width, map.height),
		secret_definitions,
		Multihelper.mapSeed,
		walkable_index,
		_water_tiles,
		blocked_tiles,
		biome_map_data
	)
	for plan: SecretLocationPlan in secret_location_plans:
		for tile: Vector2i in plan.get_reserved_tiles():
			_secret_reserved_tiles[tile] = true
			spawnable_tiles.erase(tile)
			_tree_candidate_tiles.erase(tile)
		for tile: Vector2i in plan.terrain_blocked_tiles:
			_secret_terrain_blocked_tiles[tile] = true
		_apply_secret_terrain(plan)


func _apply_secret_terrain(plan: SecretLocationPlan) -> void:
	var floor_tiles: Array[Vector2i] = []
	floor_tiles.assign(plan.room_tiles)
	for tile: Vector2i in plan.access_building_tiles:
		if tile not in floor_tiles:
			floor_tiles.append(tile)
	for tile: Vector2i in [plan.entrance_tile, plan.exit_tile]:
		if tile not in floor_tiles:
			floor_tiles.append(tile)
	for tile: Vector2i in floor_tiles:
		if tile.x < 0 or tile.y < 0 or tile.x >= map.width or tile.y >= map.height:
			continue
		_water_tiles.erase(tile)
		if tile not in walkable_tiles:
			walkable_tiles.append(tile)
		spawnable_tiles.erase(tile)
		map.set_grass_field(tile)
	for tile: Vector2i in plan.terrain_blocked_tiles:
		if tile.x < 0 or tile.y < 0 or tile.x >= map.width or tile.y >= map.height:
			continue
		walkable_tiles.erase(tile)
		spawnable_tiles.erase(tile)
		_tree_candidate_tiles.erase(tile)
		_water_tiles[tile] = true
		map.tile_map.set_cell(tile, map.tileset_source, map.waterCoors[0], 0)


func _append_secret_cover_trees() -> void:
	var occupied: Dictionary[Vector2i, bool] = {}
	for spawn: TreeSpawnData in tree_spawn_data:
		occupied[spawn.tile] = true
	for plan: SecretLocationPlan in secret_location_plans:
		for tile: Vector2i in plan.cover_tree_tiles:
			if occupied.has(tile):
				continue
			tree_spawn_data.append(TreeSpawnData.new(tile, "tree0"))
			occupied[tile] = true


func _carve_paths_between_regions() -> void:
	var destinations: Array[Vector2i] = []
	for plan: VillagePlan in village_plans:
		destinations.append(plan.bounds.position + Vector2i(
			floori(float(plan.bounds.size.x) / 2.0),
			floori(float(plan.bounds.size.y) / 2.0)
		))
	for plan: LandmarkPlan in landmark_plans:
		destinations.append(plan.center_tile)
	if destinations.is_empty():
		return
	var connected_tile: Vector2i = Vector2i(
		floori(float(map.width) / 2.0),
		floori(float(map.height) / 2.0)
	)
	_make_path_tile_walkable(connected_tile)
	var path_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	path_rng.seed = Multihelper.mapSeed ^ 0x50415448
	for destination: Vector2i in destinations:
		_carve_axis_path(connected_tile, destination, path_rng.randf() < 0.5)
		connected_tile = destination


func _carve_axis_path(
		from_tile: Vector2i,
		to_tile: Vector2i,
		horizontal_first: bool
	) -> void:
	var cursor: Vector2i = from_tile
	_make_path_area_walkable(cursor)
	if horizontal_first:
		while cursor.x != to_tile.x:
			cursor.x += signi(to_tile.x - cursor.x)
			_make_path_area_walkable(cursor)
		while cursor.y != to_tile.y:
			cursor.y += signi(to_tile.y - cursor.y)
			_make_path_area_walkable(cursor)
	else:
		while cursor.y != to_tile.y:
			cursor.y += signi(to_tile.y - cursor.y)
			_make_path_area_walkable(cursor)
		while cursor.x != to_tile.x:
			cursor.x += signi(to_tile.x - cursor.x)
			_make_path_area_walkable(cursor)


func _make_path_area_walkable(center_tile: Vector2i) -> void:
	for y_offset: int in range(-path_half_width_tiles, path_half_width_tiles + 1):
		for x_offset: int in range(-path_half_width_tiles, path_half_width_tiles + 1):
			if absi(x_offset) + absi(y_offset) > path_half_width_tiles:
				continue
			_make_path_tile_walkable(center_tile + Vector2i(x_offset, y_offset))


func _make_path_tile_walkable(tile: Vector2i) -> void:
	if tile.x < 0 or tile.y < 0 or tile.x >= map.width or tile.y >= map.height:
		return
	if _secret_terrain_blocked_tiles.has(tile):
		return
	_water_tiles.erase(tile)
	_tree_candidate_tiles.erase(tile)
	if tile not in walkable_tiles:
		walkable_tiles.append(tile)
	if not _village_reserved_tiles.has(tile) \
			and not _landmark_reserved_tiles.has(tile) \
			and not _world_event_reserved_tiles.has(tile) \
			and not _secret_reserved_tiles.has(tile) \
			and tile not in spawnable_tiles:
		spawnable_tiles.append(tile)
	map.set_biome_path_field(tile)


func _get_tree_limit(candidate_count: int) -> int:
	var result: int = candidate_count
	if max_tree_map_ratio > 0.0:
		var area_limit: int = ceili(float(map.width * map.height) * max_tree_map_ratio)
		result = mini(result, area_limit)
	if max_trees_per_map > 0:
		result = mini(result, max_trees_per_map)
	return maxi(result, 0)


func _shuffle_tiles(tiles: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for index in range(tiles.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var temporary: Vector2i = tiles[index]
		tiles[index] = tiles[swap_index]
		tiles[swap_index] = temporary
	
