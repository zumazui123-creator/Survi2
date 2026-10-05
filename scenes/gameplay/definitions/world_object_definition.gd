extends Resource
class_name WorldObjectDefinition

@export var object_id: StringName
@export var texture: Texture2D
@export var max_hp := 40.0
@export var required_tool: StringName
@export var drops: Dictionary = {}


func to_legacy_dict() -> Dictionary:
	return {
		"id": String(object_id),
		"hp": max_hp,
		"tool": String(required_tool),
		"drops": drops.duplicate(true),
	}
