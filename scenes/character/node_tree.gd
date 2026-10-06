class_name node_tree

var root
var left
var right

func _init(root,left,right ):
	self.root  = root
	self.left  = left
	self.right = right

func _ready() -> void:
	pass # Replace with function body.

func output(value) -> int:
	if value > root:
		return left
	else:
		return right

func train( training_data:Array ) -> void:
	for pair in training_data:
		var val = pair[0]
		var sol = pair[1]
		
		if left == self.output(val):
			if left != sol:
				root =- 0.001
				
		elif right == self.output(val):
			if right != sol:
				root =+ 0.001	
