extends ProgramPuzzleDefinitionBase
class_name SequencePuzzleDefinition

@export_range(5.0, 120.0, 1.0) var time_limit_seconds: float = 20.0
@export var switch_offsets: Array[Vector2i] = []
@export var reward_offset: Vector2i = Vector2i(0, 4)


func is_valid() -> bool:
	return is_common_valid() \
		and switch_offsets.size() >= 2
