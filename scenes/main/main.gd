extends Node2D

#objects
const initialSpawnObjects := 10
const maxObjects 	  := Constants.MAX_OBJECTS
const objectWaveCount := 10
var spawnedObjects 	  := 0

func _ready():
	if multiplayer.is_server():
		Multihelper.loadMap()
		spawnObjects(initialSpawnObjects)
		#$HUD.queue_free()
	$dayNight.time_tick.connect(%DayNightCycleUI.set_daytime)
	#createHUD()

#func createHUD():
	#var hudScene := preload("res://scenes/ui/playersList/generalHud.tscn")
	#var hud := hudScene.instantiate()
	#$HUD.add_child(hud)

#object spawn
func spawnObjects(amount):
	var breakableScene := preload("res://scenes/spawn/object/breakable.tscn")
	var spawnedThisWave := 0
	for i in range(amount):
		var spawnPos = $Map.tile_map.map_to_local($Map.walkable_tiles.pick_random())
		var breakable := breakableScene.instantiate()
		var objectId = Items.objects.keys().pick_random()
		$Objects.add_child(breakable,true)
		breakable.objectId = objectId
		breakable.position = spawnPos
		breakable.spawner = self
		spawnedObjects += 1
		spawnedThisWave += 1
	return spawnedThisWave

func trySpawnObjectWave():
	#print("SpawnObjects: "+ str(spawnedObjects)+ " maxObjects: "+str(maxObjects) )
	if spawnedObjects < maxObjects:
		var toMax := maxObjects - spawnedObjects
		spawnObjects(min(objectWaveCount, toMax))

func _on_object_spawn_timer_timeout():
	if multiplayer.is_server():
		trySpawnObjectWave()

func _on_enemy_spawn_timer_timeout():
	if multiplayer.is_server():
		$Enemies.trySpawnEnemies()

func _on_animal_spawn_timer_timeout() -> void:
	if multiplayer.is_server():
		$Animal.trySpawnAnimals()
		
func set_level_options(level : int):
	print("set level options:"+str(level))
	
	if level == 0:
		$Enemies.maxEnemiesPerPlayer = 0
		$Animal.maxAnimalsPerPlayer  = 50
		
	if level == 1:
		$Enemies.maxEnemiesPerPlayer = 0
		$Animal.maxAnimalsPerPlayer  = 25
		
	if level == 2:
		$Enemies.maxEnemiesPerPlayer = 5
		$Animal.maxAnimalsPerPlayer  = 35
			
	if level == 3:
		$Enemies.maxEnemiesPerPlayer = 25
		$Animal.maxAnimalsPerPlayer  = 45
