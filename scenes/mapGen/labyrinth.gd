extends Node

@onready var map = $".."

var walkable_tiles = []
var spawnPosition = Vector2i(0,0)
var endPosition = Vector2i(0,0)
var randomDirection = [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]

func generateLabyrinth( tilesSize : int): 
	Multihelper.setMobs(0,0,0,0)
	map.full_terrain_with_water_fields()
	walkable_tiles = []
	var tile_coord = Vector2i()

	var walkVec = Vector2i(int(map.map_height/2),int(map.map_width/2)) 
	var randomVec = Vector2i()
	for tile in range(tilesSize): 
		
		randomVec = randomDirection.pick_random()
		var wide = randi() % 5
		for i in range(wide):
			walkVec += randomVec
			#print("tile:"+str(tile)+str(walkVec))
			map.set_grass_field(walkVec)
			walkable_tiles.append(walkVec)
		
	spawnPosition = walkable_tiles[0]
	endPosition = walkable_tiles[-1]
	return walkable_tiles
