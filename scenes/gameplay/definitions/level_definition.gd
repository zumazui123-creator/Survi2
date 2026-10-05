extends Resource
class_name LevelDefinition

@export var level_number := 0
@export var level_type := 0
@export var end_condition := 0
@export var map_size := Vector2i.ZERO


func to_dict() -> Dictionary:
	var data := {
		"level": level_number,
		"type": level_type,
		"end": end_condition,
	}
	if map_size != Vector2i.ZERO:
		data["size"] = map_size
	return data
