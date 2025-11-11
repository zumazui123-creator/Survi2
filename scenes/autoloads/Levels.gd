extends Node


var MainLevels := {
	0: {"level": 0,"type": Constants.MAP_MAIN, "end": Constants.END_MAIN},
	1: {"level": 1,"type": Constants.MAP_MAIN, "end": Constants.END_MAIN},
	2: {"level": 2,"type": Constants.MAP_MAIN, "end": Constants.END_MAIN},
}

var LabyrinthLevels := {
	0: {"level": 0,"type": Constants.MAP_LABY, "end": Constants.END_LABY},
}
const max_laby_level = 50

var TurnierLevels := {
	0: {"level": 0,"type": Constants.MAP_TOURMENT, "end": Constants.END_LABY},
}
const max_tourment_level = 5

func _ready():
	for i in range(1,max_laby_level+1):
		LabyrinthLevels.set(i,{"level": i,"type": Constants.MAP_LABY, "end": Constants.END_LABY})
	for i in range(1,max_tourment_level+1):
		TurnierLevels.set(i,{"level": i,"type": Constants.MAP_TOURMENT, "end": Constants.END_LABY})
