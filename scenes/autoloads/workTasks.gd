extends Node

var workTask := {
	"LabyrinthTask": "- Gehe zum weissem Feld !",
	"MainTask": "- Überlebe so viele Tage wie möglich",
}

func getWorkTask(level : int) -> String:
	if level < 99:
		return workTask["MainTask"]
	if level > 99:
		return workTask["LabyrinthTask"]
	
	return ""
