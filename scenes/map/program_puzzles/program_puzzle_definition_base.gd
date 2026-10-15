extends Resource
class_name ProgramPuzzleDefinitionBase

@export var puzzle_id: StringName
@export var landmark_id: StringName
@export var display_name: String
@export_multiline var instructions: String
@export var rewards: Dictionary = {}
@export_range(2, 24, 1) var discovery_radius_tiles: int = 8


func is_common_valid() -> bool:
	return not puzzle_id.is_empty() \
		and not landmark_id.is_empty() \
		and not display_name.is_empty()
