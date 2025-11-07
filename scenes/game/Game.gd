extends Node
@onready var mainMenu = %MainMenu

func start_game():
	# Hide the UI and unpause to start the game.
	mainMenu.queue_free()
	
	get_tree().paused = false
	# Only change level on the server.
	# Clients will instantiate the level via the spawner.
	if multiplayer.is_server():
		change_level.call_deferred(load("res://scenes/main/main.tscn"))
		
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
