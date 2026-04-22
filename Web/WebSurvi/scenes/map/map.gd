extends Control
class_name Map

var grassAtlasCoords = [Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(3,0),Vector2i(16,0),Vector2i(17,0)]
var waterCoors 		 = [Vector2i(18,0), Vector2i(19,0)]
var startFieldCoords = [Vector2i(23,4)]
var blockFieldCoords = [Vector2i(20,4)]
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
var walkable_tiles = []

var level_type = -1
var level_no : int = -1

func _ready():
	print("Map ready")
	enemies	= get_node_or_null("%Enemies")
	animals	= get_node_or_null("%Animals")
	
	
func generateMap(level_dict : Dictionary):
	print("generated:"+str(level_dict))
	level_no 	= level_dict["level"]
	level_type 	= level_dict["type"]
	
	if level_type == Constants.MAP_MAIN:
		var random_level = $MainLevelGenerator
		tile_map 		 = $TileMap
		tile_map.visible = true
		random_level.generateMainMap(level_dict)
		walkable_tiles 	= get_walkable_tiles(tile_map, grassAtlasCoords)
		set_level_options(level_no)
		return 
			
		#if level_no > 0:
			#var level_path : String = "res://scenes/map/levels/level"+str(level_no)+".tscn"
			#var scene : PackedScene	= load(level_path)
			#var level_main : Node	= scene.instantiate()
			#walkable_tiles 	= get_walkable_tiles(level_main.layer, grassAtlasCoords)
			#tile_map = level_main.layer
			#set_level_options(0)
			#add_child(level_main)
			

	if level_type == Constants.MAP_LABY:
		if level_no % 2 == 0:
			tile_map 		 = $TileMap
			tile_map.visible = true
			map_type  		 =  get_node_or_null("Labyrinth")
			walkable_tiles 	 = map_type.generateLabyrinth(level_no)
		
	if level_type == Constants.MAP_TOURMENT:
		tile_map 		 = $TileMap
		tile_map.visible = true
		map_type  		=  get_node_or_null("Labyrinth")
		walkable_tiles 	= map_type.generateLabyrinthWithSeed(level_no+15,42+level_no)
		
	if level_type == Constants.MAP_KI:
		tile_map 		 = $TileMap
		tile_map.visible = true
		map_type  		=  get_node_or_null("MainLevel")
		walkable_tiles 	= map_type.generateMainMap(0)





func full_terrain_with_water_fields():
	var rng = RandomNumberGenerator.new()
	rng.seed = Multihelper.mapSeed 
	var tile_coord = Vector2i()
	for y in range(height):
		for x in range(width):
			tile_coord = waterCoors[rng.randi() % waterCoors.size()]
			Multihelper.map.tile_map.set_cell(Vector2i(x, y), tileset_source, tile_coord, 0)

func generate_borders():
	var rng = RandomNumberGenerator.new()
	rng.seed = Multihelper.mapSeed
	var edge_x = -1
	var edge_x2 = height
	var tile_coord = Vector2i()
	for y in range(-1,height+1):
		tile_coord = waterCoors[rng.randi() % waterCoors.size()]
		tile_map.set_cell( Vector2i(edge_x, y), tileset_source, tile_coord, 0)
		tile_map.set_cell( Vector2i(edge_x2, y), tileset_source, tile_coord, 0)
		
	var edge_y = -1
	var edge_y2 = width
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
	
	if level == 0:
		enemies.maxEnemiesPerPlayer = 0
		animals.maxAnimalsPerPlayer  = 0
		
	if level == 1:
		enemies.maxEnemiesPerPlayer = 0
		animals.maxAnimalsPerPlayer  = 25
		
	if level == 2:
		enemies.maxEnemiesPerPlayer = 1
		animals.maxAnimalsPerPlayer  = 6



func get_walkable_tiles(
		layer: TileMapLayer,
		grass_atlas_coords
	) :

	var walkable_tiles_tmp = []

	for cell in layer.get_used_cells():
		var atlas := layer.get_cell_atlas_coords(cell)

		if atlas in grass_atlas_coords:
			walkable_tiles_tmp.append(cell)

	return walkable_tiles_tmp
