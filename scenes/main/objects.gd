extends Node2D

var initialSpawnObjects := Constants.INITAL_OBJECTS
var maxObjects 	  		:= Constants.MAX_OBJECTS
var objectWaveCount 		:= 10
var spawnedObjects 	  	:= 0

func _ready() -> void:
	if Multihelper.level and "size" in Multihelper.level:
		var map_size = Multihelper.level["size"]
		var scale_factor = sqrt(map_size.x * map_size.y) / sqrt(Constants.MAP_SIZE.x * Constants.MAP_SIZE.y)
		maxObjects = int(Constants.MAX_OBJECTS * scale_factor)
		objectWaveCount = max(1, int(objectWaveCount * scale_factor))
		print(maxObjects)
	print("ready  Breakables")

func spawnObjects(amount):
	var breakableScene := preload("res://scenes/spawn/object/breakable.tscn")
	var spawnedThisWave := 0
	for i in range(amount):
		var spawnPos = Multihelper.map.tile_map.map_to_local(
							Multihelper.map.walkable_tiles.pick_random())
		var breakable := breakableScene.instantiate()
		var objectId = Items.objects.keys().pick_random()
		self.add_child(breakable,true)
		breakable.objectId = objectId
		breakable.position = spawnPos
		breakable.spawner = self
		spawnedObjects += 1
		spawnedThisWave += 1
	return spawnedThisWave
