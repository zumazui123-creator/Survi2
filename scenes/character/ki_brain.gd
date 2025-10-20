extends Node2D

@onready var player = $".."
@onready var status = %PlayerStatus
var last_tile_position = Vector2i(0,0)
var tile_position = Vector2i(0,0)
var tmp_status

var navigation: Node2D
var main: Node2D

func _ready() -> void:
	main 		= get_node("/root/Game/Level/Main")
	navigation  = main.get_node("NavHelper")

func _on_start_ki_button_pressed() -> void:
	player.send_to_ws_peer("start ki")

func punish_stuck_on_tile(reward):
	if last_tile_position == tile_position:
		reward /= 3
	return reward

func get_walkable_neighbor_tiles():
	var walkable_tiles = navigation.get_walkable_tiles_in_distance(tile_position,0,1)
	var walkable_obs = [0,0,0,0]
	print(walkable_tiles)
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
	reward = punish_stuck_on_tile(reward)
		
	return reward
	
func send_ki_obs():
	var reward = calculate_reward()
	var target_tile_position = Multihelper.map.laby_map.endPosition
	var walkable_tiles_bool = get_walkable_neighbor_tiles()
	var ki_data = {
			"obs": [tmp_status["tile_position"][0], 
					tmp_status["tile_position"][1], 
					target_tile_position.x, 
					target_tile_position.y,
					walkable_tiles_bool[0],
					walkable_tiles_bool[1],
					walkable_tiles_bool[2],
					walkable_tiles_bool[3],
					 ],
			"reward": reward,
			"done": player.EndUI.visible,
			"status": tmp_status
			}
	player.send_to_ws_peer(JSON.stringify(ki_data))
