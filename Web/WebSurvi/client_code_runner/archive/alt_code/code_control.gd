extends Control

var websocket := WebSocketPeer.new()

func _ready():
	var button = $HBoxContainer/VBoxContainer/Button
	button.text = "Play Code"
	button.pressed.connect(_button_pressed)
	var err = websocket.connect_to_url("ws://localhost:8765")
	if err != OK:
		print("Failed to connect:", err)
	set_process(true)
	

func _button_pressed():
	print("Hello world!")
