extends Node
class_name DebugCodePlayer

@export var player : Player
													 
# Mapping user commands to player_movement actions
var command_map = {
	Strings.ACTION_WALK_LEFT: "walkLeft",
	Strings.ACTION_WALK_RIGHT: "walkRight",
	Strings.ACTION_WALK_UP: "walkUp",
	Strings.ACTION_WALK_DOWN: "walkDown"
}

func play(code: String) -> void:
	if not player:
		push_error("DebugCodePlayer: Player node not assigned")
		return

	var lines = code.split("\n", false)
	for line in lines:
		line = line.strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		
		# Parse command and optional count
		var parts = line.split(" ", false)
		var cmd = parts[0]
		var count = 1
		
		if parts.size() > 1:
			if parts[1].is_valid_int():
				count = parts[1].to_int()
		
		await execute_command(cmd, count)
	
	print("Code execution finished")

func execute_command(cmd: String, count: int) -> void:
	if cmd in command_map:
		var movement_action = command_map[cmd]
		for i in range(count):
			await move_step(movement_action)
	elif cmd == Strings.ACTION_ATTACK:
		if player.player_combat:
			player.player_combat.hit(Strings.ACTION_ATTACK)
	else:
		print("Unknown command: ", cmd)

func move_step(action: String) -> void:
	while player.player_movement.is_moving():
		await get_tree().process_frame
	
	player.player_movement.press_action(action)
	
	await get_tree().process_frame
	
	while player.player_movement.is_moving():
		await get_tree().process_frame
