extends Node2D
@onready var completeUI = $HUD/Complete

func _ready():
	if multiplayer.is_server():
		print(Multihelper.level)
		Multihelper.loadMap()
		$Objects.spawnObjects($Objects.initialSpawnObjects)
		#$HUD.queue_free()
	$dayNight.time_tick.connect(%DayNightCycleUI.set_daytime)
	#createHUD()

#func createHUD():
	#var hudScene := preload("res://scenes/ui/playersList/generalHud.tscn")
	#var hud := hudScene.instantiate()
	#$HUD.add_child(hud)
	
func setMobs(initialSpawnObjects : int , maxObjects : int ,
			maxEnemiesPerPlayer : int,
			maxAnimalsPerPlayer : int ):
	$Objects.initialSpawnObjects = initialSpawnObjects
	$Objects.maxObjects = maxObjects
	$Enemies.maxEnemiesPerPlayer = maxEnemiesPerPlayer
	$Animals.maxAnimalsPerPlayer = maxAnimalsPerPlayer

func setHideComplete(visible : bool):
	print("setHideComplete:"+str(visible))
	completeUI.visible = visible

func trySpawnObjectWave():
	#print("SpawnObjects: "+ str(spawnedObjects)+ " maxObjects: "+str(maxObjects) )
	if $Objects.spawnedObjects < $Objects.maxObjects:
		var toMax = $Objects.maxObjects - $Objects.spawnedObjects
		$Objects.spawnObjects(min($Objects.objectWaveCount, toMax))

func _on_object_spawn_timer_timeout():
	if multiplayer.is_server():
		trySpawnObjectWave()

func _on_enemy_spawn_timer_timeout():
	if multiplayer.is_server():
		$Enemies.trySpawnEnemies()

func _on_animal_spawn_timer_timeout() -> void:
	if multiplayer.is_server():
		$Animals.trySpawnAnimals()
		
