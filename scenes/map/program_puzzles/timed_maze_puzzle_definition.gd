extends ProgramPuzzleDefinitionBase
class_name TimedMazePuzzleDefinition

@export_range(10.0, 180.0, 1.0) var time_limit_seconds: float = 45.0


func is_valid() -> bool:
	return is_common_valid() \
		and time_limit_seconds > 0.0
