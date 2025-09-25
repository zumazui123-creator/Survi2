extends Control


func _on_next_button_pressed() -> void:
	print("_on_next_button_pressed")
	self.visible = false
	Multihelper.level += 1
	Multihelper.map.generateMap(Multihelper.level)
	Multihelper.spawnPlayers()


func _on_retry_button_pressed() -> void:
	self.visible = false
