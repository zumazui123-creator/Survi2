extends PanelContainer

signal recipeSelected(id)

var canCraft: bool = false
var recipe: Dictionary = {}
var itemId: String = "":
	set(value):
		recipe = Items.get_item_recipe(value)
		itemId = value
		$TextureRect.texture = Items.get_item_icon(value)
		var display_name: String = value.capitalize()
		$ItemName.text = display_name
		$Button.tooltip_text = "%s\nRezept: %s" % [
			display_name,
			_format_recipe(recipe),
		]

func _ready():
	setState()

func setState():
	if canCraft:
		return
	self_modulate = Color.RED

func _on_button_pressed():
	recipeSelected.emit(itemId)


func _format_recipe(recipe_data: Dictionary) -> String:
	var ingredients: PackedStringArray = PackedStringArray()
	for ingredient_value: Variant in recipe_data.keys():
		var ingredient: String = str(ingredient_value)
		ingredients.append(
			"%d × %s" % [int(recipe_data[ingredient_value]), ingredient.capitalize()]
		)
	return ", ".join(ingredients)
