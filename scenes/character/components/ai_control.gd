extends Node

@onready var player = $".."
@onready var status = %PlayerStatus
@onready var net_control = $"../NetControl"

var last_tile_position = Vector2i(0,0)
var tile_position = Vector2i(0,0)
var tmp_status

var navigation: Node2D
var main: Node2D

var visited_walkable_tiles = []

func _ready() -> void:
	main 		= get_node("/root/Game/Level/Main")
	navigation  = main.get_node("NavHelper")

func _on_start_ki_button_pressed() -> void:
	net_control.send_rpc_request(Strings.RPC_METHOD_START_KI, {"message": ""})


func get_walkable_neighbor_tiles():
	var walkable_tiles = navigation.get_walkable_tiles_in_distance(tile_position,0,1)
	var walkable_obs = [0,0,0,0]

	for wt in walkable_tiles:
		var tx = tile_position.x - wt.x
		var ty = tile_position.y - wt.y
		if abs(tx) + abs(ty) == 2:
			continue
		if tx == 1:
			walkable_obs[0]   = 1
		if tx == -1:
			walkable_obs[3]  = 1
		if ty == 1:
			walkable_obs[1]   = 1
		if ty == -1:
			walkable_obs[2]   = 1

	return walkable_obs

func calculate_reward():
	if tmp_status:
		last_tile_position = Vector2i( tmp_status["tile_position"][0], tmp_status["tile_position"][1] )
	tmp_status = status.getPlayerStatus()
	tile_position = Vector2i( tmp_status["tile_position"][0], tmp_status["tile_position"][1] )

	var reward = player.get_reward()
	#reward = punish_stuck_on_tile(reward)
	#reward = punish_same_pattern(reward)

	return reward

func send_ki_obs():
	var target_tile_position = Multihelper.get_goal()
	var walkable_tiles_bool = get_walkable_neighbor_tiles()
	tmp_status = status.getPlayerStatus()
	var ki_data = {
			"obs": {
					"goal": [ target_tile_position.x, target_tile_position.y ],
					"free_directions" : walkable_tiles_bool,
					 },
			"done"	: tmp_status["terminated"],
			"status": tmp_status
			}
	net_control.send_text(JSON.stringify(ki_data))
