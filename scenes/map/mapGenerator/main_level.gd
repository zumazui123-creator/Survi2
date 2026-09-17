extends Node


@onready var map : Map = $".."

var walkable_tiles = []
var spawnable_tiles = []
var noise = FastNoiseLite.new()

func generateMainMap(levelData : Dictionary):
	generate_terrain(levelData)
	map.set_level_options(1)
	map.generate_borders()
	return [ walkable_tiles, spawnable_tiles ]
	
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
			if noise_value < 0.13:
				tile_coord = map.grassAtlasCoords[rng.randi() % map.grassAtlasCoords.size()]
				walkable_tiles.append(Vector2i(x,y))
				spawnable_tiles.append(Vector2i(x,y))
				
			elif noise_value > 0.13 and noise_value < 0.40 : 
				tile_coord = map.treeCoors
				walkable_tiles.append(Vector2i(x,y))
				spawnTrees(Vector2i(x, y))
				
			else:
				tile_coord = map.waterCoors[rng.randi() % map.waterCoors.size()]
			map.tile_map.set_cell(Vector2i(x, y), map.tileset_source, tile_coord, 0)
				
func spawnTrees(spawnPos : Vector2i):
	var tile_map: TileMapLayer = map.tile_map
	var breakableScene := preload("res://scenes/spawn/object/tree.tscn")
	var breakable := breakableScene.instantiate()
	var objectId = Items.objects.get("tree0").get("id")
	self.add_child(breakable,true)
	breakable.objectId = objectId
	breakable.position = Multihelper.map.tile_map.map_to_local( spawnPos )
	
