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

var direction_map = {
	Strings.ACTION_WALK_LEFT: Vector2i.LEFT,
	Strings.ACTION_WALK_RIGHT: Vector2i.RIGHT,
	Strings.ACTION_WALK_UP: Vector2i.UP,
	Strings.ACTION_WALK_DOWN: Vector2i.DOWN
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
		
		# Parse command and args
		var parts = line.split(" ", false)
		await execute_command(parts)
	
	print("Code execution finished")

func execute_command(parts: PackedStringArray) -> void:
	if parts.is_empty():
		return
		
	var cmd = parts[0]

	if cmd in command_map:
		var count = 1
		if parts.size() > 1 and parts[1].is_valid_int():
			count = parts[1].to_int()
			
		var movement_action = command_map[cmd]
		for i in range(count):
			await move_step(movement_action)
			
	elif cmd == Strings.ACTION_ATTACK:
		if player.player_combat:
			player.player_combat.hit(Strings.ACTION_ATTACK)
			
	elif cmd == Strings.ACTION_BUILD or cmd == Strings.ACTION_PAINT:
		if parts.size() < 3:
			print("Command missing arguments: ", parts)
			return
			
		var type = parts[1]
		var dir_str = parts[2]
		
		if dir_str in direction_map:
			var dir = direction_map[dir_str]
			var current_map_pos = player.player_movement.current_map_position
			var target_map_pos = current_map_pos + dir
			
			if cmd == Strings.ACTION_BUILD:
				# Convert to world position for building placement
				if player.player_building:
					player.player_building.build(type, target_map_pos)
					
			elif cmd == Strings.ACTION_PAINT:
				if player.player_building:
					player.player_building.paint(type, target_map_pos)
		else:
			print("Unknown direction: ", dir_str)
			
	else:
		print("Unknown command: ", cmd)

func move_step(action: String) -> void:
	while player.player_movement.is_moving():
		await get_tree().process_frame
	
	player.player_movement.press_action(action)
	
	await get_tree().process_frame
	
	while player.player_movement.is_moving():
		await get_tree().process_frame
