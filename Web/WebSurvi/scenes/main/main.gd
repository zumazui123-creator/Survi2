extends Node2D

@export var breakables : Objects
@export var buildings : Buildings


func _ready():
	print(Multihelper.level)
	Multihelper.loadMap()
	
	breakables.spawnObjects(breakables.initialSpawnObjects)
	if not Multihelper.host_as_player_enabled:
		$HUD.queue_free()
	$dayNight.time_tick.connect(%DayNightCycleUI.set_daytime)
	#createHUD()
	

#func createHUD():
	#var hudScene := preload("res://scenes/ui/playersList/generalHud.tscn")
	#var hud := hudScene.instantiate()
	#$HUD.add_child(hud)
	
func setMobs(initialSpawnObjects : int , maxObjects : int ,
			maxEnemiesPerPlayer : int,
			maxAnimalsPerPlayer : int ):
	breakables.initialSpawnObjects = initialSpawnObjects
	breakables.maxObjects 		 = maxObjects
	$Enemies.maxEnemiesPerPlayer = maxEnemiesPerPlayer
	$Animals.maxAnimalsPerPlayer = maxAnimalsPerPlayer

func trySpawnObjectWave():
	#print("SpawnObjects: "+ str(spawnedObjects)+ " maxObjects: "+str(maxObjects) )
	if breakables.spawnedObjects < breakables.maxObjects:
		var toMax = breakables.maxObjects - breakables.spawnedObjects
		breakables.spawnObjects(min(breakables.objectWaveCount, toMax))

func _on_object_spawn_timer_timeout():
	trySpawnObjectWave()

func _on_enemy_spawn_timer_timeout():
	$Enemies.trySpawnEnemies()

func _on_animal_spawn_timer_timeout() -> void:
	$Animals.trySpawnAnimals()
