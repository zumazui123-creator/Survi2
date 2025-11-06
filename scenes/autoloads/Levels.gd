extends Node
var LabyrinthLevels := {
	0: {"level": 0,"type": 100},
	1: {"level": 1,"type": 100},
	2: {"level": 2,"type": 100},
	3: {"level": 3,"type": 100},
	4: {"level": 4,"type": 100},
}

var MainLevels := {
	0: {"level": 0,"type": 1},
	1: {"level": 1,"type": 1},
	2: {"level": 2,"type": 1},
	
}

var TurnierLevels := {
	0: {"level": 0,"type": 2},
}

func _ready():
	for i in range(5,50):
		LabyrinthLevels.set(i,{"level": i,"type": 100})
