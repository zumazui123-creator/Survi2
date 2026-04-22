extends Node

var player: CharacterBody2D

@onready var held_item = get_parent().get_node("%HeldItem")
@onready var equipment = get_parent().get_node("%Equipment")
var inventory 

var equippedItem : String:
	set(value):
		equippedItem = value
		if value in Items.equips:
			var itemData = Items.equips[value]
			if "projectile" in itemData:
				player.player_combat.spawnsProjectile = itemData["projectile"]
		else:
			player.player_combat.spawnsProjectile = ""
			
func _ready():
	player = get_parent()
	Inventory.itemRemoved.connect(itemRemoved)
	#Inventory.itemConsumed.connect(_on_item_consumed)
		
	inventory = player.get_parent().get_parent().get_node("HUD/Inventory")
	inventory.player = player
		
func dropInventory():
	var inventoryDict = Inventory.inventories
	for item in inventoryDict.keys():
		Items.spawnPickups(item, player.position, inventoryDict[item].size() )
	Inventory.inventories[player.name] = {}
	Inventory.inventoryUpdated.emit(player.name)
	Inventory.inventories.erase(player.name)

func tryEquipItem(id):
	if id in Inventory.inventories[player.name].keys():
		equipItem(id)

func equipItem(id):
	equippedItem = id
	player.player_combat.hands.visible = false
	held_item.texture = load(Constants.PATH_ITEMS+id+".png")
	if "scene" in Items.equips[id]:
		for c in equipment.get_children():
			c.queue_free()
		var itemScene := load(Constants.PATH_EQUIPMENT_SCENES+Items.equips[id]["scene"]+".tscn")
		var item = itemScene.instantiate()
		equipment.add_child(item)
		item.data = {"player": str(player.name), "item": id}

func unequipItem():
	equippedItem = ""
	player.player_combat.hands.visible = true
	held_item.texture = null
	for c in equipment.get_children():
		c.queue_free()

func itemRemoved(id, item):
	if id == str(player.name) and item == equippedItem:
		unequipItem()
		
func handle_item_selection(id):
	var equipList := Items.equips.keys()
	if id in equipList:
		tryEquipItem(id)
	elif equippedItem:
		unequipItem()
		
	var consumeList := Items.consume.keys()
	if id in consumeList:
		Inventory.useItem(str(player.name), id)

func use_item(cmd: PackedStringArray):
	var item_id : int 				= -1
	var item_id_str : String 	= cmd[1]
	if item_id_str.is_valid_int():
		item_id = int(item_id_str)
		inventory.selectionChanged.emit(item_id)
		return item_id

#func _on_item_consumed(id, effects):
	#if str(player.name) != id: # Ensure this is for the current player
		#return
	#if "hp" in effects:
		#player.hp = min(player.maxHP, player.hp + effects["hp"])
	#if "food" in effects:
		#player.player_status.foodBar.value = min(100, player.player_status.foodBar.value + effects["food"])
	#if "hydration" in effects:
		#player.player_status.hydrationBar.value = min(100, player.player_status.hydrationBar.value + effects["hydration"])
	#if "speed" in effects and "duration" in effects:
		#player.apply_speed_boost(effects["speed"], effects["duration"])
	#Inventory.removeItem(str(name),effects)

func consumeItem(item, item_prop):
	if "hp" in item_prop:
		player.player_status.get_heal( 100 )#item["hp"])
	Inventory.removeItem(str(player.name),item)
