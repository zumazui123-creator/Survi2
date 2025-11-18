extends Control

var grassAtlasCoords = [Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(3,0),Vector2i(16,0),Vector2i(17,0)]
var waterCoors = [Vector2i(18,0), Vector2i(19,0)]
#var blockStoneCoors = [Vector2i(6,0),Vector2i(7,0),Vector2i(8,0),Vector2i(9,0), Vector2i(10,0)]
var noise = FastNoiseLite.new()
var tileset_source = 1

# Noise parameters
#var tile_size = 64
var map_width = Constants.MAP_SIZE.x
var map_height = Constants.MAP_SIZE.y


@onready var enemies : Node2D  
@onready var animals : Node2D 
@onready var tile_map : TileMapLayer 
@onready var laby_map : Node 

var walkable_tiles = []
var level_type = -1

func _ready():
	print("Map ready")
	enemies = get_node_or_null("%Enemies")
	animals  = get_node_or_null("%Animals" )
	tile_map  = get_node_or_null("TileMap")
	laby_map  =  get_node_or_null("Labyrinth")
	
func generateMap(level_dict : Dictionary):
	print("generated:"+str(level_dict))
	var level_no = level_dict["level"]
	level_type = level_dict["type"]
	if level_type == Constants.MAP_MAIN:
		generateMainMap(level_no)
		
	if level_type == Constants.MAP_LABY:
		walkable_tiles = laby_map.generateLabyrinth(level_no)
		
	if level_type == Constants.MAP_TOURMENT:
		walkable_tiles = laby_map.generateLabyrinthWithSeed(level_no+15,42+level_no)
		
	if level_type == Constants.MAP_KI:
		generateMainMap(0)



func generateMainMap(level_no: int):
	print("gen. level "+str(level_no))
	generate_terrain()
	set_level_options(level_no)
	generate_borders()
	

	
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
		tile_map.set_cell( Vector2i(edge_x, y), tileset_source, tile_coord, 0)
		tile_map.set_cell( Vector2i(edge_x2, y), tileset_source, tile_coord, 0)
		
	var edge_y = -1
	var edge_y2 = map_width
	for x2 in range(-1,map_width+1):
		tile_coord = waterCoors.pick_random()
		tile_map.set_cell( Vector2i(x2, edge_y), tileset_source, tile_coord, 0)
		tile_map.set_cell( Vector2i(x2, edge_y2), tileset_source, tile_coord, 0)



func set_grass_field(tile_place : Vector2i ):
	var tile_coord = grassAtlasCoords.pick_random()
	tile_coord = Vector2i(0,0)
	tile_map.set_cell( tile_place, tileset_source, tile_coord, 0)

	
func set_field(tile_place : Vector2i, atlasCoor : Vector2i ):
	tile_map.set_cell( tile_place, tileset_source, atlasCoor, 0)



	
func set_level_options(level : int):
	#print("set level options:"+str(level))
	
	if level == 0:
		enemies.maxEnemiesPerPlayer = 0
		animals.maxAnimalsPerPlayer  = 0
		
	if level == 1:
		enemies.maxEnemiesPerPlayer = 0
		animals.maxAnimalsPerPlayer  = 25
		
	if level == 2:
		enemies.maxEnemiesPerPlayer = 25
		animals.maxAnimalsPerPlayer  = 6
		
