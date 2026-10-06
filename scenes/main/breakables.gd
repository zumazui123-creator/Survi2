extends Node2D
class_name Breakables

const BREAKABLE_SCENE = preload("res://scenes/spawn/object/breakable.tscn")
var initialSpawnObjects := Constants.INITAL_OBJECTS
var maxObjects 	  		:= Constants.MAX_OBJECTS
var objectWaveCount 	:= 10
var spawnedObjects 	  	:= 0

var spawnedTrees 	  	:= 0
const TREE_SCENE = preload("res://scenes/spawn/object/tree.tscn")


func _ready() -> void:
	if Multihelper.level and "size" in Multihelper.level:
		var map_size = Multihelper.level["size"]
		var scale_factor = sqrt(map_size.x * map_size.y) / sqrt(Constants.MAP_SIZE.x * Constants.MAP_SIZE.y)
		maxObjects = int(Constants.MAX_OBJECTS * scale_factor)
		objectWaveCount = max(1, int(objectWaveCount * scale_factor))
		print(maxObjects)
	print("ready  Breakables")
	
	
func spawnObjects(amount):
	var spawnedThisWave := 0
	for i in range(amount):
		var spawnPos = Multihelper.map.tile_map.map_to_local(
							Multihelper.map.spawnable_tiles.pick_random())
		var breakable := BREAKABLE_SCENE.instantiate()
		var objectId = Items.objects.keys().pick_random()
		self.add_child(breakable,true)
		breakable.objectId = objectId
		breakable.position = spawnPos
		breakable.spawner = self
		spawnedObjects += 1
		spawnedThisWave += 1
	return spawnedThisWave

func spawnTrees(spawnPos : Vector2i):
	var breakable := TREE_SCENE.instantiate()
	var objectId = "tree0"
	self.add_child(breakable,true)
	breakable.spawner = self
	breakable.objectId = objectId
	breakable.position = Multihelper.map.tile_map.map_to_local( spawnPos )
	spawnedTrees += 1
	
	
