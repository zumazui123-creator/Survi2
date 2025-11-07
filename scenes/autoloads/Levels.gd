extends Node


var MainLevels := {
	0: {"level": 0,"type": 1},
	1: {"level": 1,"type": 1},
	2: {"level": 2,"type": 1},
}

var LabyrinthLevels := {
	0: {"level": 0,"type": 2},
}

var TurnierLevels := {
	0: {"level": 15,"type": 3},
}

func _ready():
	for i in range(1,50):
		LabyrinthLevels.set(i,{"level": i,"type": 2})
