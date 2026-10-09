extends Node
class_name CodePlayer

enum LoopControlState {
	NONE,
	BREAK,
	CONTINUE,
}

signal execution_started(command_count: int)
signal source_line_started(source_line: int, source_text: String)
signal command_started(command_index: int, command: String, source_line: int)
signal execution_finished()
signal execution_cancelled()
signal runtime_error(message: String)
signal pause_changed(paused: bool)
signal execution_gate_changed()
signal variables_changed(snapshot: Dictionary)

@export var player: CharacterBody2D
@export var code_particles: CPUParticles2D
@export_range(1, 10000, 1) var max_runtime_commands: int = 1000

var is_running: bool = false
var is_paused: bool = false
var _execution_id: int = 0
var _executed_command_count: int = 0
var _step_budget: int = 0
var _loop_control_state: int = LoopControlState.NONE
var _parser: CodeParser = CodeParser.new()
var _execution_context: CodeExecutionContext = CodeExecutionContext.new()
var _expression_evaluator: CodeExpressionEvaluator = CodeExpressionEvaluator.new()


func cancel() -> void:
	if not is_running:
		return

	_execution_id += 1
	is_running = false
	is_paused = false
	_step_budget = 0
	_loop_control_state = LoopControlState.NONE
	execution_gate_changed.emit()
	pause_changed.emit(false)
	_reset_execution_effects()
	execution_cancelled.emit()


func pause() -> void:
	if not is_running or is_paused:
		return
	is_paused = true
	_step_budget = 0
	pause_changed.emit(true)


func resume() -> void:
	if not is_running or not is_paused:
		return
	is_paused = false
	_step_budget = 0
	execution_gate_changed.emit()
	pause_changed.emit(false)


func step_once() -> void:
	if not is_running:
		return
	is_paused = true
	_step_budget += 1
	execution_gate_changed.emit()
	pause_changed.emit(true)


func play(code: String, functions: Dictionary = {}, start_paused: bool = false) -> void:
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
	is_paused = start_paused
	_step_budget = 0
	_executed_command_count = 0
	_loop_control_state = LoopControlState.NONE
	_execution_context.clear()
	variables_changed.emit(_execution_context.get_variables())
	var maximum_command_count: int = parse_result.get_max_command_count()
	execution_started.emit(maximum_command_count)
	pause_changed.emit(is_paused)
	_apply_execution_effects(maximum_command_count)

	for node: CodeParser.ParsedNode in parse_result.commands:
		if not _is_current_execution(current_execution_id):
			return
		await execute_node(node, current_execution_id)

	_finish_execution(current_execution_id)


func execute_node(node: CodeParser.ParsedNode, execution_id: int) -> void:
	if node == null or not _is_current_execution(execution_id):
		return
	if not await _wait_for_execution_permission(execution_id):
		return
	source_line_started.emit(node.source_line, node.source_text)
	if _executed_command_count >= max_runtime_commands:
		_report_error(
			"Das Laufzeitlimit von %d Programmschritten wurde erreicht." % max_runtime_commands,
			node.source_line
		)
		cancel()
		return
	var execution_index: int = _executed_command_count
	_executed_command_count += 1

	if node is CodeParser.ParsedCommand:
		var command: CodeParser.ParsedCommand = node as CodeParser.ParsedCommand
		command_started.emit(
			execution_index,
			command.source_text,
			command.source_line
		)
		await execute_command(command, execution_id)
		return

	if node is CodeParser.Assignment:
		var assignment: CodeParser.Assignment = node as CodeParser.Assignment
		var assignment_result: Dictionary = _evaluate_expression(
			assignment.expression,
			assignment.source_line
		)
		if not bool(assignment_result.get("ok", false)):
			return
		_execution_context.set_variable(assignment.variable_name, assignment_result.get("value"))
		variables_changed.emit(_execution_context.get_variables())
		return

	if node is CodeParser.LoopControl:
		var loop_control: CodeParser.LoopControl = node as CodeParser.LoopControl
		_loop_control_state = LoopControlState.BREAK \
			if loop_control.kind == CodeParser.LoopControl.Kind.BREAK \
			else LoopControlState.CONTINUE
		return

	if node is CodeParser.ConditionalBlock:
		var conditional_block: CodeParser.ConditionalBlock = node as CodeParser.ConditionalBlock
		var condition_matches: bool = conditional_block.condition == null \
			or _matches_condition(conditional_block.condition, conditional_block.source_line)
		if not condition_matches:
			if conditional_block.alternative != null:
				await execute_node(conditional_block.alternative, execution_id)
			return
		for child: CodeParser.ParsedNode in conditional_block.body:
			if not _is_current_execution(execution_id):
				return
			await execute_node(child, execution_id)
			if _loop_control_state != LoopControlState.NONE:
				return
		return

	if node is CodeParser.RepeatBlock:
		var repeat_block: CodeParser.RepeatBlock = node as CodeParser.RepeatBlock
		var count_result: Dictionary = _evaluate_expression(
			repeat_block.count_expression,
			repeat_block.source_line
		)
		if not bool(count_result.get("ok", false)):
			return
		var count_value: Variant = count_result.get("value")
		if not count_value is int:
			_report_error("Die Wiederholungsanzahl muss eine ganze Zahl sein.", node.source_line)
			return
		var repeat_count: int = int(count_value)
		if repeat_count < 0:
			_report_error("Die Wiederholungsanzahl darf nicht negativ sein.", node.source_line)
			return
		if repeat_count > max_runtime_commands:
			_report_error(
				"Die Wiederholungsanzahl darf höchstens %d sein." % max_runtime_commands,
				node.source_line
			)
			return
		for _repeat_index: int in range(repeat_count):
			var repeat_control: int = await _execute_loop_body(repeat_block.body, execution_id)
			if repeat_control == LoopControlState.BREAK:
				_loop_control_state = LoopControlState.NONE
				return
			if repeat_control == LoopControlState.CONTINUE:
				_loop_control_state = LoopControlState.NONE
				continue
		return

	if node is CodeParser.ConditionLoopBlock:
		var condition_loop: CodeParser.ConditionLoopBlock = node as CodeParser.ConditionLoopBlock
		while _is_current_execution(execution_id):
			var condition_matches: bool = _matches_condition(
				condition_loop.condition,
				condition_loop.source_line
			)
			var should_execute: bool = condition_matches \
				if condition_loop.mode == CodeParser.ConditionLoopBlock.Mode.WHILE \
				else not condition_matches
			if not should_execute:
				return
			var condition_control: int = await _execute_loop_body(
				condition_loop.body,
				execution_id
			)
			if condition_control == LoopControlState.BREAK:
				_loop_control_state = LoopControlState.NONE
				return
			if condition_control == LoopControlState.CONTINUE:
				_loop_control_state = LoopControlState.NONE
		return

	if node is CodeParser.RangeLoopBlock:
		await _execute_range_loop(node as CodeParser.RangeLoopBlock, execution_id)
		return

	if node is CodeParser.ForEachBlock:
		await _execute_for_each_loop(node as CodeParser.ForEachBlock, execution_id)
		return

	if node is CodeParser.ForeverBlock:
		var forever_loop: CodeParser.ForeverBlock = node as CodeParser.ForeverBlock
		while _is_current_execution(execution_id):
			var forever_control: int = await _execute_loop_body(forever_loop.body, execution_id)
			if forever_control == LoopControlState.BREAK:
				_loop_control_state = LoopControlState.NONE
				return
			if forever_control == LoopControlState.CONTINUE:
				_loop_control_state = LoopControlState.NONE
		return


func _execute_loop_body(
		body: Array[CodeParser.ParsedNode],
		execution_id: int
	) -> int:
	for child: CodeParser.ParsedNode in body:
		if not _is_current_execution(execution_id):
			return LoopControlState.NONE
		await execute_node(child, execution_id)
		if _loop_control_state != LoopControlState.NONE:
			return _loop_control_state
	return LoopControlState.NONE


func _execute_range_loop(
		loop: CodeParser.RangeLoopBlock,
		execution_id: int
	) -> void:
	var start_result: Dictionary = _evaluate_expression(loop.start_expression, loop.source_line)
	if not bool(start_result.get("ok", false)):
		return
	var end_result: Dictionary = _evaluate_expression(loop.end_expression, loop.source_line)
	if not bool(end_result.get("ok", false)):
		return
	var start_value: Variant = start_result.get("value")
	var end_value: Variant = end_result.get("value")
	if not start_value is int or not end_value is int:
		_report_error("Die Grenzen einer Für-Schleife müssen ganze Zahlen sein.", loop.source_line)
		return
	var start_number: int = int(start_value)
	var end_number: int = int(end_value)
	var iteration_count: int = absi(end_number - start_number) + 1
	if iteration_count > max_runtime_commands:
		_report_error(
			"Eine Für-Schleife darf höchstens %d Durchläufe haben." % max_runtime_commands,
			loop.source_line
		)
		return
	var step_size: int = 1 if start_number <= end_number else -1
	for current_value: int in range(start_number, end_number + step_size, step_size):
		_execution_context.set_variable(loop.variable_name, current_value)
		variables_changed.emit(_execution_context.get_variables())
		var range_control: int = await _execute_loop_body(loop.body, execution_id)
		if range_control == LoopControlState.BREAK:
			_loop_control_state = LoopControlState.NONE
			return
		if range_control == LoopControlState.CONTINUE:
			_loop_control_state = LoopControlState.NONE
			continue


func _execute_for_each_loop(
		loop: CodeParser.ForEachBlock,
		execution_id: int
	) -> void:
	var values: Array = _get_loop_collection(loop)
	for value: Variant in values:
		if not _is_current_execution(execution_id):
			return
		_execution_context.set_variable(loop.variable_name, value)
		variables_changed.emit(_execution_context.get_variables())
		var each_control: int = await _execute_loop_body(loop.body, execution_id)
		if each_control == LoopControlState.BREAK:
			_loop_control_state = LoopControlState.NONE
			return
		if each_control == LoopControlState.CONTINUE:
			_loop_control_state = LoopControlState.NONE
			continue


func _get_loop_collection(loop: CodeParser.ForEachBlock) -> Array:
	if loop.collection_name == &"inventory":
		var inventory: Dictionary = Inventory.getItems(str(player.name))
		var item_ids: Array = []
		for item_id_value: Variant in inventory.keys():
			if int(inventory.get(item_id_value, 0)) > 0:
				item_ids.append(String(item_id_value))
		item_ids.sort()
		return item_ids
	if loop.collection_name == &"sensor" and is_instance_valid(player.sensor):
		var sensor_tiles: Array[Vector2i] = player.sensor.get_code_collection_tiles(
			loop.sensor_subject
		)
		var result: Array = []
		result.assign(sensor_tiles)
		return result
	return []


func _matches_condition(condition: CodeParser.CodeCondition, source_line: int) -> bool:
	if condition == null or not is_instance_valid(player):
		return false
	if condition.mode == CodeParser.CodeCondition.Mode.EXPRESSION:
		var left_result: Dictionary = _evaluate_expression(condition.left_expression, source_line)
		if not bool(left_result.get("ok", false)):
			return false
		var right_result: Dictionary = _evaluate_expression(condition.right_expression, source_line)
		if not bool(right_result.get("ok", false)):
			return false
		return _compare_values(
			left_result.get("value"),
			right_result.get("value"),
			condition.comparison_operator,
			source_line
		)
	if not is_instance_valid(player.sensor):
		return false
	if condition.mode == CodeParser.CodeCondition.Mode.DISTANCE:
		return player.sensor.matches_code_distance_condition(
			condition.subject,
			condition.comparison_operator,
			condition.distance_tiles
		)
	return player.sensor.matches_code_condition(condition.subject, condition.direction_action)


func _evaluate_expression(expression: CodeParser.CodeExpression, source_line: int) -> Dictionary:
	var result: Dictionary = _expression_evaluator.evaluate(expression, _execution_context, player)
	if not bool(result.get("ok", false)):
		_report_error(String(result.get("error", "Ungültiger Ausdruck.")), source_line)
	return result


func _compare_values(
		left_value: Variant,
		right_value: Variant,
		comparison_operator: StringName,
		source_line: int
	) -> bool:
	if comparison_operator == Strings.CONDITION_COMPARISON_EQUAL:
		if _is_number(left_value) and _is_number(right_value):
			return is_equal_approx(float(left_value), float(right_value))
		return left_value == right_value
	if not _is_number(left_value) or not _is_number(right_value):
		_report_error("'kleiner' und 'größer' können nur Zahlen vergleichen.", source_line)
		return false
	if comparison_operator == Strings.CONDITION_COMPARISON_LESS:
		return float(left_value) < float(right_value)
	if comparison_operator == Strings.CONDITION_COMPARISON_GREATER:
		return float(left_value) > float(right_value)
	_report_error("Unbekannter Vergleich.", source_line)
	return false


func _is_number(value: Variant) -> bool:
	return value is int or value is float


func get_variables() -> Dictionary:
	return _execution_context.get_variables()


func execute_command(command: CodeParser.ParsedCommand, execution_id: int) -> void:
	if command == null or not _is_current_execution(execution_id):
		return

	var action: String = String(command.action)
	if action in [Strings.ACTION_WALK_LEFT, Strings.ACTION_WALK_RIGHT, Strings.ACTION_WALK_UP, Strings.ACTION_WALK_DOWN]:
		await walk(action, command.arguments, execution_id, command.source_line)
	elif action == Strings.ACTION_ATTACK:
		if player.combat:
			await player.combat.hit(Strings.ACTION_ATTACK)
	elif action == Strings.ACTION_COMBO:
		if not player.combo:
			_report_error("PlayerCombo ist nicht verfügbar.", command.source_line)
		elif not player.combo.try_execute_combo(command.arguments):
			_report_error("Unbekannte Combo: " + " ".join(command.arguments), command.source_line)
	elif action == Strings.ACTION_DRINK:
		if not player.combat:
			_report_error("PlayerCombat ist nicht verfügbar.", command.source_line)
		else:
			var drank: bool = await player.combat.drink()
			if not drank:
				_report_error(
					"Zum Trinken muss das Hand-Tile Wasser berühren.",
					command.source_line
				)
	elif action == Strings.ACTION_BUILD or action == Strings.ACTION_PAINT:
		build(action, command.arguments, command.source_line)
	elif action == Strings.ACTION_USE_ITEM:
		if not player.items.use_item(command.arguments):
			_report_error(
				"Der angegebene Inventar-Slot ist leer oder ungültig.",
				command.source_line
			)
	elif action == Strings.ACTION_DROP_ITEM:
		if not player.items.drop_item(command.arguments):
			_report_error(
				"Das Item konnte nicht gedroppt werden. Prüfe Slot und freie Nachbar-Tiles.",
				command.source_line
			)
	elif action == Strings.ACTION_SAY:
		say(command.arguments)
	else:
		_report_error("Unbekannter Befehl: " + action, command.source_line)


func build(action: String, arguments: PackedStringArray, source_line: int) -> void:
	if arguments.size() != 2:
		_report_error("Dem Bau-Befehl fehlen Argumente.", source_line)
		return

	var building_type: String = arguments[0]
	var direction_action: String = arguments[1]
	if not Strings.direction_map.has(direction_action):
		_report_error("Unbekannte Richtung: " + direction_action, source_line)
		return

	var target_map_position: Vector2i = player.movement.current_map_position + Strings.direction_map[direction_action]
	if not player.building:
		_report_error("PlayerBuilding ist nicht verfügbar.", source_line)
		return

	if action == Strings.ACTION_BUILD:
		player.building.build(building_type, target_map_position)
	else:
		player.building.paint(building_type, target_map_position)


func walk(
		action: String,
		arguments: PackedStringArray,
		execution_id: int,
		source_line: int
	) -> void:
	var count: int = 1
	if not arguments.is_empty():
		var count_result: Dictionary = _resolve_integer_argument(
			arguments[0],
			source_line,
			"Die Schrittanzahl"
		)
		if not bool(count_result.get("ok", false)):
			return
		count = int(count_result.get("value", 0))
		if count < 0:
			_report_error("Die Schrittanzahl darf nicht negativ sein.", source_line)
			return
		if count > max_runtime_commands:
			_report_error(
				"Die Schrittanzahl darf höchstens %d sein." % max_runtime_commands,
				source_line
			)
			return

	for _step_index: int in range(count):
		if not _is_current_execution(execution_id):
			return
		var step_succeeded: bool = await move_step(action, execution_id, source_line)
		if not step_succeeded:
			return


func move_step(action: String, execution_id: int, source_line: int) -> bool:
	while player.movement.is_moving():
		if not _is_current_execution(execution_id):
			return false
		await player.movement.tile_step_resolved

	if not _is_current_execution(execution_id):
		return false
	if not player.movement.request_code_step(action):
		_report_error("Das Ziel-Tile ist blockiert: " + action, source_line)
		return false

	var step_result: Array = await player.movement.tile_step_resolved
	if not _is_current_execution(execution_id):
		return false
	if step_result.size() < 2 or not bool(step_result[1]):
		# A blocked step is also useful: the player keeps facing the requested
		# direction so the next attack or drink command can target that tile.
		return false
	return true


func _resolve_integer_argument(value: String, source_line: int, label: String) -> Dictionary:
	if value.is_valid_int():
		return {"ok": true, "value": value.to_int()}
	if not _execution_context.has_variable(value):
		var suggestion: String = _execution_context.find_similar_variable(value)
		var message: String = "Die Variable '%s' existiert nicht." % value
		if not suggestion.is_empty():
			message += " Meintest du '%s'?" % suggestion
		_report_error(message, source_line)
		return {"ok": false}
	var variable_value: Variant = _execution_context.get_variable(value)
	if not variable_value is int:
		_report_error("%s muss eine ganze Zahl sein." % label, source_line)
		return {"ok": false}
	return {"ok": true, "value": variable_value}


func say(arguments: PackedStringArray) -> void:
	if arguments.is_empty():
		player.sendMessage("")
		return
	if arguments.size() == 1 and _execution_context.has_variable(arguments[0]):
		player.sendMessage(str(_execution_context.get_variable(arguments[0])))
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
	is_paused = false
	_step_budget = 0
	_loop_control_state = LoopControlState.NONE
	pause_changed.emit(false)
	_reset_execution_effects()
	execution_finished.emit()


func _is_current_execution(execution_id: int) -> bool:
	return is_running and execution_id == _execution_id


func _wait_for_execution_permission(execution_id: int) -> bool:
	while _is_current_execution(execution_id) and is_paused and _step_budget <= 0:
		await execution_gate_changed
	if not _is_current_execution(execution_id):
		return false
	if is_paused and _step_budget > 0:
		_step_budget -= 1
	return true


func _report_error(message: String, source_line: int = 0) -> void:
	var formatted_message: String = message
	if source_line > 0 and not formatted_message.contains("(Zeile "):
		formatted_message += " (Zeile %d)" % source_line
	push_error(formatted_message)
	runtime_error.emit(formatted_message)


func _exit_tree() -> void:
	cancel()
