extends Node

var workTask := {
	"LabyrinthTask": "Gehe zum weißen Feld!“",
	"MainTask": "Überlebe so viele Tage wie möglich",
}

func getWorkTask(level : Dictionary) -> String:
	if level["type"] == 1:
		return workTask["MainTask"]
	if level["type"] == 2:
		return " Labyrinth Level:"+str(level["level"])+ "\n \n"+ workTask["LabyrinthTask"] 
	return ""
