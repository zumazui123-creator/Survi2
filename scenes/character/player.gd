extends CharacterBody2D

var act : String = ""

@onready var status = $PlayerStatus
@onready var kiBrain = $AIControl
@onready var workTaskText = $PlayerStatus/WorkContainer/VBoxContainer/workTaskText
@onready var net_control = $NetControl
@onready var player_movement = $PlayerMovement
@onready var player_animation = $PlayerAnimation
@onready var player_combat = $PlayerCombat

@onready var code_edit = %CodeEdit
@export var playerName : String:
	set(value):
		playerName = value
		$PlayerStatus.setPlayerName(value)

@export var characterFile : String:
	set(value):
		characterFile = value
		if player_animation:
			player_animation.set_character_sprite(value)

var inventory : Control
var EndUI     : Control

func _ready():
	if multiplayer.is_server():
		var player_combat_node = get_node("PlayerCombat")
		if player_combat_node:
			Inventory.itemRemoved.connect(player_combat_node.itemRemoved)
			player_combat_node.mob_killed.connect(player_combat_node.mobKilled)
			player_combat_node.player_killed.connect(player_combat_node.enemyPlayerKilled)
			player_combat_node.object_destroyed.connect(player_combat_node.objectDestroyed)

	if name == str(multiplayer.get_unique_id()):
		print("player HUD")
		var main = get_parent().get_parent()

		inventory = main.get_node("HUD/Inventory")
		EndUI = main.get_node("HUD/EndUI")
		inventory.player = self
		$Camera2D.enabled = true
		var player_movement_node = get_node("PlayerMovement")
		if player_movement_node:
			player_movement_node.level_completed.connect(on_level_completed)
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

func _physics_process(delta: float) -> void:
	if str(multiplayer.get_unique_id()) != name:
		return

	act = net_commander()
	press_action(act)
	
	var player_movement_node = get_node("PlayerMovement")
	if player_movement_node:
		player_movement_node.tile_move()
		player_movement_node.win_condition()

func get_reward():
	var reward = 0
	if Multihelper.level["type"] == 100:
		var end_goal_position = Multihelper.map.laby_map.endPosition
		reward = 1/current_map_position.distance_to(end_goal_position)
	return reward

func resetPlayer():
	var difLevelMode = %DifModeButton.get_selected_id()
	if difLevelMode > 0:
		Multihelper.spawnPlayers()


func press_action(inp_action : String):
	if inp_action == "":
		return
	inp_action = inp_action.strip_edges()
	
	var player_combat_node = get_node("PlayerCombat")
	if player_combat_node:
		player_combat_node.hit(inp_action)
	
	if Strings.ACTION_SAY in inp_action:
		print("sage:"+inp_action)
		var text = inp_action.trim_prefix(Strings.ACTION_SAY)
		sendMessage(text)
		net_control.send_text("Godot: " + inp_action)

	if Strings.ACTION_USE_ITEM in inp_action:
		var item_id_str = inp_action.trim_prefix(Strings.ACTION_USE_ITEM).strip_edges()
		print("action: "+inp_action+" item_id_str: "+item_id_str)
		var item_id : int = -1
		if item_id_str.is_valid_int():
			item_id = int(item_id_str)
			inventory.selectionChanged.emit(item_id)

		net_control.send_text("Godot: " + inp_action + ", item: "+str(item_id))

	var player_movement_node = get_node("PlayerMovement")
	if player_movement_node:
		player_movement_node.press_action(inp_action)
	
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

func on_level_completed(message):
	EndUI.setLabel(message)
	EndUI.retry()