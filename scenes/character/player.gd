extends CharacterBody2D
class_name Player

var act : String = ""

@onready var status = $PlayerStatus
@onready var ai_control = $AIControl
@onready var workTaskText = %workTaskText
@onready var net_control = $NetControl
@onready var player_movement = $PlayerMovement
@onready var player_animation = $PlayerAnimation
@onready var player_combat = $PlayerCombat
@export var player_building : PlayerBuilding
@onready var player_items = $PlayerItems
@onready var player_status = %PlayerStatus
@onready var code_edit = %CodeEdit
@export var playerName : String:
	set(value):
		playerName = value
		$PlayerStatus.setPlayerName(value)

var characterFile : String:
	set(value):
		characterFile = value
		if is_node_ready() and characterFile != "":
			player_animation.set_character_sprite(characterFile)

var EndUI     : Control
var local_setup_done := false

func _enter_tree():
	set_multiplayer_authority(name.to_int())
	if str(multiplayer.get_unique_id()) != name:
		$CodeLayer.hide()
		$CodeLayer.process_mode = Node.PROCESS_MODE_DISABLED

func save_tilemap_layer_to_file(layer: TileMapLayer) -> void:
	var lines: Array[String] = []

	for cell in layer.get_used_cells():
		var source_id = layer.get_cell_source_id(cell)
		var atlas = layer.get_cell_atlas_coords(cell)
		var alternative = layer.get_cell_alternative_tile(cell)

		var line = "%d,%d,%d,%d,%d,%d" % [
			cell.x,
			cell.y,
			source_id,
			atlas.x,
			atlas.y,
			alternative
		]

		lines.append(line)

	var file := FileAccess.open("level1.txt", FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()


func _ready():
	#var tile_map = Multihelper.map.tile_map
	#save_tilemap_layer_to_file(Multihelper.map.tile_map)

	print("Player : "+str(characterFile))
	
	Multihelper.data_loaded.connect(_on_multidata_received)
	Multihelper.player_spawned.connect(_on_player_spawned_info)
	Multihelper.player_disconnected.connect(disconnected)
	
	if characterFile == "":
		try_recover_body()
	else:
		_setup_local_player()
				
	if characterFile != "":
		player_animation.set_character_sprite(characterFile)


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
		#var player_combat_node = get_node("PlayerCombat")
		#if player_combat_node:
			#Inventory.itemRemoved.connect(player_items.itemRemoved)
			#player_combat_node.mob_killed.connect(player_combat_node.mobKilled)
			#player_combat_node.player_killed.connect(player_combat_node.enemyPlayerKilled)
			#player_combat_node.object_destroyed.connect(player_combat_node.objectDestroyed)
	
	_setup_local_player()

func _setup_local_player():
	if local_setup_done or name != str(multiplayer.get_unique_id()):
		return
	local_setup_done = true
	print("player HUD")
	var main = get_parent().get_parent()
	EndUI = main.get_node("HUD/EndUI")
	$Camera2D.enabled = true

func getDamage(causer, amount, _type):
	player_combat.getDamage(causer, amount, _type)
		
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


func _physics_process(_delta: float) -> void:
	if str(multiplayer.get_unique_id()) != name:
		return
	player_movement.input()
	player_movement.tile_move()
	player_movement.win_condition()

func resetPlayer():
	var difLevelMode = %DifModeButton.get_selected_id()
	if difLevelMode > 0:
		Multihelper.spawnPlayers()


# func action(vel, angle, doingAction):
# 	var player_movement_node = get_node("PlayerMovement")
# 	if player_movement_node:
# 		player_movement_node.action(vel, angle, doingAction)

# @rpc("any_peer", "call_local", "reliable")
# func sendInputstwo(data):
# 	var player_movement_node = get_node("PlayerMovement")
# 	if player_movement_node:
# 		player_movement_node.moveServer(data["vel"], data["angle"], data["doingAction"])

@rpc("any_peer", "call_local", "reliable")
func sendPos(pos):
	position = pos
	player_movement.current_map_position = Multihelper.map.tile_map.local_to_map( position )

func _on_back_to_menu_pressed() -> void:
	var game_scene: PackedScene = load(Constants.PATH_GAME_SCENE)
	get_tree().change_scene_to_packed(game_scene)
