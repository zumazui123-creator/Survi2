extends Node
@onready var mainMenu = %MainMenu

func save_runtime_level(level_root: Node, path: String = "res://scenes/map/levels/level_saved.tscn") -> void:
	# 1️⃣ PackedScene erzeugen
	var packed := PackedScene.new()
	var result = packed.pack(level_root)
	if not result:
		print("Failed to pack scene!")
		return
	
	# 2️⃣ Scene speichern
	var err = ResourceSaver.save(packed, path)
	if err != OK:
		print("Failed to save level: ", err)
	else:
		print("Level saved to ", path)
		
func start_game():
	# Hide the UI and unpause to start the game.
	mainMenu.queue_free()
	
	get_tree().paused = false
	# Only change level on the server.
	# Clients will instantiate the level via the spawner.
	if multiplayer.is_server():
		var main = load("res://scenes/main/main.tscn")
		var test = main.instantiate()
		
		save_runtime_level(test)
		change_level.call_deferred(main)
		
func setMainMenu(newMainMenu: Node):
	mainMenu = newMainMenu
	
# Call this function deferred and only on the main authority (server).
func change_level(scene: PackedScene):
	# Remove old level if any.
	var level = %Level
	for c in level.get_children():
		level.remove_child(c)
		c.queue_free()
	# Add new level.
	level.add_child(scene.instantiate())
