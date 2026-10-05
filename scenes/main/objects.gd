extends Node2D
class_name Objects

@export var world_map: Map

var initialSpawnObjects := Constants.INITAL_OBJECTS
var maxObjects 	  		:= Constants.MAX_OBJECTS
var objectWaveCount 	:= 10
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
	var candidates: Array[Vector2i] = []
	for tile: Vector2i in world_map.spawnable_tiles:
		if world_map.is_navigation_tile_walkable(tile, true):
			candidates.append(tile)
	candidates.shuffle()
	for spawn_tile in candidates:
		if spawnedThisWave >= amount:
			break
		var breakable := breakableScene.instantiate() as NavigationBreakable
		if breakable == null:
			push_warning("Breakable scene must use NavigationBreakable")
			return spawnedThisWave
		var occupied_tiles := breakable.get_navigation_tiles(spawn_tile)
		var can_spawn := true
		for occupied_tile in occupied_tiles:
			if not world_map.is_navigation_tile_walkable(occupied_tile, true):
				can_spawn = false
				break
		if not can_spawn:
			breakable.free()
			continue
		var objectId = Items.objects.keys().pick_random()
		self.add_child(breakable,true)
		breakable.objectId = objectId
		breakable.global_position = world_map.navigation_tile_to_world(spawn_tile)
		breakable.spawner = self
		breakable.register_navigation_blockers(occupied_tiles)
		spawnedObjects += 1
		spawnedThisWave += 1
	return spawnedThisWave
