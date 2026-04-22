extends Node

var playerScenePath = preload("res://scenes/character/player.tscn")
var isHost = true
var mapSeed = randi()
var level : Dictionary = {"level": 0,"type": Constants.MAP_MAIN}

var is_stopped :bool = false

var map: Map
var main: Node2D

var lang : String = "de"

signal player_connected(peer_id)
signal player_disconnected(peer_id)
signal server_disconnected
signal player_spawned(peer_id, player_info)
signal player_despawned
signal player_registered
@warning_ignore("unused_signal")
signal player_score_updated
signal data_loaded

const PORT = Constants.PORT
const DEFAULT_SERVER_IP = Constants.SERVER_IP

var spawnedPlayers = {}
var connectedPlayers = []
var syncedPlayers = []

var player_info = {"name": ""}
var goal_tile = Vector2i(0,0)
var code_player_enabled 	= true
var host_as_player_enabled 	= true

var game : Node
func setGameNode(gameNode : Node):
	if game:
		game.queue_free()
	game = gameNode
	
func _ready():
	game = get_node("/root/Game")

func join_game(address = ""):
	print("join_game - disabled for web")
	load_main_game()

func create_game():
	if not game:
		game = get_node_or_null("/root/Game")
	print("starting local game")
	player_connected.emit(1, player_info)
	game.start_game()

func remove_multiplayer_peer():
	print("remove_multiplayer_peer")

func _on_player_connected(id):
	print("player connected with id "+str(id))

func _register_character(new_player_info, requested_id := 0):
	print("player register:"+str(new_player_info))
	var new_player_id = 1
	if requested_id != 0:
		new_player_id = requested_id
	spawnedPlayers[new_player_id] = new_player_info
	player_spawned.emit(new_player_id, new_player_info)
	player_registered.emit()
	
func _deregister_character(id):
	print("_deregister_character:"+str(id))
	spawnedPlayers.erase(id)
	player_despawned.emit()

func _on_player_disconnected(id):
	print("_on_player_disconnected:"+str(id))
	connectedPlayers.erase(id)
	spawnedPlayers.erase(id)
	syncedPlayers.erase(id)
	player_disconnected.emit(id)

func _on_connected_ok():
	print("_on_connected_ok")
	game.start_game()
	var peer_id = 1
	connectedPlayers.append(peer_id)
	player_connected.emit(peer_id)
	load_main_game()
	
func load_main_game():
	print("load_main_game")
	player_loaded()

func player_loaded():
	print("player_loaded")
	var sender_id = 1
	main = game.get_node("Level/Main")
	var mapData := {
		"seed": mapSeed,
		"level": level,
	}
	sendGameData(spawnedPlayers, mapData)
	set_process(false)

func sendGameData(playerData, mapData):
	print("sendGameData")
	spawnedPlayers = playerData
	mapSeed = mapData["seed"]
	level 	= mapData["level"]
	main = game.get_node("Level/Main")
	loadMap()
	data_loaded.emit()
	set_process(true)

func _on_connected_fail():
	pass

func _on_server_disconnected():
	server_disconnected.emit()

func loadMap():
	print("loadMap()")
	main = get_node("/root/Game/Level/Main")
	map  = main.get_node("Map")
	map.generateMap(level)

func get_map_position(coords : Vector2i):
	print("get_map_position")
	return map.tile_map.local_to_map(coords)
	
func requestSpawn(playerName, id, characterFile):
	print("requestSpawn: "+str(characterFile))
	var new_player_info = player_info.duplicate()
	new_player_info["name"] = playerName
	new_player_info["body"] = characterFile
	new_player_info["score"] = 0
	spawnedPlayers[id] = new_player_info
	_register_character(new_player_info, id)
	addPlayer(playerName, id, characterFile)

func addPlayer(playerName, id, characterFile):
	print("addPlayer: "+str(characterFile))
	var newPlayer 		:= playerScenePath.instantiate()
	newPlayer.playerName = playerName
	newPlayer.characterFile = characterFile
	newPlayer.name = str(id)
	main.get_node("Players").add_child(newPlayer)
	spawnPlayer(newPlayer)

func getPlayers():
	if not main: return
	var players = main.get_node("Players")
	if players:
		return players
	

func spawnPlayers():
	var players = getPlayers()
	if players:
		for newPlayer in players.get_children():
			spawnPlayer(newPlayer)
	
func spawnPlayer(newPlayer):
	var spawnPosition = Vector2i(0,0)
	if map.spawnPosition > Vector2i(0,0):
		spawnPosition = map.spawnPosition
	else :
		if  len(spawnedPlayers) > 1:
			print("spawn near players")
			var player1 = getPlayers().get_child(0)
			spawnPosition = player1.player_movement.current_map_position
		else:
			spawnPosition = map.walkable_tiles.pick_random()
	newPlayer.workTaskText.text = workTask.getWorkTask(self.level)
	newPlayer.sendPos(map.tile_map.map_to_local( spawnPosition ))

func showSpawnUI():
	print("showSpawnUI")
	var spawnPlayerScene := preload("res://scenes/ui/spawn/spawnPlayer.tscn")
	var retry 	  = spawnPlayerScene.instantiate()
	retry.retry   = true
	retry.visible = true
	main.get_node("HUD").add_child(retry)

func set_goal(tile):
	goal_tile = tile
	
func get_goal():
	if map.level_type == Constants.MAP_KI:
		return goal_tile
	else: 
		return map.laby_map.endPosition
		
func setMobs(initialSpawnObjects : int , maxObjects : int ,
			maxEnemiesPerPlayer : int,
			maxAnimalsPerPlayer : int ):
	main.setMobs( initialSpawnObjects , maxObjects ,
			 		maxEnemiesPerPlayer,
			 		maxAnimalsPerPlayer )

func setLevel(set_level : Dictionary):
	self.level = set_level
