extends Node

var workTask := {
	"LabyrinthTask": "- Gehe zum weissem Feld !",
	"MainTask": "- Überlebe so viele Tage wie möglich",
}

func getWorkTask(level : Dictionary) -> String:
	if level["type"] == 1:
		return workTask["MainTask"]
	if level["type"] == 100:
		return workTask["LabyrinthTask"]
	return ""
