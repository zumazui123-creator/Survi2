extends PanelContainer

signal recipeSelected(id)

var canCraft = false
var recipe := {}
var itemId := "":
	set(value):
		recipe = Items.recipes[value]
		itemId = value
		$TextureRect.texture = Items.get_item_icon(value)

func _ready():
	setState()

func setState():
	if canCraft:
		return
	self_modulate = Color.RED

func _on_button_pressed():
	recipeSelected.emit(itemId)
