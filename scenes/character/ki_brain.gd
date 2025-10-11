extends Node2D

@onready var player = $".."
@onready var status = %PlayerStatus

func _on_start_ki_button_pressed() -> void:
	player.send_to_ws_peer("start ki")

func send_ki_obs():
	print("reward")
	var tmp_status = status.getPlayerStatus()
	var endPosition = Multihelper.map.tile_map.map_to_local( Multihelper.map.laby_map.endPosition )
	var ki_data = {
			"obs": [tmp_status["position"][0], tmp_status["position"][1], endPosition.x, endPosition.y ],
			"reward": player.get_reward(), # TODO: Reward-Logik
			"done": false,
			"status": tmp_status
			}
	player.send_to_ws_peer(JSON.stringify(ki_data))
