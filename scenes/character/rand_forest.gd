extends Node

@onready var player = $"../.."

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func train() -> void:
	print("Train: "+player.name)
	var position = player.movement.current_map_position
	var object 	 = Vector2i(position.x+5,position.y+3) 
	var features = [object.x,object.y] 
	print(features)
	var training_data = [
	[1, 0],
	[2, 1],
	[3, 0] 
	]
	var tree1 = node_tree.new(5,1,0)
	tree1.train(training_data)
	
	var value = tree1.output(2)
	print(value)


func _on_start_ki_button_pressed() -> void:
	train()
