extends Node2D

@export var object_manager: ObjectManager
@export var entity_spawner: WorldEntitySpawner

func _ready() -> void:
	%Map.generation_started.connect(_clear_dynamic_world)
	if multiplayer.is_server():
		print(Multihelper.level)
		Multihelper.loadMap()

		object_manager.spawn_initial_breakables()
		if not Multihelper.host_as_player_enabled:
			$HUD.queue_free()
	$dayNight.time_tick.connect(%DayNightCycleUI.set_daytime)
	#createHUD()


#func createHUD(): # brauche leider den Platz fuer den Code editor
	#var hudScene: PackedScene = preload("res://scenes/ui/playersList/generalHud.tscn")
	#var hud: Node = hudScene.instantiate()
	#$HUD.add_child(hud)

func setMobs(initialSpawnObjects : int , maxObjects : int ,
			maxEnemiesPerPlayer : int,
			maxAnimalsPerPlayer : int ) -> void:
	object_manager.configure_breakables(initialSpawnObjects, maxObjects)
	$Enemies.maxEnemiesPerPlayer = maxEnemiesPerPlayer
	$Animals.maxAnimalsPerPlayer = maxAnimalsPerPlayer

func trySpawnObjectWave() -> void:
	object_manager.try_spawn_breakable_wave()

func _on_object_spawn_timer_timeout() -> void:
	if multiplayer.is_server():
		trySpawnObjectWave()

func _on_enemy_spawn_timer_timeout() -> void:
	if multiplayer.is_server():
		$Enemies.trySpawnEnemies()

func _on_animal_spawn_timer_timeout() -> void:
	if multiplayer.is_server():
		$Animals.trySpawnAnimals()


func _clear_dynamic_world() -> void:
	object_manager.clear_villages()
	object_manager.clear_breakables()
	object_manager.clear_buildings()
	for container in [$Enemies, $Animals, $Projectiles, $Pickups]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	$Enemies.spawnedEnemies.clear()
