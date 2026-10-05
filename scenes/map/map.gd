extends Control
class_name Map

signal navigation_changed(revision: int)
signal generation_started()

var grassAtlasCoords = [Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(3,0),Vector2i(16,0),Vector2i(17,0)]
var waterCoors 		 = [Vector2i(18,0), Vector2i(19,0)]
var startFieldCoords = [Vector2i(23,4)]
var blockFieldCoords = [Vector2i(20,4)]
var treeCoors 		 = Vector2i(17,0)

#var blockStoneCoors = [Vector2i(6,0),Vector2i(7,0),Vector2i(8,0),Vector2i(9,0), Vector2i(10,0)]

var tileset_source = 1
# Noise parameters
#var tile_size = 64
var width = Constants.MAP_SIZE.x
var height = Constants.MAP_SIZE.y


@onready var enemies : Node2D  
@onready var animals : Node2D 
#@export var tile_map : TileMapLayer 
var tile_map : TileMapLayer 

var map_type : Node
var spawnPosition = Vector2i(0,0)
var endPosition = Vector2i(-10,-10)
var walkable_tiles: Array[Vector2i] = []
var spawnable_tiles: Array[Vector2i] = []

var level_type = -1
var level_no : int = -1

# A single shared grid describes terrain and persistent world obstacles. Moving
# actors use the lightweight occupancy/reservation dictionaries below instead
# of mutating the AStar graph for every step.
var astar_grid := AStarGrid2D.new()
var astar_ready := false
var navigation_blockers: Dictionary = {}
var navigation_reservations: Dictionary = {}
var navigation_occupants: Dictionary = {}
var navigation_moves: Dictionary = {}
var navigation_destinations: Dictionary = {}
var navigation_revision := 0
var navigation_generation := 0
var navigation_path_queries := 0
@export var debug_navigation := false

func _ready():
	print("Map ready")
	enemies = get_tree().get_first_node_in_group("enemies_root")
	animals = get_tree().get_first_node_in_group("animals_root")
	
	
func generateMap(level_dict : Dictionary):
	print("generated:"+str(level_dict))
	generation_started.emit()
	var main_generator := get_node_or_null("MainLevelGenerator")
	if main_generator:
		main_generator.clear_generated_objects()
	level_no 	= level_dict["level"]
	level_type 	= level_dict["type"]
	tile_map 		 = $TileMap
	tile_map.visible = true
	tile_map.clear()
	var requested_size: Vector2i = level_dict.get("size", Constants.MAP_SIZE)
	width = requested_size.x
	height = requested_size.y
	walkable_tiles.clear()
	spawnable_tiles.clear()
	spawnPosition = Vector2i.ZERO
	endPosition = Vector2i(-10, -10)
	_reset_navigation_state()
	
	if level_type == Constants.MAP_MAIN:
		map_type  		=  get_node_or_null("MainLevelGenerator")
		var tiles: Array = map_type.generateMainMap(level_dict)
		walkable_tiles = tiles[0]
		spawnable_tiles = tiles[1]
		set_level_options(level_no)
	elif level_type == Constants.MAP_LABY:
		map_type  		 =  get_node_or_null("LabyrinthGenerator")
		walkable_tiles 	 = map_type.generateLabyrinth(level_no)
	elif level_type == Constants.MAP_TOURMENT:
		map_type  		=  get_node_or_null("LabyrinthGenerator")
		walkable_tiles 	= map_type.generateLabyrinthWithSeed(level_no+15,42+level_no)
	elif level_type == Constants.MAP_KI:
		map_type  		=  get_node_or_null("MainLevelGenerator")
		var tiles: Array = map_type.generateMainMap(level_dict)
		walkable_tiles = tiles[0]
		spawnable_tiles = tiles[1]
	else:
		push_warning("Unsupported map type: %s" % level_type)
		return

	if spawnable_tiles.is_empty():
		spawnable_tiles = walkable_tiles.duplicate()
	rebuild_navigation_grid()


func _reset_navigation_state() -> void:
	astar_ready = false
	astar_grid.clear()
	navigation_generation += 1
	navigation_blockers.clear()
	navigation_reservations.clear()
	navigation_occupants.clear()
	navigation_moves.clear()
	navigation_destinations.clear()
	navigation_path_queries = 0


func rebuild_navigation_grid() -> void:
	astar_ready = false
	astar_grid.clear()
	astar_grid.region = _get_navigation_region()
	astar_grid.cell_size = Vector2(Constants.TILE_SIZE, Constants.TILE_SIZE)
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar_grid.update()
	astar_grid.fill_solid_region(astar_grid.region, true)

	for tile: Vector2i in walkable_tiles:
		if astar_grid.is_in_boundsv(tile):
			astar_grid.set_point_solid(tile, false)
	for tile: Vector2i in navigation_blockers:
		if astar_grid.is_in_boundsv(tile):
			astar_grid.set_point_solid(tile, true)

	astar_ready = true
	_bump_navigation_revision()


func _get_navigation_region() -> Rect2i:
	var minimum := Vector2i.ZERO
	var maximum := Vector2i(maxi(width - 1, 0), maxi(height - 1, 0))
	for tile: Vector2i in walkable_tiles:
		minimum.x = mini(minimum.x, tile.x)
		minimum.y = mini(minimum.y, tile.y)
		maximum.x = maxi(maximum.x, tile.x)
		maximum.y = maxi(maximum.y, tile.y)
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


func world_to_navigation_tile(global_pos: Vector2) -> Vector2i:
	return tile_map.local_to_map(tile_map.to_local(global_pos))


func navigation_tile_to_world(tile: Vector2i) -> Vector2:
	return tile_map.to_global(tile_map.map_to_local(tile))


func is_navigation_tile_in_bounds(tile: Vector2i) -> bool:
	return astar_ready and astar_grid.is_in_boundsv(tile)


func is_navigation_tile_walkable(
		tile: Vector2i,
		include_actor_occupancy := false,
		except_actor_id := -1
	) -> bool:
	if not is_navigation_tile_in_bounds(tile) or astar_grid.is_point_solid(tile):
		return false
	if not include_actor_occupancy:
		return true
	return not is_navigation_tile_reserved(tile, except_actor_id) \
		and not is_navigation_tile_occupied(tile, except_actor_id)


func get_navigation_path(from_tile: Vector2i, to_tile: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not is_navigation_tile_walkable(from_tile) \
			or not is_navigation_tile_walkable(to_tile):
		return result
	navigation_path_queries += 1
	for point: Vector2i in astar_grid.get_id_path(from_tile, to_tile, false):
		result.append(point)
	if debug_navigation:
		print("Navigation path ", from_tile, " -> ", to_tile, ": ", result)
	return result


func get_navigation_path_avoiding_actors(
		from_tile: Vector2i,
		to_tile: Vector2i,
		actor_id: int
	) -> Array[Vector2i]:
	var temporary_solids: Array[Vector2i] = []
	var actor_tiles: Array[Vector2i] = []
	for tile: Vector2i in navigation_occupants.keys():
		if navigation_occupants[tile] != actor_id:
			actor_tiles.append(tile)
	for tile: Vector2i in navigation_reservations.keys():
		if navigation_reservations[tile] != actor_id and tile not in actor_tiles:
			actor_tiles.append(tile)
	for tile: Vector2i in navigation_destinations.keys():
		if navigation_destinations[tile] != actor_id and tile not in actor_tiles:
			actor_tiles.append(tile)

	for tile in actor_tiles:
		if tile == from_tile or tile == to_tile:
			continue
		if is_navigation_tile_walkable(tile):
			astar_grid.set_point_solid(tile, true)
			temporary_solids.append(tile)
	var result := get_navigation_path(from_tile, to_tile)
	for tile in temporary_solids:
		if not navigation_blockers.has(tile):
			astar_grid.set_point_solid(tile, false)
	return result


func get_attack_destination(
		enemy_tile: Vector2i,
		player_tile: Vector2i,
		actor_id: int,
		desired_range_tiles := 1
	) -> Vector2i:
	var radius := maxi(desired_range_tiles, 1)
	var candidates: Array[Vector2i] = []
	for x_offset in range(-radius, radius + 1):
		var y_offset := radius - absi(x_offset)
		candidates.append(player_tile + Vector2i(x_offset, y_offset))
		if y_offset != 0:
			candidates.append(player_tile + Vector2i(x_offset, -y_offset))

	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return enemy_tile.distance_squared_to(a) < enemy_tile.distance_squared_to(b)
	)
	for candidate in candidates:
		if not is_navigation_tile_walkable(candidate, true, actor_id):
			continue
		var path := get_navigation_path_avoiding_actors(enemy_tile, candidate, actor_id)
		if not path.is_empty():
			return candidate
	return Vector2i(-1, -1)


func add_navigation_blocker(tile: Vector2i) -> void:
	navigation_blockers[tile] = int(navigation_blockers.get(tile, 0)) + 1
	if astar_ready and astar_grid.is_in_boundsv(tile):
		astar_grid.set_point_solid(tile, true)
		_bump_navigation_revision()


func remove_navigation_blocker(tile: Vector2i) -> void:
	if not navigation_blockers.has(tile):
		return
	navigation_blockers[tile] = int(navigation_blockers[tile]) - 1
	if navigation_blockers[tile] <= 0:
		navigation_blockers.erase(tile)
		if astar_ready and astar_grid.is_in_boundsv(tile) and tile in walkable_tiles:
			astar_grid.set_point_solid(tile, false)
	if astar_ready:
		_bump_navigation_revision()


func register_navigation_actor(actor_id: int, tile: Vector2i) -> bool:
	if not is_navigation_tile_walkable(tile):
		return false
	var occupant := int(navigation_occupants.get(tile, actor_id))
	if occupant != actor_id:
		return false
	navigation_occupants[tile] = actor_id
	return true


func try_reserve_navigation_step(
		from_tile: Vector2i,
		to_tile: Vector2i,
		actor_id: int
	) -> bool:
	if not is_navigation_tile_walkable(to_tile):
		return false
	if is_navigation_tile_occupied(to_tile, actor_id) \
			or is_navigation_tile_reserved(to_tile, actor_id):
		return false

	var existing_move: Dictionary = navigation_moves.get(actor_id, {})
	if not existing_move.is_empty() and existing_move.get("to") == to_tile:
		return true
	cancel_navigation_step(actor_id)
	navigation_reservations[to_tile] = actor_id
	navigation_moves[actor_id] = {"from": from_tile, "to": to_tile}
	return true


func commit_navigation_step(actor_id: int, reached_tile: Vector2i) -> void:
	var move: Dictionary = navigation_moves.get(actor_id, {})
	if not move.is_empty():
		var old_tile: Vector2i = move["from"]
		if navigation_occupants.get(old_tile) == actor_id:
			navigation_occupants.erase(old_tile)
		var reserved_tile: Vector2i = move["to"]
		if navigation_reservations.get(reserved_tile) == actor_id:
			navigation_reservations.erase(reserved_tile)
		navigation_moves.erase(actor_id)
	navigation_occupants[reached_tile] = actor_id


func cancel_navigation_step(actor_id: int) -> void:
	var move: Dictionary = navigation_moves.get(actor_id, {})
	if move.is_empty():
		return
	var reserved_tile: Vector2i = move["to"]
	if navigation_reservations.get(reserved_tile) == actor_id:
		navigation_reservations.erase(reserved_tile)
	navigation_moves.erase(actor_id)


func release_navigation_actor(actor_id: int) -> void:
	cancel_navigation_step(actor_id)
	release_navigation_destination(actor_id)
	for tile: Vector2i in navigation_occupants.keys():
		if navigation_occupants[tile] == actor_id:
			navigation_occupants.erase(tile)


func is_navigation_tile_reserved(tile: Vector2i, except_actor_id := -1) -> bool:
	var step_reserved := navigation_reservations.has(tile) \
		and navigation_reservations[tile] != except_actor_id
	var destination_reserved := navigation_destinations.has(tile) \
		and navigation_destinations[tile] != except_actor_id
	return step_reserved or destination_reserved


func is_navigation_tile_occupied(tile: Vector2i, except_actor_id := -1) -> bool:
	return navigation_occupants.has(tile) \
		and navigation_occupants[tile] != except_actor_id


func try_claim_navigation_destination(tile: Vector2i, actor_id: int) -> bool:
	if not is_navigation_tile_walkable(tile, true, actor_id):
		return false
	release_navigation_destination(actor_id)
	navigation_destinations[tile] = actor_id
	return true


func release_navigation_destination(actor_id: int) -> void:
	for tile: Vector2i in navigation_destinations.keys():
		if navigation_destinations[tile] == actor_id:
			navigation_destinations.erase(tile)


func set_navigation_terrain_tile(tile: Vector2i, walkable: bool) -> void:
	if walkable:
		if tile not in walkable_tiles:
			walkable_tiles.append(tile)
	else:
		walkable_tiles.erase(tile)
	if astar_ready and astar_grid.is_in_boundsv(tile):
		var blocked := not walkable or navigation_blockers.has(tile)
		astar_grid.set_point_solid(tile, blocked)
	_bump_navigation_revision()


func _bump_navigation_revision() -> void:
	navigation_revision += 1
	navigation_changed.emit(navigation_revision)


func debug_print_path(from_tile: Vector2i, to_tile: Vector2i) -> void:
	var path := get_navigation_path(from_tile, to_tile)
	print("Navigation path ", from_tile, " -> ", to_tile, " (", path.size(), "): ", path)





func full_terrain_with_water_fields():
	var rng = RandomNumberGenerator.new()
	rng.seed = Multihelper.mapSeed 
	var tile_coord = Vector2i()
	for y in range(height):
		for x in range(width):
			tile_coord = waterCoors[rng.randi() % waterCoors.size()]
			tile_map.set_cell(Vector2i(x, y), tileset_source, tile_coord, 0)

func generate_borders():
	var rng = RandomNumberGenerator.new()
	rng.seed = Multihelper.mapSeed
	var edge_x = -1
	var edge_x2 = width
	var tile_coord = Vector2i()
	for y in range(-1,height+1):
		tile_coord = waterCoors[rng.randi() % waterCoors.size()]
		tile_map.set_cell( Vector2i(edge_x, y), tileset_source, tile_coord, 0)
		tile_map.set_cell( Vector2i(edge_x2, y), tileset_source, tile_coord, 0)
		
	var edge_y = -1
	var edge_y2 = height
	for x2 in range(-1,width+1):
		tile_coord = waterCoors[rng.randi() % waterCoors.size()]
		tile_map.set_cell( Vector2i(x2, edge_y), tileset_source, tile_coord, 0)
		tile_map.set_cell( Vector2i(x2, edge_y2), tileset_source, tile_coord, 0)

func set_grass_field(tile_place : Vector2i ):
	var rng = RandomNumberGenerator.new()
	rng.seed = Multihelper.mapSeed + tile_place.x + tile_place.y # Deterministic but varies by position
	var tile_coord = grassAtlasCoords[rng.randi() % grassAtlasCoords.size()]
	tile_coord = Vector2i(0,0)
	tile_map.set_cell( tile_place, tileset_source, tile_coord, 0)

func set_field(tile_place : Vector2i, atlasCoor : Vector2i ):
	tile_map.set_cell( tile_place, tileset_source, atlasCoor, 0)

func set_level_options(level : int):
	#print("set level options:"+str(level))
	if not is_instance_valid(enemies):
		enemies = get_tree().get_first_node_in_group("enemies_root")
	if not is_instance_valid(animals):
		animals = get_tree().get_first_node_in_group("animals_root")
	if enemies == null or animals == null:
		return
	
	if level == 0:
		enemies.maxEnemiesPerPlayer = 0
		animals.maxAnimalsPerPlayer  = 0
		
	if level == 1:
		enemies.maxEnemiesPerPlayer = 0
		animals.maxAnimalsPerPlayer  = 25
		
	if level == 2:
		enemies.maxEnemiesPerPlayer = 1
		animals.maxAnimalsPerPlayer  = 6



func get_walkable_tiles2(
		layer: TileMapLayer,
		grass_atlas_coords
	) :

	var walkable_tiles_tmp = []

	for cell in layer.get_used_cells():
		var atlas := layer.get_cell_atlas_coords(cell)

		if atlas in grass_atlas_coords:
			walkable_tiles_tmp.append(cell)

	return walkable_tiles_tmp
