extends Node2D

@onready var player = $".."

func _on_start_ki_button_pressed() -> void:
	player.send_to_ws_peer("start ki")
