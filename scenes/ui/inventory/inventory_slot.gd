extends PanelContainer

signal itemSelected(id)

@onready var slot_number_label: Label = %SlotNumberLabel

var pId : int
var index : int:
	set(value):
		index = value
		_update_slot_number()
var selected: bool = false
var itemId : String:
	set(value):
		itemId = value
		if value:
			$itemTexture.texture = Items.get_item_icon(value)
			setItemDurability()
		else:
			$itemTexture.texture = null
			%durabilityBar.visible = false
			$Label.text = ""

var itemCount : int:
	set(value):
		itemCount = value
		$Label.text = "x"+str(value)


func _ready() -> void:
	_update_slot_number()


func _update_slot_number() -> void:
	if not is_node_ready():
		return
	if not is_instance_valid(slot_number_label):
		return
	slot_number_label.visible = index > 0
	slot_number_label.text = str(index)

func setItemDurability():
	if str(pId) not in Inventory.durabilities:
		return
	var itemDurabilities = Inventory.durabilities[str(pId)]
	if itemId in itemDurabilities:
		%durabilityBar.visible = true
		%durabilityBar.value = itemDurabilities[itemId] / Items.equips[itemId]["durability"]
	else:
		%durabilityBar.visible = false

func selectionChanged(selectedId):
	if selectedId == index:
		selected = true
		$AnimationPlayer.play("selected")
		itemSelected.emit(itemId)
	elif selected:
		selected = false
		$AnimationPlayer.play("deselected")

func setRecipeText(count, needed):
	$Label.text = str(count)+"/"+str(needed)
	if count < needed:
		$bgTexture.modulate = Color.RED
