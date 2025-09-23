extends Node2D
var initialSpawnObjects := Constants.INITAL_OBJECTS
var maxObjects 	  		:= Constants.MAX_OBJECTS
var objectWaveCount 		:= 10
var spawnedObjects 	  	:= 0


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
