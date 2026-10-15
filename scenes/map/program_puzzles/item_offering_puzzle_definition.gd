extends ProgramPuzzleDefinitionBase
class_name ItemOfferingPuzzleDefinition

@export var offering_offsets: Array[Vector2i] = []
@export var required_items: PackedStringArray = PackedStringArray()
@export var reward_offset: Vector2i = Vector2i(0, -1)


func is_valid() -> bool:
	return is_common_valid() \
		and offering_offsets.size() >= 2 \
		and offering_offsets.size() == required_items.size()
