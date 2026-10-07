extends Node

@export_group("Tree placement")
@export_range(1, 8, 1) var tree_spacing_tiles: int = 2
@export_range(0, 100000, 1) var max_trees_per_map: int = 1000
@export_range(0.0, 1.0, 0.001) var max_tree_map_ratio: float = 0.02

@onready var map : Map = $".."

var walkable_tiles: Array[Vector2i] = []
var spawnable_tiles: Array[Vector2i] = []
var tree_spawn_data: Array[TreeSpawnData] = []
var _tree_candidate_blocks: Dictionary = {}
var noise = FastNoiseLite.new()

func generateMainMap(levelData : Dictionary):
	walkable_tiles.clear()
	spawnable_tiles.clear()
	tree_spawn_data.clear()
	_tree_candidate_blocks.clear()
	generate_terrain(levelData)
	_select_tree_spawns()
	map.set_level_options(1)
	map.generate_borders()
	return [walkable_tiles, spawnable_tiles, tree_spawn_data]
	
func generate_terrain(levelData : Dictionary):
	
	print("generate_terrain with seed: ", Multihelper.mapSeed)
	var rng = RandomNumberGenerator.new()
	rng.seed = Multihelper.mapSeed
	
	noise.seed = Multihelper.mapSeed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.fractal_octaves = 1.1
	noise.fractal_lacunarity = 1.0 #2.0
	noise.frequency = 0.03
	if "size" in levelData:
		map.width = levelData["size"].x
		map.height = levelData["size"].y
	
	for y in range(map.height):
		for x in range(map.width):
			var noise_value = noise.get_noise_2d(x, y)
			var tile_coord = Vector2i()
			var tile: Vector2i = Vector2i(x, y)
			if noise_value < 0.13:
				tile_coord = map.grassAtlasCoords[rng.randi() % map.grassAtlasCoords.size()]
				walkable_tiles.append(tile)
				spawnable_tiles.append(tile)
				
			elif noise_value > 0.13 and noise_value < 0.40 : 
				tile_coord = map.treeCoors
				walkable_tiles.append(tile)
				_add_tree_candidate(tile)
				
			else:
				tile_coord = map.waterCoors[rng.randi() % map.waterCoors.size()]
			map.tile_map.set_cell(tile, map.tileset_source, tile_coord, 0)


func _add_tree_candidate(tile: Vector2i) -> void:
	var spacing: int = maxi(tree_spacing_tiles, 1)
	var block: Vector2i = Vector2i(
		floori(float(tile.x) / float(spacing)),
		floori(float(tile.y) / float(spacing))
	)
	var candidates: Array = _tree_candidate_blocks.get(block, [])
	candidates.append(tile)
	_tree_candidate_blocks[block] = candidates


func _select_tree_spawns() -> void:
	var tree_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	tree_rng.seed = Multihelper.mapSeed ^ 0x54524545
	var selected_tiles: Array[Vector2i] = []

	# Each spacing block contributes at most one randomly selected forest tile.
	for candidates_value: Variant in _tree_candidate_blocks.values():
		var candidates: Array = candidates_value
		if candidates.is_empty():
			continue
		var selected_index: int = tree_rng.randi_range(0, candidates.size() - 1)
		var selected_tile: Vector2i = candidates[selected_index]
		selected_tiles.append(selected_tile)

	_shuffle_tiles(selected_tiles, tree_rng)
	var tree_limit: int = _get_tree_limit(selected_tiles.size())
	if selected_tiles.size() > tree_limit:
		selected_tiles.resize(tree_limit)
	selected_tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)

	for tile: Vector2i in selected_tiles:
		tree_spawn_data.append(TreeSpawnData.new(tile))


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
	
