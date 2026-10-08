extends Node
class_name PlayerItems
@export var player: CharacterBody2D

@onready var held_item = %HeldItem  #get_parent().get_node("%HeldItem")
@onready var equipment = %Equipment #get_parent().get_node("%Equipment")
var inventory 

var equippedItem : String:
	set(value):
		equippedItem = value
		if value in Items.equips:
			var itemData = Items.equips[value]
			if "projectile" in itemData:
				player.combat.spawnsProjectile = itemData["projectile"]
		else:
			player.combat.spawnsProjectile = ""
			
func _ready():
	
	Inventory.itemRemoved.connect(itemRemoved)
	#if multiplayer.is_server():
		#Inventory.itemRemoved.connect(itemRemoved)
		#Inventory.itemConsumed.connect(_on_item_consumed)
		
	if player.name == str(multiplayer.get_unique_id()):
		inventory = get_tree().get_first_node_in_group("inventory_ui")
		if inventory:
			inventory.player = player
		
func dropInventory():
	var inventoryDict = Inventory.inventories
	var player_inventory: Dictionary = inventoryDict.get(str(player.name), {})
	for item in player_inventory.keys():
		WorldEntitySpawner.get_for(self).spawn_pickups(item, player.position, player_inventory[item])
	Inventory.inventories[player.name] = {}
	Inventory.inventoryUpdated.emit(player.name)
	Inventory.inventories.erase(player.name)

@rpc("any_peer", "call_local", "reliable")
func tryEquipItem(id):
	if id in Inventory.inventories[player.name].keys():
		equipItem.rpc(id)

@rpc("any_peer", "call_local", "reliable")
func equipItem(id):
	equippedItem = id
	player.combat.hands.visible = false
	held_item.texture = Items.get_item_icon(id)
	var item_scene: PackedScene = Items.get_equipment_scene(id)
	if multiplayer.is_server() and item_scene:
		for c in equipment.get_children():
			c.queue_free()
		var item = item_scene.instantiate()
		equipment.add_child(item)
		item.data = {"player": str(player.name), "item": id}

@rpc("any_peer", "call_local", "reliable")
func unequipItem():
	equippedItem = ""
	player.combat.hands.visible = true
	held_item.texture = null
	if multiplayer.is_server():
		for c in equipment.get_children():
			c.queue_free()

func itemRemoved(id, item):
	if not multiplayer.is_server():
		return
	if id == str(player.name) and item == equippedItem:
		unequipItem.rpc()
		
func handle_item_selection(id):
	var equipList: Array = Items.equips.keys()
	if id in equipList:
		tryEquipItem.rpc_id(1, id)
	elif equippedItem:
		unequipItem.rpc()
		
	var consumeList: Array = Items.consume.keys()
	if id in consumeList:
		request_consume_item(String(id))


func use_item(arguments: PackedStringArray) -> bool:
	if arguments.size() != 1 or not arguments[0].is_valid_int():
		return false
	if not is_instance_valid(inventory) or not inventory.has_method("select_slot"):
		return false
	var slot_number: int = arguments[0].to_int()
	return inventory.select_slot(slot_number)

#func _on_item_consumed(id, effects):
	#if str(player.name) != id: # Ensure this is for the current player
		#return
	#if "hp" in effects:
		#player.hp = min(player.maxHP, player.hp + effects["hp"])
	#if "food" in effects:
		#player.status.foodBar.value = min(100, player.status.foodBar.value + effects["food"])
	#if "hydration" in effects:
		#player.status.hydrationBar.value = min(100, player.status.hydrationBar.value + effects["hydration"])
	#if "speed" in effects and "duration" in effects:
		#player.apply_speed_boost(effects["speed"], effects["duration"])
	#Inventory.removeItem(str(name),effects)

func request_consume_item(item_id: String) -> void:
	if multiplayer.is_server():
		_consume_item_authoritative(item_id, multiplayer.get_unique_id())
	else:
		_request_consume_item.rpc_id(1, item_id)


@rpc("any_peer", "call_remote", "reliable")
func _request_consume_item(item_id: String) -> void:
	if not multiplayer.is_server():
		return
	_consume_item_authoritative(item_id, multiplayer.get_remote_sender_id())


func _consume_item_authoritative(item_id: String, sender_id: int) -> bool:
	var player_peer_id: int = int(str(player.name))
	if sender_id != player_peer_id:
		return false
	var definition: ItemDefinition = Items.item_definitions.get(item_id) as ItemDefinition
	if definition == null or definition.kind != ItemDefinition.Kind.CONSUMABLE:
		return false
	var player_id: String = str(player.name)
	if not Inventory.checkHasItemAmount(player_id, item_id, 1):
		return false

	_apply_consumable_effects(definition.effects)
	return Inventory.removeItem(player_id, item_id, 1)


func _apply_consumable_effects(effects: Dictionary) -> void:
	if effects.has("hp"):
		player.status.heal(float(effects["hp"]))
	if effects.has("hydration"):
		player.status.hydration += float(effects["hydration"])
	if effects.has("food"):
		player.status.food += float(effects["food"])
	if effects.has("mana"):
		player.status.mana += float(effects["mana"])
	if effects.has("speed") and effects.has("duration"):
		_apply_speed_boost.rpc_id(
			int(str(player.name)),
			float(effects["speed"]),
			float(effects["duration"])
		)


@rpc("any_peer", "call_local", "reliable")
func _apply_speed_boost(multiplier: float, duration: float) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != 0 and sender_id != 1:
		return
	if is_instance_valid(player) and is_instance_valid(player.movement):
		player.movement.apply_speed_boost(multiplier, duration)
