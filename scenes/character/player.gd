extends CharacterBody2D

var act : String = ""

@onready var status = $PlayerStatus
@onready var ai_control = $AIControl
@onready var workTaskText = $PlayerStatus/WorkContainer/VBoxContainer/workTaskText
@onready var net_control = $NetControl
@onready var player_movement = $PlayerMovement
@onready var player_animation = $PlayerAnimation
@onready var player_combat = $PlayerCombat
@onready var player_items = $PlayerItems
@onready var player_status = %PlayerStatus
@onready var code_edit = %CodeEdit
@export var playerName : String:
	set(value):
		playerName = value
		$PlayerStatus.setPlayerName(value)

var characterFile : String


var EndUI     : Control

func _ready():
	print("Player : "+str(characterFile))
	player_animation.set_character_sprite(characterFile)
	#if multiplayer.is_server():
		#var player_combat_node = get_node("PlayerCombat")
		#if player_combat_node:
			#Inventory.itemRemoved.connect(player_items.itemRemoved)
			#player_combat_node.mob_killed.connect(player_combat_node.mobKilled)
			#player_combat_node.player_killed.connect(player_combat_node.enemyPlayerKilled)
			#player_combat_node.object_destroyed.connect(player_combat_node.objectDestroyed)

	if name == str(multiplayer.get_unique_id()):
		print("player HUD")
		var main = get_parent().get_parent()
		EndUI = main.get_node("HUD/EndUI")
		$Camera2D.enabled = true
		
	Multihelper.player_disconnected.connect(disconnected)

func visibilityFilter(id):
	if id == int(str(name)):
		return false
	return true

@rpc("any_peer", "call_local", "reliable")
func sendMessage(text):
	if multiplayer.is_server():
		var messageBoxScene := preload(Constants.PATH_CHAT_MESSAGE_SCENE)
		var messageBox := messageBoxScene.instantiate()
		%PlayerMessages.add_child(messageBox, true)
		messageBox.text = str(text)

func disconnected(id):
	if str(id) == name:
		var player_combat_node = get_node("PlayerCombat")
		if player_combat_node:
			player_combat_node.die()

func net_commander():
	var net_action = net_control.net_commander()
	if net_action == Strings.CMD_END_SEQUENCE:
		resetPlayer()
		net_control.send_text(net_action)
	if net_action == Strings.CMD_RESET:
		Multihelper.spawnPlayers()
	return net_action

func _physics_process(_delta: float) -> void:
	if str(multiplayer.get_unique_id()) != name:
		return

	act = net_commander()
	press_action(act)
	player_movement.input()
	player_movement.tile_move()
	player_movement.win_condition()
	player_combat.hit(act)

func resetPlayer():
	var difLevelMode = %DifModeButton.get_selected_id()
	if difLevelMode > 0:
		Multihelper.spawnPlayers()

func press_action(inp_action : String):
	if inp_action == "":
		return
	inp_action = inp_action.strip_edges()

	if Strings.ACTION_SAY in inp_action:
		print("sage:"+inp_action)
		var text = inp_action.trim_prefix(Strings.ACTION_SAY)
		sendMessage(text)
		net_control.send_text("Godot: " + inp_action)

	if Strings.ACTION_USE_ITEM in inp_action:
		var item_id = player_items.use_item(inp_action)
		net_control.send_text("Godot: " + inp_action + ", item: "+str(item_id))
		
	player_movement.press_action(inp_action)
	
	if Multihelper.level in range(0,2) and "End Sequenz" in inp_action:
		code_edit.text = ""
		var end = Multihelper.map.laby_map.spawnPosition
		var start = Multihelper.map.tile_map.map_to_local( end )
		position = start
		net_control.send_text("Godot: " + inp_action)
		print("End Sequenz")

# GODOT Server
func action(vel, angle, doingAction):
	var player_movement_node = get_node("PlayerMovement")
	if player_movement_node:
		player_movement_node.action(vel, angle, doingAction)

@rpc("any_peer", "call_local", "reliable")
func sendInputstwo(data):
	var player_movement_node = get_node("PlayerMovement")
	if player_movement_node:
		player_movement_node.moveServer(data["vel"], data["angle"], data["doingAction"])

@rpc("any_peer", "call_local", "reliable")
func sendPos(pos):
	position = pos

func _on_back_to_menu_pressed() -> void:
	var game_scene: PackedScene = load(Constants.PATH_GAME_SCENE)
	get_tree().change_scene_to_packed(game_scene)
