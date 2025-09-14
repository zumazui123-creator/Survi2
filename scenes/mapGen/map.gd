extends Node2D

var grassAtlasCoords = [Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(3,0),Vector2i(16,0),Vector2i(17,0)]
var waterCoors = [Vector2i(18,0), Vector2i(19,0)]
var blockStoneCoors = [Vector2i(6,0),Vector2i(7,0),Vector2i(8,0),Vector2i(9,0), Vector2i(10,0)]
var noise = FastNoiseLite.new()
var tileset_source = 1

# Noise parameters
var tile_size = 64
var map_width = Constants.MAP_SIZE.x
var map_height = Constants.MAP_SIZE.y

var walkable_tiles = []
@onready var tile_map = $TileMap


	
func generateMap():
	noise.seed = Multihelper.mapSeed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.fractal_octaves = 1.1
	noise.fractal_lacunarity = 1.0 #2.0
	noise.frequency = 0.03
	generate_terrain()
	generate_borders()
	
func generate_terrain():
	for y in range(map_height):
		for x in range(map_width):
			var noise_value = noise.get_noise_2d(x, y)
			var tile_coord = Vector2i()
			if noise_value < 0.13:
				tile_coord = grassAtlasCoords.pick_random()
				tile_map.set_cell(Vector2i(x, y), tileset_source, tile_coord, 0)
				walkable_tiles.append(Vector2i(x,y))
			else:
				tile_coord = waterCoors.pick_random()
				tile_map.set_cell(Vector2i(x, y), tileset_source, tile_coord, 0)

func generate_borders():
	var edge_x = -1
	var edge_x2 = map_height
	var tile_coord = Vector2i()
	for y in range(-1,map_height+1):
		tile_coord = waterCoors.pick_random()
		tile_map.set_cell(Vector2i(edge_x, y), tileset_source, tile_coord, 0)
		tile_map.set_cell(Vector2i(edge_x2, y), tileset_source, tile_coord, 0)
		
	var edge_y = -1
	var edge_y2 = map_width
	for x2 in range(-1,map_width+1):
		tile_coord = waterCoors.pick_random()
		tile_map.set_cell(Vector2i(x2, edge_y), tileset_source, tile_coord, 0)
		tile_map.set_cell(Vector2i(x2, edge_y2), tileset_source, tile_coord, 0)
