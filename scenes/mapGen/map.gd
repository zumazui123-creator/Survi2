extends Node2D

var grassAtlasCoords = [Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(3,0),Vector2i(16,0),Vector2i(17,0)]
var waterCoors = [Vector2i(18,0), Vector2i(19,0)]
#var blockStoneCoors = [Vector2i(6,0),Vector2i(7,0),Vector2i(8,0),Vector2i(9,0), Vector2i(10,0)]
var noise = FastNoiseLite.new()
var tileset_source = 1



# Noise parameters
#var tile_size = 64
var map_width = Constants.MAP_SIZE.x
var map_height = Constants.MAP_SIZE.y

@onready var enemies = $"../Enemies"
@onready var animal = $"../Animal"


var walkable_tiles = []
@onready var tile_map = $TileMap
@onready var laby_map = $Labyrinth


func generateMap(level : int):
	print("generated:"+str(level))
	if level == 1:
		print("gen. level 1")
		generate_terrain()
		set_level_options(1)
		generate_borders()
	if level == 0: 
		walkable_tiles = laby_map.generateLabyrinth(1)
		
	




	
func generate_terrain():
	noise.seed = Multihelper.mapSeed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.fractal_octaves = 1.1
	noise.fractal_lacunarity = 1.0 #2.0
	noise.frequency = 0.03
	
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

func full_terrain_with_water_fields():
	var tile_coord = Vector2i()
	for y in range(map_height):
		for x in range(map_width):
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

func noneSpawnObjAndMobs():
	Constants.INITAL_OBJECTS 	= 0
	Constants.MAX_OBJECTS		= 0
	Constants.MAX_ENEMIES_PER_PLAYER = 0
	Constants.MAX_ANIMALS_PER_PLAYER = 0

func set_grass_field(tile_place : Vector2i ):
	var tile_coord = grassAtlasCoords.pick_random()
	tile_coord = Vector2i(0,0)
	tile_map.set_cell(tile_place, tileset_source, tile_coord, 0)
	walkable_tiles.append(tile_place)
	var src = tile_map.get_cell_source_id(tile_place)
	print("set grass field: "+str(src)+"  on:"+str(tile_place))
	
func set_level_options(level : int):
	print("set level options:"+str(level))
	
	if level == 0:
		enemies.maxEnemiesPerPlayer = 0
		animal.maxAnimalsPerPlayer  = 0
		
	if level == 1:
		enemies.maxEnemiesPerPlayer = 0
		animal.maxAnimalsPerPlayer  = 25
		
	if level == 2:
		enemies.maxEnemiesPerPlayer = 25
		animal.maxAnimalsPerPlayer  = 6
