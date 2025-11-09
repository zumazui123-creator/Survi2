extends Node

var player: CharacterBody2D

@onready var hands = get_parent().get_node("%Hands")
@onready var held_item = get_parent().get_node("%HeldItem")
@onready var equipment = get_parent().get_node("%Equipment")
@onready var hit_area = get_parent().get_node("%HitArea")
@onready var blood_particles = get_parent().get_node("bloodParticles")
@onready var animation_player = get_parent().get_node("AnimationPlayer")


var attackRate : int = 1
var equippedItem : String:
	set(value):
		equippedItem = value
		if value in Items.equips:
			var itemData = Items.equips[value]
			if "projectile" in itemData:
				spawnsProjectile = itemData["projectile"]
		else:
			spawnsProjectile = ""

#stats
@export var maxHP := 250.0
@export var hp := maxHP:
	set(value):
		hp = value
		blood_particles.emitting = true
		player.status.setHPBarRatio(hp/maxHP)
		if hp <= 0:
			die()


var spawnsProjectile := ""
@export var speed := 10
@export var attackDamage := 10:
	get:
		if equippedItem:
			return Items.equips[equippedItem]["damage"] + attackDamage
		else:
			return attackDamage
var damageType := "normal":
	get:
		if equippedItem:
			return Items.equips[equippedItem]["damageType"]
		else:
			return damageType
var attackRange := 1.0:
	set(value):
		var clampedVal = clampf(value, 1.0, 5.0)
		attackRange = clampedVal
		var hit_collision = get_parent().get_node("%HitCollision")
		if hit_collision:
			hit_collision.shape.height = 20 * clampedVal


func _ready():
	player = get_parent()

func hit(inp_action : String):
	if "leftClickAction" == inp_action:
		animation_player.speed_scale = attackRate
		var action_anim = Items.equips[equippedItem]["attack"] if equippedItem else Strings.ANIM_PUNCHING
		if not animation_player.is_playing() or animation_player.current_animation != action_anim:
			animation_player.play(action_anim)
			var delay : float = 0.8 / attackRate
			await get_tree().create_timer(delay).timeout
			animation_player.stop()
			player.net_control.send_text("Godot: " + inp_action)

func punchCheckCollision():
	var id = multiplayer.get_unique_id()
	if spawnsProjectile:
		if str(id) == player.name:
			var mousePos := player.get_global_mouse_position()
			sendProjectile.rpc_id(1, mousePos)
	if not player.is_multiplayer_authority():
		return
	if equippedItem:
		Inventory.useItemDurability(str(player.name), equippedItem)
	for body in hit_area.get_overlapping_bodies():
		if body != player and body.is_in_group(Strings.GROUP_DAMAGEABLE):
			body.getDamage(player, attackDamage, damageType)

@rpc("any_peer", "reliable")
func sendProjectile(towards):
	Items.spawnProjectile(player, spawnsProjectile, towards, Strings.GROUP_DAMAGEABLE)

@rpc("authority", "call_local", "reliable")
func get_heal(heal_hp : float):
	hp += heal_hp


@rpc("authority", "call_local", "reliable")
func increaseScore(by):
	hp += by * 5
	maxHP += by * 5
	attackDamage += by
	speed += by
	Multihelper.spawnedPlayers[int(str(player.name))]["score"] += by
	Multihelper.player_score_updated.emit()

func objectDestroyed():
	increaseScore.rpc(Constants.OBJECT_SCORE_GAIN)

func mobKilled():
	increaseScore.rpc(Constants.MOB_SCORE_GAIN)

func enemyPlayerKilled():
	increaseScore.rpc(Constants.PK_SCORE_GAIN)

func getDamage(causer, amount, _type):
	hp -= amount
	if (hp - amount) <= 0 and causer.is_in_group(Strings.GROUP_PLAYER):
		causer.player_killed.emit()

func die():
	if not multiplayer.is_server():
		return
	var peerId := int(str(player.name))
	Multihelper._deregister_character.rpc(peerId) # für Server
	dropInventory()
	Multihelper.showSpawnUI.rpc_id(peerId)
	player.queue_free()

func dropInventory():
	var inventoryDict = Inventory.inventories
	for item in inventoryDict.keys():
		Items.spawnPickups(item, player.position, inventoryDict[item].size() )
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
	hands.visible = false
	held_item.texture = load(Constants.PATH_ITEMS+id+".png")
	if multiplayer.is_server() and "scene" in Items.equips[id]:
		for c in equipment.get_children():
			c.queue_free()
		var itemScene := load(Constants.PATH_EQUIPMENT_SCENES+Items.equips[id]["scene"]+".tscn")
		var item = itemScene.instantiate()
		equipment.add_child(item)
		item.data = {"player": str(player.name), "item": id}

@rpc("any_peer", "call_local", "reliable")
func unequipItem():
	equippedItem = ""
	hands.visible = true
	held_item.texture = null
	if multiplayer.is_server():
		for c in equipment.get_children():
			c.queue_free()

func itemRemoved(id, item):
	if not multiplayer.is_server():
		return
	if id == str(player.name) and item == equippedItem:
		unequipItem.rpc()

func projectileHit(body):
	body.getDamage(player, attackDamage, damageType)