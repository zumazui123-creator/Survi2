extends Node


var MainLevels := {
	0: {"level": 0,"type": Constants.MAP_MAIN},
	1: {"level": 1,"type": Constants.MAP_MAIN},
	2: {"level": 2,"type": Constants.MAP_MAIN},
}

var LabyrinthLevels := {
	0: {"level": 0,"type": Constants.MAP_LABY},
}

var TurnierLevels := {
	0: {"level": 15,"type": Constants.MAP_TOURMENT},
}

func _ready():
	for i in range(1,50):
		LabyrinthLevels.set(i,{"level": i,"type": Constants.MAP_LABY})
