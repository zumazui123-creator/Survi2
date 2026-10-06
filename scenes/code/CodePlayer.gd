extends Node
class_name CodePlayer

signal execution_started(command_count: int)
signal command_started(command_index: int, command: String)
signal execution_finished()
signal execution_cancelled()
signal runtime_error(message: String)

const MAX_EXPANDED_LINES := 1000

@export var player: CharacterBody2D

var is_running := false
var _execution_id := 0


func cancel() -> void:
	if not is_running:
		return

	_execution_id += 1
	is_running = false
	_reset_execution_effects()
	execution_cancelled.emit()


func parse_lines_with_repeat(lines: PackedStringArray, start := 0) -> Dictionary:
	var result: Array[String] = []
	var i := start
	var repeat_keyword := Strings.KEYWORD_REPEAT.get_slice(" ", 0)

	while i < lines.size():
		var line := lines[i].strip_edges()

		if line == "" or line.begins_with("#"):
			i += 1
			continue

		if line == Strings.KEYWORD_END:
			return {"lines": result, "index": i, "closed": true}

		if line.get_slice(" ", 0) == repeat_keyword:
			var parts := line.split(" ", false)
			if parts.size() < 3 or not parts[1].is_valid_int():
				return _parse_error("Ungültige Wiederholung: " + line, i)

			var repeat_count := parts[1].to_int()
			if repeat_count < 0:
				return _parse_error("Die Anzahl der Wiederholungen darf nicht negativ sein.", i)

			var parsed := parse_lines_with_repeat(lines, i + 1)
			if parsed.has("error"):
				return parsed
			if not parsed.closed:
				return _parse_error("Der Wiederholungsblock hat kein '" + Strings.KEYWORD_END + "'.", i)

			var block: Array = parsed.lines
			if block.size() * repeat_count + result.size() > MAX_EXPANDED_LINES:
				return _parse_error("Das Programm überschreitet das Limit von %d Befehlen." % MAX_EXPANDED_LINES, i)

			for _repeat_index in range(repeat_count):
				result.append_array(block)
			i = parsed.index
		else:
			result.append(line)
			if result.size() > MAX_EXPANDED_LINES:
				return _parse_error("Das Programm überschreitet das Limit von %d Befehlen." % MAX_EXPANDED_LINES, i)

		i += 1

	return {"lines": result, "index": i, "closed": false}


func parse_lines_with_func(lines: PackedStringArray, functions: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	for source_line in lines:
		var line := source_line.strip_edges()
		if functions.has(line):
			for function_line in functions[line]:
				result.append(function_line)
		else:
			result.append(source_line)
	return result


func play(code: String, functions: Dictionary = {}) -> void:
	if not is_instance_valid(player):
		_report_error("CodePlayer: Player node not assigned")
		return

	if is_running:
		cancel()

	_execution_id += 1
	var current_execution_id := _execution_id
	var lines := parse_lines_with_func(code.split("\n", false), functions)
	var parsed_repeats := parse_lines_with_repeat(lines)
	if parsed_repeats.has("error"):
		_report_error(parsed_repeats.error)
		return
	if parsed_repeats.closed:
		_report_error("Unerwartetes '%s' in Zeile %d." % [Strings.KEYWORD_END, parsed_repeats.index + 1])
		return

	lines = PackedStringArray(parsed_repeats.lines)
	is_running = true
	execution_started.emit(lines.size())
	_apply_execution_effects(lines.size())

	for command_index in range(lines.size()):
		if not _is_current_execution(current_execution_id):
			return

		var line := lines[command_index].strip_edges()
		if line == "" or line.begins_with("#"):
			continue

		line = Strings.remap_code_cmd_to_action(Strings.current_locale, line)
		if line == "":
			_report_error("Unbekannter Befehl in Zeile %d." % (command_index + 1))
			continue

		var parts := line.split(" ", false)
		command_started.emit(command_index, line)
		await execute_command(parts, current_execution_id)

	_finish_execution(current_execution_id)


func execute_command(parts: PackedStringArray, execution_id: int) -> void:
	if parts.is_empty() or parts[0] == "" or not _is_current_execution(execution_id):
		return

	var command := parts[0]
	if command in [Strings.ACTION_WALK_LEFT, Strings.ACTION_WALK_RIGHT, Strings.ACTION_WALK_UP, Strings.ACTION_WALK_DOWN]:
		await walk(parts, execution_id)
	elif command == Strings.ACTION_ATTACK:
		if player.combat:
			await player.combat.hit(Strings.ACTION_ATTACK)
	elif command == Strings.ACTION_BUILD or command == Strings.ACTION_PAINT:
		build(command, parts)
	elif command == Strings.ACTION_USE_ITEM:
		player.items.use_item(parts)
	elif command == Strings.ACTION_SAY:
		say(parts)
	else:
		_report_error("Unbekannter Befehl: " + command)


func build(command: String, parts: PackedStringArray) -> void:
	if parts.size() < 3:
		_report_error("Dem Befehl fehlen Argumente: " + " ".join(parts))
		return

	var building_type := parts[1]
	var direction_name := parts[2]
	var localized_actions: Dictionary = Strings.ACTION_NAMES.get(Strings.current_locale, {})
	if not localized_actions.has(direction_name):
		_report_error("Unbekannte Richtung: " + direction_name)
		return

	var direction_action: String = localized_actions[direction_name]
	if not Strings.direction_map.has(direction_action):
		_report_error("Unbekannte Richtung: " + direction_name)
		return

	var target_map_position: Vector2i = player.movement.current_map_position + Strings.direction_map[direction_action]
	if not player.building:
		_report_error("PlayerBuilding ist nicht verfügbar.")
		return

	if command == Strings.ACTION_BUILD:
		player.building.build(building_type, target_map_position)
	else:
		player.building.paint(building_type, target_map_position)


func walk(parts: PackedStringArray, execution_id: int) -> void:
	var count := 1
	if parts.size() > 1 and parts[1].is_valid_int():
		count = maxi(parts[1].to_int(), 0)

	for _step in range(count):
		if not _is_current_execution(execution_id):
			return
		await move_step(parts[0], execution_id)


func move_step(action: String, execution_id: int) -> void:
	while player.movement.is_moving():
		if not _is_current_execution(execution_id):
			return
		await get_tree().process_frame

	player.movement.press_action(action)
	await get_tree().process_frame

	while player.movement.is_moving():
		if not _is_current_execution(execution_id):
			return
		await get_tree().process_frame


func say(parts: PackedStringArray) -> void:
	if parts.size() <= 1:
		player.sendMessage("")
		return
	player.sendMessage(" ".join(parts.slice(1)))


func _apply_execution_effects(command_count: int) -> void:
	player.movement.set_code_input_active(true)
	player.movement.apply_code_speed_bonus(1.0 + command_count * 0.05)

	var code_particles := player.get_node_or_null("codeParticles") as CPUParticles2D
	if code_particles:
		code_particles.emitting = true
		code_particles.amount = 10 + command_count * 2
		code_particles.speed_scale = 1.0 + command_count * 0.02


func _reset_execution_effects() -> void:
	if not is_instance_valid(player):
		return
	player.movement.set_code_input_active(false)
	player.movement.reset_code_speed_bonus()
	var code_particles := player.get_node_or_null("codeParticles") as CPUParticles2D
	if code_particles:
		code_particles.emitting = false


func _finish_execution(execution_id: int) -> void:
	if not _is_current_execution(execution_id):
		return
	is_running = false
	_reset_execution_effects()
	execution_finished.emit()


func _is_current_execution(execution_id: int) -> bool:
	return is_running and execution_id == _execution_id


func _parse_error(message: String, line_index: int) -> Dictionary:
	return {"lines": [], "index": line_index, "closed": false, "error": "%s (Zeile %d)" % [message, line_index + 1]}


func _report_error(message: String) -> void:
	push_error(message)
	runtime_error.emit(message)


func _exit_tree() -> void:
	cancel()
