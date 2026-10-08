extends Control

signal selectionChanged

var slotCount: int = Constants.MAX_INVENTORY_SLOTS
var selectedSlot: int = 0
var selectedRecipe: String = ""
var player

var chatinput

func _ready():
	Inventory.updateReceived.connect(inventoryUpdated)
	populateSlots()

func _unhandled_input(_event):
	if Input.is_action_pressed("esc"):
		if is_instance_valid(chatinput):
			chatinput.queue_free()
	if Input.is_action_pressed("chat"):
		if is_instance_valid(chatinput):
			if chatinput.text:
				player.sendMessage.rpc_id(1,chatinput.text)
			chatinput.queue_free()
		else:
			var chatInputSc: PackedScene = preload("res://scenes/ui/chat/chat_input.tscn")
			var chatInput: Node = chatInputSc.instantiate()
			%ChatInputLocation.add_child(chatInput)
			chatinput = chatInput
			chatinput.gui_input.connect(_unhandled_input)
			chatinput.grab_focus()

func inventoryUpdated(_id):
	populateItems()
	populateRecipes()
	if selectedRecipe:
		recipeSelected(selectedRecipe)

func populateSlots():
	for c in %Slots.get_children():
		c.queue_free()
	var slotScene: PackedScene = preload("res://scenes/ui/inventory/inventory_slot.tscn")
	for i in range(1,slotCount+1):
		var slot: Node = slotScene.instantiate()
		slot.index = i
		selectionChanged.connect(slot.selectionChanged)
		%Slots.add_child(slot)

func populateItems():
	var pId: int = multiplayer.get_unique_id()
	if str(pId) in Inventory.inventories:
		var inventory = Inventory.inventories[str(pId)]
		var currentIndex: int = 0
		for slot in %Slots.get_children():
			if currentIndex < len(inventory.keys()):
				var item = inventory.keys()[currentIndex]
				slot.pId = pId
				slot.itemId = item
				slot.itemCount = inventory[item]
				currentIndex += 1
			else:
				slot.itemId = ""

func populateRecipes():
	var recipeSlotScene: PackedScene = preload("res://scenes/ui/inventory/recipe_slot.tscn")
	for c in %Recipes.get_children():
		c.queue_free()
	for recipe in Items.recipes.keys():
		var recipeSlot: Node = recipeSlotScene.instantiate()
		recipeSlot.itemId = recipe
		recipeSlot.canCraft = Inventory.canCraftItem(str(multiplayer.get_unique_id()), recipe)
		%Recipes.add_child(recipeSlot)
		recipeSlot.recipeSelected.connect(recipeSelected)

#func nextSelection():
	#selectedSlot += 1
	#if selectedSlot == slotCount:
		#selectedSlot = 0
	#selectionChanged.emit(selectedSlot)
#
#func prevSelection():
	#selectedSlot -= 1
	#if selectedSlot < 0:
		#selectedSlot = slotCount - 1
	#selectionChanged.emit(selectedSlot)
	
func select_slot(slot_number: int) -> bool:
	var slot_index: int = slot_number - 1
	var slots: Array[Node] = %Slots.get_children()
	if slot_index < 0 or slot_index >= slots.size():
		return false

	selectedSlot = slot_number
	selectionChanged.emit(slot_number)
	var item_id: String = String(slots[slot_index].get("itemId"))
	if item_id.is_empty():
		return false
	itemSelected(item_id)
	return true


func itemSelected(id: String) -> void:
	if not is_instance_valid(player) or not is_instance_valid(player.items):
		return
	player.items.handle_item_selection(id)
		
func _on_craft_button_pressed():
	if %craftCont.visible:
		$AnimationPlayer.play("craftDisappear")
	else:
		$AnimationPlayer.play("craftAppear")

func recipeSelected(id):
	selectedRecipe = id
	if Inventory.canCraftItem(str(multiplayer.get_unique_id()), id):
		%craftButton.disabled = false
	else:
		%craftButton.disabled = true
	%recipeName.text = id
	for c in %ingList.get_children():
		c.queue_free()
	%RecipeBox.visible = true
	for ing in Items.recipes[id].keys():
		var itemSlotScene: PackedScene = preload("res://scenes/ui/inventory/inventory_slot.tscn")
		var itemSlot: Node = itemSlotScene.instantiate()
		itemSlot.itemId = ing
		itemSlot.setRecipeText(Inventory.checkItemCount(str(multiplayer.get_unique_id()), ing),Items.recipes[id][ing])
		%ingList.add_child(itemSlot)	

func closeRecipe():
	selectedRecipe = ""
	for c in %ingList.get_children():
		c.queue_free()
	%RecipeBox.visible = false

func _on_startcraft_button_pressed():
	Inventory.tryCraftItem.rpc_id(1, str(multiplayer.get_unique_id()), selectedRecipe)
