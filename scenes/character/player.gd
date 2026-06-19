extends CharacterBody2D
class_name Player

var act : String = ""

@onready var p_status: PlayerStatus = $PlayerStatus
@onready var p_ai_control = $AIControl
@onready var p_workTaskText = %workTaskText
@onready var p_net_control = $NetControl
@onready var p_movement: PlayerMovement = $PlayerMovement
@onready var p_animation: AnimationPlayer = $AnimationPlayer
@onready var p_combat: PlayerCombat = $PlayerCombat
@export var p_building: PlayerBuilding
@onready var p_items: PlayerItems = $PlayerItems
@onready var code_edit = %CodeEdit
@export var playerName : String:
	set(value):
		playerName = value
		p_status.setPlayerName(value)

var characterFile : String:
	set(value):
		characterFile = value
		if is_node_ready() and characterFile != "":
			p_animation.set_character_sprite(characterFile)

var EndUI     : Control
var local_setup_done := false

func _enter_tree():
	set_multiplayer_authority(name.to_int())
	if str(multiplayer.get_unique_id()) != name:
		$CodeLayer.hide()
		$CodeLayer.process_mode = Node.PROCESS_MODE_DISABLED

func _ready():
	# ... (existing code)
	var line = Line2D.new()
	line.name = "PathLine"
	line.default_color = Color(1, 1, 1, 0.3)
	line.width = 2
	line.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	line.z_index = -1 # Draw behind other elements
	add_child(line)
	p_movement.path_line = line
	
	Multihelper.data_loaded.connect(_on_multidata_received)
	# ... (rest of existing code)
	Multihelper.player_spawned.connect(_on_player_spawned_info)
	Multihelper.player_disconnected.connect(disconnected)
	
	if characterFile == "":
		try_recover_body()
	else:
		_setup_local_player()
				
	if characterFile != "":
		p_animation.set_character_sprite(characterFile)


func _on_multidata_received():
	try_recover_body()

func _on_player_spawned_info(id, info):
	if str(id) == name:
		try_recover_body()

func try_recover_body():
	var pid = name.to_int()
	if not Multihelper.spawnedPlayers.has(pid):
		return
		
	var info = Multihelper.spawnedPlayers[pid]
	
	if playerName == "" and info.has("name"):
		self.playerName = info["name"]
		
	if characterFile == "" and info.has("body"):
		print("Recovered body from Multihelper: " + str(info["body"]))
		self.characterFile = info["body"]
		#var p_combat_node = get_node("PlayerCombat")
		#if p_combat_node:
			#Inventory.itemRemoved.connect(p_items.itemRemoved)
			#p_combat_node.mob_killed.connect(p_combat_node.mobKilled)
			#p_combat_node.player_killed.connect(p_combat_node.enemyPlayerKilled)
			#p_combat_node.object_destroyed.connect(p_combat_node.objectDestroyed)
	
	_setup_local_player()

func _setup_local_player():
	if local_setup_done or name != str(multiplayer.get_unique_id()):
		return
	local_setup_done = true
	print("player HUD")
	var main = get_parent().get_parent()
	EndUI = main.get_node("HUD/EndUI")
	$Camera2D.enabled = true

@rpc("any_peer", "call_local", "reliable")
func getDamage(causer, amount, _type):
	p_combat.getDamage(causer, amount, _type)
		
func visibilityFilter(id):
	if id == int(str(name)):
		return false
	return true

@rpc("any_peer", "call_local", "reliable")
func sendMessage(text):
	#if multiplayer.is_server():
		var messageBoxScene := preload(Constants.PATH_CHAT_MESSAGE_SCENE)
		var messageBox := messageBoxScene.instantiate()
		%PlayerMessages.add_child(messageBox, true)
		messageBox.text = str(text)

func disconnected(id):
	if str(id) == name:
		var p_combat_node = get_node("PlayerCombat")
		if p_combat_node:
			p_combat_node.die()


func _physics_process(_delta: float) -> void:
	if str(multiplayer.get_unique_id()) != name:
		return
	p_movement.input()
	p_movement.tile_move()
	win_condition()

func win_condition():
	p_status.char_info["terminated"] = false
	win_laby()

func win_laby():
	if Multihelper.level["end"] == Constants.END_LABY:
		var current_map_position = Multihelper.map.tile_map.local_to_map( position )
		var end_goal_position = Multihelper.map.endPosition
		if current_map_position == end_goal_position:
			current_map_position = Vector2i()
			EndUI.setLabel("Level Abgeschlossen!")
			p_status.char_info["terminated"] = true
			EndUI.visible = true
			
func resetPlayer():
	var difLevelMode = %DifModeButton.get_selected_id()
	if difLevelMode > 0:
		Multihelper.spawnPlayers()


@rpc("any_peer", "call_local", "reliable")
func sendPos(pos):
	position = pos
	p_movement.current_map_position = Multihelper.map.tile_map.local_to_map( position )

func _on_back_to_menu_pressed() -> void:
	var game_scene: PackedScene = load(Constants.PATH_GAME_SCENE)
	get_tree().change_scene_to_packed(game_scene)
	
