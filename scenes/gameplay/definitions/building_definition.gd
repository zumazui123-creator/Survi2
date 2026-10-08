extends Resource
class_name BuildingDefinition

@export var building_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var scene: PackedScene
@export var texture: Texture2D
@export var max_hp: float = 70.0
@export var required_tool: StringName = &"pickaxe"
@export var drops: Dictionary = {}
@export var build_cost: Dictionary = {}
@export var navigation_footprint: Array[Vector2i] = [Vector2i.ZERO]


func get_occupied_tiles(origin: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset: Vector2i in navigation_footprint:
		result.append(origin + offset)
	return result
