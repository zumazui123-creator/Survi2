extends Node
class_name CodePlayer

signal execution_started(command_count: int)
signal command_started(command_index: int, command: String)
signal execution_finished()
signal execution_cancelled()
signal runtime_error(message: String)

@export var player: CharacterBody2D
@export var code_particles: CPUParticles2D

var is_running: bool = false
var _execution_id: int = 0
var _executed_command_count: int = 0
var _parser: CodeParser = CodeParser.new()


func cancel() -> void:
	if not is_running:
		return

	_execution_id += 1
	is_running = false
	_reset_execution_effects()
	execution_cancelled.emit()


func play(code: String, functions: Dictionary = {}) -> void:
	if not is_instance_valid(player):
		_report_error("CodePlayer: Player node not assigned")
		return

	if is_running:
		cancel()

	_execution_id += 1
	var current_execution_id: int = _execution_id
	var parse_result: CodeParser.ParseResult = _parser.parse(code, functions, Strings.current_locale)
	if parse_result.has_error():
		_report_error(parse_result.error_message)
		return
	if not player.movement.set_code_input_active(true):
		_report_error("Der Player wird gerade von einer anderen Steuerung kontrolliert.")
		return

	is_running = true
	_executed_command_count = 0
	var maximum_command_count: int = parse_result.get_max_command_count()
	execution_started.emit(maximum_command_count)
	_apply_execution_effects(maximum_command_count)

	for node: CodeParser.ParsedNode in parse_result.commands:
		if not _is_current_execution(current_execution_id):
			return
		await execute_node(node, current_execution_id)

	_finish_execution(current_execution_id)


func execute_node(node: CodeParser.ParsedNode, execution_id: int) -> void:
	if node == null or not _is_current_execution(execution_id):
		return

	if node is CodeParser.ParsedCommand:
		var command: CodeParser.ParsedCommand = node as CodeParser.ParsedCommand
		command_started.emit(_executed_command_count, command.source_text)
		_executed_command_count += 1
		await execute_command(command, execution_id)
		return

	if node is CodeParser.ConditionalBlock:
		var conditional_block: CodeParser.ConditionalBlock = node as CodeParser.ConditionalBlock
		if not _matches_condition(conditional_block.condition):
			return
		for child: CodeParser.ParsedNode in conditional_block.body:
			if not _is_current_execution(execution_id):
				return
			await execute_node(child, execution_id)


func _matches_condition(condition: CodeParser.CodeCondition) -> bool:
	if condition == null or not is_instance_valid(player) or not is_instance_valid(player.sensor):
		return false
	return player.sensor.matches_code_condition(condition.subject, condition.direction_action)


func execute_command(command: CodeParser.ParsedCommand, execution_id: int) -> void:
	if command == null or not _is_current_execution(execution_id):
		return

	var action: String = String(command.action)
	if action in [Strings.ACTION_WALK_LEFT, Strings.ACTION_WALK_RIGHT, Strings.ACTION_WALK_UP, Strings.ACTION_WALK_DOWN]:
		await walk(action, command.arguments, execution_id)
	elif action == Strings.ACTION_ATTACK:
		if player.combat:
			await player.combat.hit(Strings.ACTION_ATTACK)
	elif action == Strings.ACTION_COMBO:
		if not player.combo:
			_report_error("PlayerCombo ist nicht verfügbar.")
		elif not player.combo.try_execute_combo(command.arguments):
			_report_error("Unbekannte Combo: " + " ".join(command.arguments))
	elif action == Strings.ACTION_DRINK:
		if not player.combat:
			_report_error("PlayerCombat ist nicht verfügbar.")
		else:
			var drank: bool = await player.combat.drink()
			if not drank:
				_report_error("Zum Trinken muss das Hand-Tile Wasser berühren.")
	elif action == Strings.ACTION_BUILD or action == Strings.ACTION_PAINT:
		build(action, command.arguments)
	elif action == Strings.ACTION_USE_ITEM:
		player.items.use_item(command.to_parts())
	elif action == Strings.ACTION_SAY:
		say(command.arguments)
	else:
		_report_error("Unbekannter Befehl: " + action)


func build(action: String, arguments: PackedStringArray) -> void:
	if arguments.size() != 2:
		_report_error("Dem Bau-Befehl fehlen Argumente.")
		return

	var building_type: String = arguments[0]
	var direction_action: String = arguments[1]
	if not Strings.direction_map.has(direction_action):
		_report_error("Unbekannte Richtung: " + direction_action)
		return

	var target_map_position: Vector2i = player.movement.current_map_position + Strings.direction_map[direction_action]
	if not player.building:
		_report_error("PlayerBuilding ist nicht verfügbar.")
		return

	if action == Strings.ACTION_BUILD:
		player.building.build(building_type, target_map_position)
	else:
		player.building.paint(building_type, target_map_position)


func walk(action: String, arguments: PackedStringArray, execution_id: int) -> void:
	var count: int = 1
	if not arguments.is_empty():
		count = arguments[0].to_int()

	for step_index: int in range(count):
		if not _is_current_execution(execution_id):
			return
		var step_succeeded: bool = await move_step(action, execution_id)
		if not step_succeeded:
			return


func move_step(action: String, execution_id: int) -> bool:
	while player.movement.is_moving():
		if not _is_current_execution(execution_id):
			return false
		await player.movement.tile_step_resolved

	if not _is_current_execution(execution_id):
		return false
	if not player.movement.request_code_step(action):
		_report_error("Das Ziel-Tile ist blockiert: " + action)
		return false

	var step_result: Array = await player.movement.tile_step_resolved
	if not _is_current_execution(execution_id):
		return false
	if step_result.size() < 2 or not bool(step_result[1]):
		_report_error("Die Bewegung wurde durch eine Kollision blockiert: " + action)
		return false
	return true


func say(arguments: PackedStringArray) -> void:
	if arguments.is_empty():
		player.sendMessage("")
		return
	player.sendMessage(" ".join(arguments))


func _apply_execution_effects(command_count: int) -> void:
	player.movement.apply_code_speed_bonus(1.0 + command_count * 0.05)

	if code_particles:
		code_particles.emitting = true
		code_particles.amount = 10 + command_count * 2
		code_particles.speed_scale = 1.0 + command_count * 0.02


func _reset_execution_effects() -> void:
	if not is_instance_valid(player):
		return
	player.movement.set_code_input_active(false)
	player.movement.reset_code_speed_bonus()
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


func _report_error(message: String) -> void:
	push_error(message)
	runtime_error.emit(message)


func _exit_tree() -> void:
	cancel()
