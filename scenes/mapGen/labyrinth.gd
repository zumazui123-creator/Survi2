extends Node

@onready var map = $".."
@onready var animals = $"../../Animals"

var walkable_tiles : Array[Vector2i] = []
var spawnPosition = Vector2i(0,0)
var endPosition = Vector2i(-10,-10)
var randomDirection : Array[Vector2i] = [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]
var moduleNumber = [2,3,5,7,11,13]
var atlasCoorWhiteField = Vector2i(11,0)


func generateLabyrinth( level_no : int) -> Array[Vector2i] : 
	var way_size = 5
	var level_hard_count = level_no+5
	if level_no > 10:
		level_hard_count += 10
		way_size = 7
	if level_no > 20:
		level_hard_count += 15
		way_size = 10
	Multihelper.setMobs(0,0,0,0)
	map.full_terrain_with_water_fields()
	walkable_tiles = []

	var walkVec = Vector2i(int(map.map_height/2),int(map.map_width/2)) 
	var randomVec = Vector2i()
	for tile in range(level_hard_count): 
		
		randomVec = randomDirection.pick_random()
		var wide = randi() % way_size
		for i in range(wide):
			walkVec += randomVec
			#print("tile:"+str(tile)+str(walkVec))
			map.set_grass_field(walkVec)
			walkable_tiles.append(walkVec)
		
	spawnPosition = walkable_tiles[0]
	endPosition = walkable_tiles[-1]
	map.set_field(endPosition, atlasCoorWhiteField)
	return walkable_tiles
	
func generateLabyrinthWithSeed( level_no : int, seed : int)-> Array[Vector2i]: 
	seed(seed)
	var way_size = 5
	var level_hard_count = level_no+5
	if level_no > 10:
		level_hard_count += 10
		way_size = 7
	if level_no > 20:
		level_hard_count += 15
		way_size = 10
	Multihelper.setMobs(0,0,0,5)
	map.full_terrain_with_water_fields()
	walkable_tiles = []

	var walkVec = Vector2i(int(map.map_height/2),int(map.map_width/2)) 
	var randomVec = Vector2i()
	for tile in range(level_hard_count): 
		randomVec = randomDirection.pick_random()
		var wide = randi() % way_size
		for i in range(wide):
			walkVec += randomVec
			map.set_grass_field(walkVec)
			var animal = animals.spawn(walkVec)
			animals.add_child(animal)
			walkable_tiles.append(walkVec)
		
	spawnPosition = walkable_tiles[0]
	endPosition = walkable_tiles[-1]
	map.set_field(endPosition, atlasCoorWhiteField)
	return walkable_tiles
	

func set_random_mobs(free_tiles: Array[Vector2i]):
	print("set mob rand")
	
