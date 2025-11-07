extends CharacterBody2D

signal mob_killed
signal object_destroyed
signal player_killed
#signal end_goal_reached
#move speed

const default_move_speed_factor = 3


const TILE_SIZE = 32
var direction = Vector2.ZERO
var _pixels_moved: int = 0
var move_speed_factor = default_move_speed_factor
var act : String = ""
var attackRate : int = 1
var current_map_position : Vector2i
@onready var status = $PlayerStatus
@onready var kiBrain = $AIControl

@onready var workTaskText = $PlayerStatus/WorkContainer/VBoxContainer/workTaskText
@onready var net_control = $NetControl
## Server: TCP + WebSocket Upgrade
#var _tcp_server := TCPServer.new()
#var _ws_peers 	:= []  # Liste der aktiven WebSocket-Verbindungen
var time 		:= 0

@onready var code_edit = %CodeEdit
@export var playerName : String:
	set(value):
		playerName = value
		$PlayerStatus.setPlayerName(value)

@export var characterFile : String:
	set(value):
		characterFile = value
		$MovingParts/Sprite2D.texture = load("res://assets/characters/bodies/"+value)

var inventory : Control
var EndUI : Control
#@onready var inventory2 : Control = $Inventory #TODO ?

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
		$bloodParticles.emitting = true
		$PlayerStatus.setHPBarRatio(hp/maxHP)
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
		%HitCollision.shape.height = 20 * clampedVal

#var ws_peer = WebSocketPeer.new()

var last_angle = 0.0 # für godot server nötig

func _ready():

	#_tcp_server.listen(8765)  # Port 8765
	#print("Server gestartet auf ws://localhost:8765")

	if multiplayer.is_server():
		Inventory.itemRemoved.connect(itemRemoved)
		mob_killed.connect(mobKilled)
		player_killed.connect(enemyPlayerKilled)
		object_destroyed.connect(objectDestroyed)
		#end_goal_reached.connect()

	if name == str(multiplayer.get_unique_id()):
		print("player HUD")
		var main = get_parent().get_parent()

		inventory = main.get_node("HUD/Inventory")
		EndUI = main.get_node("HUD/EndUI")
		inventory.player = self
		$Camera2D.enabled = true

		#var err = websocket.connect_to_url("ws://localhost:8765")
		#if err != OK:
			#print("Failed to connect:", err)
		#if err == OK:
			#print("connectin succesfully")
		#set_process(true)
	Multihelper.player_disconnected.connect(disconnected)

#func send_to_ws_peer(text):
	#ws_peer.send_text(text)

func visibilityFilter(id):
	if id == int(str(name)):
		return false
	return true

@rpc("any_peer", "call_local", "reliable")
func sendMessage(text):
	if multiplayer.is_server():
		var messageBoxScene := preload("res://scenes/ui/chat/message_box.tscn")
		var messageBox := messageBoxScene.instantiate()
		%PlayerMessages.add_child(messageBox, true)
		messageBox.text = str(text)

func disconnected(id):
	if str(id) == name:
		die()

func is_moving() -> bool:
	return direction != Vector2.ZERO

func input():
	if is_moving(): return
	if Input.is_action_pressed("walkRight"):
		direction = Vector2(1, 0)
	elif Input.is_action_pressed("walkLeft"):
		direction = Vector2(-1, 0)
	elif Input.is_action_pressed("walkUp"):
		direction = Vector2(0, -1)
	elif Input.is_action_pressed("walkDown"):
		direction = Vector2(0, 1)
	elif Input.is_action_pressed("leftClickAction"):
		hit("leftClickAction")

func net_commander(): 
	var net_action = net_control.net_commander()
	if net_action == "End Sequenz":
		resetPlayer()
		net_control.send_text(net_action)
	if net_action == "reset":
		Multihelper.spawnPlayers()
	return net_action
	
func _physics_process(delta: float) -> void:
	if str(multiplayer.get_unique_id()) != name:
		return

	act = net_commander()
	press_action(act)
	#input() # manuelle Eingabe
	tile_move()
	win_condition()

func win_condition():
	status.playerStatus["terminated"] = false

	if Multihelper.level["type"] == 100:
		var end_goal_position = Multihelper.map.laby_map.endPosition
		if current_map_position == end_goal_position:
			current_map_position = Vector2i()
			EndUI.setLabel("Level Abgeschlossen!")
			# EndUI.visible = true
			#EndUI.next_level()
			status.playerStatus["terminated"] = true
			EndUI.retry()

func get_reward():
	var reward = 0
	if Multihelper.level["type"] == 100:
		var end_goal_position = Multihelper.map.laby_map.endPosition
		reward = 1/current_map_position.distance_to(end_goal_position)
	return reward

func tile_move():
	if not is_moving():
		return

	_pixels_moved += 1
	velocity = direction * move_speed_factor
	move_and_collide(velocity)

	if _pixels_moved >= TILE_SIZE/move_speed_factor:
		direction = Vector2.ZERO
		_pixels_moved = 0

		current_map_position = Multihelper.map.tile_map.local_to_map( position )
		snap_to_tiles_position()
		#ws_peer.send_text("Godot: " + act) TODO nice für Debugen
		kiBrain.send_ki_obs()
		act = ""
	animate_player(direction)

func snap_to_tiles_position():
	var snap_position = Multihelper.map.tile_map.map_to_local( current_map_position )
	self.position = snap_position

func animate_player(dir: Vector2):
	if dir != Vector2.ZERO:
		$MovingParts.rotation = dir.angle()
		if !$AnimationPlayer.is_playing() or $AnimationPlayer.current_animation != "walking":
			$AnimationPlayer.play("walking")
	else:
		$AnimationPlayer.stop()

func resetPlayer():
	var difLevelMode = %DifModeButton.get_selected_id()
	if difLevelMode > 0:
		Multihelper.spawnPlayers()


func press_action(inp_action : String):
	if inp_action == "":
		return
	inp_action = inp_action.strip_edges()
	hit(inp_action)
	if "sage" in inp_action:
		print("sage:"+inp_action)
		var text = inp_action.trim_prefix("sage")
		sendMessage(text)
		net_control.send_text("Godot: " + inp_action)

	if "use item" in inp_action:
		var item_id_str = inp_action.trim_prefix("use item").strip_edges()
		print("action: "+inp_action+" item_id_str: "+item_id_str)
		var item_id : int = -1
		if item_id_str.is_valid_int():
			item_id = int(item_id_str)
			#inventory.itemSelected(item_id)
			inventory.selectionChanged.emit(item_id)

		net_control.send_text("Godot: " + inp_action + ", item: "+str(item_id))

	if "walk" in inp_action:
		if inp_action == "walkRight":
			#print("input walkRight")
			direction = Vector2(1, 0)
		elif inp_action == "walkLeft":
			#print("input walkLeft")
			direction = Vector2(-1, 0)
		elif inp_action == "walkUp":
			#print("input walkUp")
			direction = Vector2(0, -1)
		elif inp_action == "walkDown":
			#print("input walkDown")
			direction = Vector2(0, 1)

	if Multihelper.level in range(0,2) and "End Sequenz" in inp_action:
		code_edit.text = ""
		var end = Multihelper.map.laby_map.spawnPosition
		var start = Multihelper.map.tile_map.map_to_local( end )
		position = start
		net_control.send_text("Godot: " + inp_action)
		print("End Sequenz")



func hit(inp_action : String):
	#print("hit")
	if "leftClickAction" == inp_action:
		$AnimationPlayer.speed_scale = attackRate
		var action_anim = Items.equips[equippedItem]["attack"] if equippedItem else "punching"
		if !$AnimationPlayer.is_playing() or $AnimationPlayer.current_animation != action_anim:
			$AnimationPlayer.play(action_anim)
			#print("Play Animation")
			var delay : float = 0.8 / attackRate
			await get_tree().create_timer(delay).timeout
			$AnimationPlayer.stop()
			net_control.send_text("Godot: " + inp_action)

#func _on_next_item():
	#inventory.nextSelection()
#
## Define what happens when previousItem is triggered
#func _on_previous_item():
	#inventory.prevSelection()

# Handle input events
#func _unhandled_input(event):
	#if name != str(multiplayer.get_unique_id()):
		#return
	#if event.is_action_pressed("nextItem"):
		#_on_next_item()
	#elif event.is_action_pressed("previousItem"):
		#_on_previous_item()

func punchCheckCollision():
	var id = multiplayer.get_unique_id()
	if spawnsProjectile:
		if str(id) == name:
			var mousePos := get_global_mouse_position()
			sendProjectile.rpc_id(1, mousePos)
	if !is_multiplayer_authority():
		return
	if equippedItem:
		Inventory.useItemDurability(str(name), equippedItem)
	for body in %HitArea.get_overlapping_bodies():
		if body != self and body.is_in_group("damageable"):
			body.getDamage(self, attackDamage, damageType)

@rpc("any_peer", "reliable")
func sendProjectile(towards):
	Items.spawnProjectile(self, spawnsProjectile, towards, "damageable")

@rpc("authority", "call_local", "reliable")
func get_heal(heal_hp : float):
	hp += heal_hp


@rpc("any_peer", "call_local", "reliable")
func consumeItem(item, item_prop):
	if "hp" in item_prop:
		get_heal.rpc( 100 )#item["hp"])
	Inventory.removeItem(str(name),item)

@rpc("authority", "call_local", "reliable")
func increaseScore(by):
	hp += by * 5
	maxHP += by * 5
	attackDamage += by
	speed += by
	Multihelper.spawnedPlayers[int(str(name))]["score"] += by
	Multihelper.player_score_updated.emit()

func objectDestroyed():
	increaseScore.rpc(Constants.OBJECT_SCORE_GAIN)

func mobKilled():
	increaseScore.rpc(Constants.MOB_SCORE_GAIN)

func enemyPlayerKilled():
	increaseScore.rpc(Constants.PK_SCORE_GAIN)

func getDamage(causer, amount, _type):
	hp -= amount
	if (hp - amount) <= 0 and causer.is_in_group("player"):
		causer.player_killed.emit()

func die():
	if !multiplayer.is_server():
		return
	var peerId := int(str(name))
	Multihelper._deregister_character.rpc(peerId) # für Server
	dropInventory()
	Multihelper.showSpawnUI.rpc_id(peerId)
	queue_free()
	#if peerId in multiplayer.get_peers(): # Multiplayer Server
		#Multihelper.showSpawnUI.rpc_id(peerId)

func dropInventory():
	var inventoryDict = Inventory.inventories
	for item in inventoryDict.keys():
		Items.spawnPickups(item, position, inventoryDict[item].size() )
	Inventory.inventories[name] = {}
	Inventory.inventoryUpdated.emit(name)
	Inventory.inventories.erase(name)

@rpc("any_peer", "call_local", "reliable")
func tryEquipItem(id):
	if id in Inventory.inventories[name].keys():
		equipItem.rpc(id)

@rpc("any_peer", "call_local", "reliable")
func equipItem(id):
	equippedItem = id
	%Hands.visible = false
	%HeldItem.texture = load("res://assets/items/"+id+".png")
	if multiplayer.is_server() and "scene" in Items.equips[id]:
		for c in %Equipment.get_children():
			c.queue_free()
		var itemScene := load("res://scenes/character/equipments/"+Items.equips[id]["scene"]+".tscn")
		var item = itemScene.instantiate()
		%Equipment.add_child(item)
		item.data = {"player": str(name), "item": id}

@rpc("any_peer", "call_local", "reliable")
func unequipItem():
	equippedItem = ""
	%Hands.visible = true
	%HeldItem.texture = null
	if multiplayer.is_server():
		for c in %Equipment.get_children():
			c.queue_free()



func itemRemoved(id, item):
	if !multiplayer.is_server():
		return
	if id == str(name) and item == equippedItem:
		unequipItem.rpc()

func projectileHit(body):
	body.getDamage(self, attackDamage, damageType)


# GODOT Server
func action(vel, angle, doingAction):
	if vel != Vector2.ZERO:
		last_angle = vel.angle()
	angle = last_angle
	moveProcess(vel, angle, doingAction)

	var inputData = {
		"vel": vel,
		"angle": angle,
		"doingAction": doingAction
	}
	sendInputstwo.rpc_id(1, inputData)
	sendPos.rpc(position)

@rpc("any_peer", "call_local", "reliable")
func sendInputstwo(data):
	moveServer(data["vel"], data["angle"], data["doingAction"])

@rpc("any_peer", "call_local", "reliable")
func moveServer(vel, angle, doingAction):
	$MovingParts.rotation = angle
	handleAnims(vel,doingAction)

@rpc("any_peer", "call_local", "reliable")
func sendPos(pos):
	#print("position"+str(position))
	position = pos

func moveProcess(vel, angle, doingAction):
	velocity = vel
	if velocity != Vector2.ZERO:
		move_and_slide()
	$MovingParts.rotation = angle
	handleAnims(vel,doingAction)

func handleAnims(vel, doing_action):
	if doing_action:
		var action_anim = Items.equips[equippedItem]["attack"] if equippedItem else "punching"
		if !$AnimationPlayer.is_playing() or $AnimationPlayer.current_animation != action_anim:
			$AnimationPlayer.play(action_anim)
	elif vel != Vector2.ZERO:
		if !$AnimationPlayer.is_playing() or $AnimationPlayer.current_animation != "walking":
			$AnimationPlayer.play("walking")
	else:
		$AnimationPlayer.stop()


func _on_back_to_menu_pressed() -> void:
	# 1. Zerstöre die aktuelle Node
	#queue_free()
	
	# 2. Lade die MainMenu Szene
	#var menu_scene : PackedScene = load("res://scenes/ui/mainMenu/mainMenu.tscn")  # Pfad anpassen
	#var menu_node : Node = menu_scene.instantiate()
	
	# 2. Lade die Szene für das Menü / Game Node
	var game_scene: PackedScene = load("res://scenes/game/Game.tscn")  # Pfad anpassen
	var game_node: Node = game_scene.instantiate()
	#%Multihelper.setGameNode(game_node)
	get_tree().change_scene_to_packed(game_scene)
	#game_node.setMainMenu(menu_node)
	# Hier binde an den passenden Parent — z. B. die Root-Node oder ein UI-Container
	#get_tree().get_root().add_child(game_node)
	
	# Optional: mache Pause rückgängig, oder setze Status
	#get_tree().paused = false
