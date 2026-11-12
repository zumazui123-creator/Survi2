extends ProgramPuzzleDefinitionBase
class_name BridgeRepairPuzzleDefinition

@export_group("Repair")
@export var required_building_id: StringName = &"wall"
@export_range(1, 6, 1) var gap_tile_count: int = 2


func is_valid() -> bool:
	return is_common_valid() \
		and not required_building_id.is_empty() \
		and gap_tile_count > 0
