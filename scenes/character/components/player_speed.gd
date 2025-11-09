extends Node2D

@onready var player = $".."
@onready var speedLabel = $"../CanvasLayer/Code/TabContainer/KI Playground/VBoxContainer/GameSetContainer/HBoxContainer2/Speed"


func _ready():
	speedLabel.text = str(player.move_speed_factor)
	
func set_speed( player_speed : float):
	player.move_speed_factor += player_speed
	speedLabel.text = str(player.move_speed_factor)

func _on_speed_plus_pressed() -> void:
	set_speed(0.2)

func _on_speed_minus_pressed() -> void:
	set_speed(-0.2)
