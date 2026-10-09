extends Resource
class_name StructureRecipe

@export var recipe_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var base_building_ids: Array[StringName] = []
@export var ingredients: Dictionary = {}
@export var result_building_id: StringName
@export_range(0, 1000, 1) var priority: int = 0


func accepts_base(building_id: StringName) -> bool:
	return building_id in base_building_ids


func requires_item(item_id: StringName) -> bool:
	return int(ingredients.get(item_id, ingredients.get(String(item_id), 0))) > 0


func get_required_amount(item_id: StringName) -> int:
	return int(ingredients.get(item_id, ingredients.get(String(item_id), 0)))


func matches(available_items: Dictionary[StringName, int]) -> bool:
	for item_value: Variant in ingredients.keys():
		var item_id: StringName = StringName(String(item_value))
		var required_amount: int = int(ingredients[item_value])
		if required_amount > int(available_items.get(item_id, 0)):
			return false
	return not ingredients.is_empty()

