extends Node
class_name CodePlayer

@export var player : Player
@onready var function_handler =  $"../../../FunctionHandler"													 

func parse_lines_with_repeat(lines: PackedStringArray, start := 0) -> Dictionary:
	var result: Array = []
	var i := start

	while i < lines.size():
		var line = lines[i].strip_edges()

		if line == "" or line.begins_with("#"):
			i += 1
			continue

		# --- Ende eines Blocks ---
		if line == Strings.KEYWORD_END:
			return {
				"lines": result,
				"index": i
			}

		# --- Wiederholung ---
		if line.begins_with("wiederhole"):
			var parts = line.split(" ", false)

			if parts.size() >= 3 and parts[1].is_valid_int():
				var repeat_count = parts[1].to_int()

				var parsed = parse_lines_with_repeat(lines, i + 1)
				var block = parsed.lines
				i = parsed.index

				for r in range(repeat_count):
					result.append_array(block)
			else:
				push_error("Invalid repeat syntax: " + line)
		else:
			result.append(line)

		i += 1

	return {
		"lines": result,
		"index": i
	}

func parse_lines_with_func(lines: PackedStringArray, start := 0) -> PackedStringArray:
	var result: Array = [] 
	for line in lines:
		if line in function_handler.functions.keys():
			for func_line in function_handler.functions[line]:
				result.append(line)
		result.append(line)
	
	return result
	
func play(code: String) -> void:
	if not player:
		push_error("DebugCodePlayer: Player node not assigned")
		return

	var lines 				 = code.split("\n", false)
	lines  			   	 	 = parse_lines_with_func(lines)
	var parsed_repeats = parse_lines_with_repeat(lines)
	lines 						 = parsed_repeats.lines

	for line in lines:
		
		line = line.strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		
		
		# Parse command and args
		line = Strings.remap_code_cmd_to_action("de", line)
		var parts = line.split(" ", false)
		await execute_command(parts)
	
	print("Code execution finished")

func execute_command(parts: PackedStringArray) -> void:
	if parts.is_empty():
		return

	if parts[0] == "":
		return
		
	if "walk" in parts[0]:
		await walk(parts)
		
	elif parts[0] == Strings.ACTION_ATTACK:
		if player.player_combat:
			await player.player_combat.hit(Strings.ACTION_ATTACK)
		
	elif parts[0] == Strings.ACTION_BUILD or parts[0] == Strings.ACTION_PAINT:
		await build(parts[0],parts)
		
	elif Strings.ACTION_USE_ITEM in parts[0]:
		var item_id = player.player_items.use_item(parts)
		print("Using item:"+str(item_id))
		
	elif Strings.ACTION_SAY in parts[0]:
		say(parts)
	else:
		print("Unknown command: ", parts[0])
			
			
func build(cmd,parts) -> void:
	if parts.size() < 3:
		print("Command missing arguments: ", parts)
		return
		
	var type = parts[1]
	var dir_str = parts[2]
	
	if dir_str in Strings.ACTION_NAMES[Strings.current_locale] and Strings.ACTION_NAMES[Strings.current_locale][dir_str] in Strings.direction_map:
		var dir = Strings.direction_map[Strings.ACTION_NAMES[Strings.current_locale][dir_str]]
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

func walk(parts) -> void:
	var count = 1
	if parts.size() > 1 and parts[1].is_valid_int():
		count = parts[1].to_int()
		
	var movement_action = parts[0] 
	for i in range(count):
		await move_step(movement_action)	
					
func move_step(action: String) -> void:
	while player.player_movement.is_moving():
		await get_tree().process_frame
	
	player.player_movement.press_action(action)
	
	await get_tree().process_frame
	
	while player.player_movement.is_moving():
		await get_tree().process_frame

func say(parts):
	var text = ""
	if len(parts) > 1: 
		text = parts[1].trim_prefix(Strings.ACTION_SAY)
	player.sendMessage(text)
