extends RefCounted
class_name CodeParser

const MAX_EXPANDED_COMMANDS: int = 1000
const MAX_FUNCTION_DEPTH: int = 32
const MAX_BLOCK_DEPTH: int = 32


class ParsedNode:
	extends RefCounted

	var source_line: int
	var source_text: String


class ParsedCommand:
	extends ParsedNode

	var action: StringName
	var arguments: PackedStringArray

	func _init(
			parsed_action: StringName,
			parsed_arguments: PackedStringArray,
			parsed_source_line: int,
			parsed_source_text: String
		) -> void:
		action = parsed_action
		arguments = parsed_arguments
		source_line = parsed_source_line
		source_text = parsed_source_text

	func to_parts() -> PackedStringArray:
		var parts: PackedStringArray = PackedStringArray([String(action)])
		parts.append_array(arguments)
		return parts


class CodeCondition:
	extends RefCounted

	var subject: StringName
	var direction_action: StringName

	func _init(parsed_subject: StringName, parsed_direction_action: StringName) -> void:
		subject = parsed_subject
		direction_action = parsed_direction_action


class ConditionalBlock:
	extends ParsedNode

	var condition: CodeCondition
	var body: Array[ParsedNode] = []

	func _init(
			parsed_condition: CodeCondition,
			parsed_body: Array[ParsedNode],
			parsed_source_line: int,
			parsed_source_text: String
		) -> void:
		condition = parsed_condition
		body = parsed_body
		source_line = parsed_source_line
		source_text = parsed_source_text


class ParseResult:
	extends RefCounted

	var commands: Array[ParsedNode] = []
	var error_message: String = ""

	func has_error() -> bool:
		return not error_message.is_empty()

	func get_max_command_count() -> int:
		var command_count: int = 0
		for node: ParsedNode in commands:
			command_count += _count_commands_in_node(node)
		return command_count

	func _count_commands_in_node(node: ParsedNode) -> int:
		if node is ParsedCommand:
			return 1
		if node is ConditionalBlock:
			var conditional_block: ConditionalBlock = node as ConditionalBlock
			var command_count: int = 0
			for child: ParsedNode in conditional_block.body:
				command_count += _count_commands_in_node(child)
			return command_count
		return 0


func parse(
		source_code: String,
		functions: Dictionary = {},
		locale: String = Strings.current_locale
	) -> ParseResult:
	var result: ParseResult = ParseResult.new()
	if not Strings.ACTION_NAMES.has(locale):
		result.error_message = "Unbekannte Code-Sprache: %s" % locale
		return result

	var source_lines: Array[Dictionary] = _create_source_lines(source_code)
	var expanded_functions: Dictionary = _expand_functions(source_lines, functions)
	if expanded_functions.has("error"):
		result.error_message = String(expanded_functions.error)
		return result

	var parsed_program: Dictionary = _parse_block(expanded_functions.lines, 0, false, locale, 0)
	if parsed_program.has("error"):
		result.error_message = String(parsed_program.error)
		return result

	result.commands = parsed_program.nodes
	return result


func _create_source_lines(source_code: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var lines: PackedStringArray = source_code.split("\n", true)
	for line_index: int in range(lines.size()):
		result.append({
			"text": lines[line_index],
			"line_number": line_index + 1,
		})
	return result


func _expand_functions(
		lines: Array[Dictionary],
		functions: Dictionary,
		call_stack: Array[String] = []
	) -> Dictionary:
	var result: Array[Dictionary] = []

	for line_data: Dictionary in lines:
		var line: String = String(line_data.text).strip_edges()
		if line.is_empty() or line.begins_with("#") or not functions.has(line):
			result.append(line_data)
			if result.size() > MAX_EXPANDED_COMMANDS:
				return _error(
					"Das Programm überschreitet das Limit von %d Befehlen." % MAX_EXPANDED_COMMANDS,
					int(line_data.line_number)
				)
			continue

		if line in call_stack:
			var recursion_path: String = " -> ".join(call_stack + [line])
			return _error(
				"Rekursive Funktion erkannt: %s" % recursion_path,
				int(line_data.line_number)
			)
		if call_stack.size() >= MAX_FUNCTION_DEPTH:
			return _error(
				"Die maximale Funktionstiefe von %d wurde überschritten." % MAX_FUNCTION_DEPTH,
				int(line_data.line_number)
			)

		var function_body: Dictionary = _normalize_function_body(functions[line])
		if not bool(function_body.valid):
			return _error("Ungültiger Funktionsinhalt für '%s'." % line, int(line_data.line_number))

		var function_lines: Array[Dictionary] = []
		for function_line: String in function_body.lines:
			function_lines.append({
				"text": String(function_line),
				"line_number": int(line_data.line_number),
			})

		var nested_stack: Array[String] = call_stack.duplicate()
		nested_stack.append(line)
		var expanded_body: Dictionary = _expand_functions(function_lines, functions, nested_stack)
		if expanded_body.has("error"):
			return expanded_body
		result.append_array(expanded_body.lines)
		if result.size() > MAX_EXPANDED_COMMANDS:
			return _error(
				"Das Programm überschreitet das Limit von %d Befehlen." % MAX_EXPANDED_COMMANDS,
				int(line_data.line_number)
			)

	return {"lines": result}


func _normalize_function_body(body: Variant) -> Dictionary:
	if body is String:
		return {"valid": true, "lines": String(body).split("\n", true)}
	if body is PackedStringArray:
		return {"valid": true, "lines": body}
	if body is Array:
		var lines: PackedStringArray = PackedStringArray()
		for line: Variant in body:
			lines.append(String(line))
		return {"valid": true, "lines": lines}
	return {"valid": false, "lines": PackedStringArray()}


func _parse_block(
		lines: Array[Dictionary],
		start_index: int,
		expects_end: bool,
		locale: String,
		block_depth: int
	) -> Dictionary:
	var result: Array[ParsedNode] = []
	var line_index: int = start_index
	var repeat_template: PackedStringArray = Strings.KEYWORD_REPEAT.split(" ", false)
	var repeat_keyword: String = repeat_template[0]

	while line_index < lines.size():
		var line_data: Dictionary = lines[line_index]
		var line: String = String(line_data.text).strip_edges()
		var source_line: int = int(line_data.line_number)

		if line.is_empty() or line.begins_with("#"):
			line_index += 1
			continue

		if line == Strings.KEYWORD_END:
			if not expects_end:
				return _error("Unerwartetes '%s'." % Strings.KEYWORD_END, source_line)
			return {"nodes": result, "index": line_index, "closed": true}

		if block_depth >= MAX_BLOCK_DEPTH:
			return _error(
				"Die maximale Blocktiefe von %d wurde überschritten." % MAX_BLOCK_DEPTH,
				source_line
			)

		var first_word: String = line.get_slice(" ", 0).to_lower()
		if first_word == repeat_keyword:
			var repeat_parts: PackedStringArray = line.split(" ", false)
			if not _is_valid_repeat_syntax(repeat_parts, repeat_template):
				return _error("Ungültige Wiederholung: %s" % line, source_line)

			var repeat_count: int = repeat_parts[1].to_int()
			if repeat_count < 0:
				return _error("Die Anzahl der Wiederholungen darf nicht negativ sein.", source_line)

			var repeat_block_result: Dictionary = _parse_block(
				lines,
				line_index + 1,
				true,
				locale,
				block_depth + 1
			)
			if repeat_block_result.has("error"):
				return repeat_block_result
			if not bool(repeat_block_result.get("closed", false)):
				return _error(
					"Der Wiederholungsblock hat kein '%s'." % Strings.KEYWORD_END,
					source_line
				)

			var repeat_body: Array[ParsedNode] = repeat_block_result.nodes
			var repeat_body_count: int = _count_commands(repeat_body)
			if _count_commands(result) + repeat_body_count * repeat_count > MAX_EXPANDED_COMMANDS:
				return _error(
					"Das Programm überschreitet das Limit von %d Befehlen." % MAX_EXPANDED_COMMANDS,
					source_line
				)
			for repeat_index: int in range(repeat_count):
				result.append_array(repeat_body)
			line_index = int(repeat_block_result.index)
		elif first_word == Strings.KEYWORD_IF:
			var condition_result: Dictionary = _parse_condition(line_data, locale)
			if condition_result.has("error"):
				return condition_result

			var conditional_body_result: Dictionary = _parse_block(
				lines,
				line_index + 1,
				true,
				locale,
				block_depth + 1
			)
			if conditional_body_result.has("error"):
				return conditional_body_result
			if not bool(conditional_body_result.get("closed", false)):
				return _error(
					"Der Wenn-Block hat kein '%s'." % Strings.KEYWORD_END,
					source_line
				)

			var conditional_block: ConditionalBlock = ConditionalBlock.new(
				condition_result.condition,
				conditional_body_result.nodes,
				source_line,
				line
			)
			result.append(conditional_block)
			line_index = int(conditional_body_result.index)
		else:
			var parsed_command: Dictionary = _parse_command(line_data, locale)
			if parsed_command.has("error"):
				return parsed_command
			result.append(parsed_command.command)

		if _count_commands(result) > MAX_EXPANDED_COMMANDS:
			return _error(
				"Das Programm überschreitet das Limit von %d Befehlen." % MAX_EXPANDED_COMMANDS,
				source_line
			)
		line_index += 1

	return {"nodes": result, "index": line_index, "closed": false}


func _parse_condition(line_data: Dictionary, locale: String) -> Dictionary:
	var source_text: String = String(line_data.text).strip_edges()
	var source_line: int = int(line_data.line_number)
	var parts: PackedStringArray = source_text.split(" ", false)
	if parts.size() != 3:
		return _error("Ungültige Wenn-Bedingung: %s" % source_text, source_line)

	var subject: StringName = Strings.translate_condition_name(locale, parts[1])
	if subject == &"":
		return _error("Unbekannte Bedingung: %s" % parts[1], source_line)

	var localized_actions: Dictionary = Strings.ACTION_NAMES.get(locale, {})
	var direction_name: String = parts[2].to_lower()
	if not localized_actions.has(direction_name):
		return _error("Unbekannte Richtung: %s" % parts[2], source_line)
	var direction_action: StringName = StringName(localized_actions[direction_name])
	if not Strings.direction_map.has(String(direction_action)):
		return _error("Unbekannte Richtung: %s" % parts[2], source_line)

	return {"condition": CodeCondition.new(subject, direction_action)}


func _count_commands(nodes: Array[ParsedNode]) -> int:
	var command_count: int = 0
	for node: ParsedNode in nodes:
		if node is ParsedCommand:
			command_count += 1
		elif node is ConditionalBlock:
			var conditional_block: ConditionalBlock = node as ConditionalBlock
			command_count += _count_commands(conditional_block.body)
	return command_count


func _is_valid_repeat_syntax(parts: PackedStringArray, template: PackedStringArray) -> bool:
	if parts.size() != template.size() or parts.size() < 2 or not parts[1].is_valid_int():
		return false
	for token_index in range(parts.size()):
		if token_index == 1:
			continue
		if parts[token_index] != template[token_index]:
			return false
	return true


func _parse_command(line_data: Dictionary, locale: String) -> Dictionary:
	var source_text: String = String(line_data.text).strip_edges()
	var source_line: int = int(line_data.line_number)
	var normalized_line: String = Strings.remap_code_cmd_to_action(locale, source_text)
	if normalized_line.is_empty():
		return _error("Unbekannter Befehl: %s" % source_text, source_line)

	var parts: PackedStringArray = normalized_line.split(" ", false)
	var action: StringName = StringName(parts[0])
	var arguments: PackedStringArray = parts.slice(1)
	var validation_error: String = _validate_and_normalize_arguments(action, arguments, locale)
	if not validation_error.is_empty():
		return _error(validation_error, source_line)

	return {
		"command": ParsedCommand.new(action, arguments, source_line, source_text),
	}


func _validate_and_normalize_arguments(
		action: StringName,
		arguments: PackedStringArray,
		locale: String
	) -> String:
	if action in [
		Strings.ACTION_WALK_LEFT,
		Strings.ACTION_WALK_RIGHT,
		Strings.ACTION_WALK_UP,
		Strings.ACTION_WALK_DOWN,
	]:
		if arguments.size() > 1:
			return "Ein Bewegungsbefehl akzeptiert höchstens eine Schrittanzahl."
		if arguments.size() == 1:
			if not arguments[0].is_valid_int():
				return "Die Schrittanzahl muss eine ganze Zahl sein."
			if arguments[0].to_int() < 0:
				return "Die Schrittanzahl darf nicht negativ sein."
		return ""

	if action == Strings.ACTION_ATTACK or action == Strings.ACTION_DRINK:
		return "" if arguments.is_empty() else "Dieser Aktionsbefehl akzeptiert keine Argumente."

	if action == Strings.ACTION_COMBO:
		return _validate_combo_arguments(arguments, locale)

	if action == Strings.ACTION_BUILD or action == Strings.ACTION_PAINT:
		if arguments.size() != 2:
			return "Der Bau-Befehl benötigt einen Typ und eine Richtung."
		var localized_actions: Dictionary = Strings.ACTION_NAMES.get(locale, {})
		var direction_name: String = arguments[1]
		if not localized_actions.has(direction_name):
			return "Unbekannte Richtung: %s" % direction_name
		var direction_action: String = localized_actions[direction_name]
		if not Strings.direction_map.has(direction_action):
			return "Unbekannte Richtung: %s" % direction_name
		arguments[1] = direction_action
		return ""

	if action == Strings.ACTION_USE_ITEM:
		if arguments.size() != 1 or not arguments[0].is_valid_int():
			return "Der Item-Befehl benötigt genau einen ganzzahligen Index."
		if arguments[0].to_int() < 1:
			return "Der Item-Index muss bei 1 beginnen."
		return ""

	if action == Strings.ACTION_SAY:
		return ""

	return "Unbekannte Aktion: %s" % action


func _validate_combo_arguments(arguments: PackedStringArray, locale: String) -> String:
	if arguments.is_empty() or arguments.size() % 2 != 0:
		return "Eine Combo benötigt Paare aus Richtung und 'attacke'."
	var localized_actions: Dictionary = Strings.ACTION_NAMES.get(locale, {})
	for argument_index: int in range(0, arguments.size(), 2):
		var direction_name: String = arguments[argument_index].to_lower()
		if not localized_actions.has(direction_name):
			return "Unbekannte Combo-Richtung: %s" % arguments[argument_index]
		var direction_action: String = localized_actions[direction_name]
		if not Strings.direction_map.has(direction_action):
			return "Unbekannte Combo-Richtung: %s" % arguments[argument_index]

		var attack_name: String = arguments[argument_index + 1].to_lower()
		if not localized_actions.has(attack_name) \
				or localized_actions[attack_name] != Strings.ACTION_ATTACK:
			return "Jede Combo-Richtung muss von 'attacke' gefolgt werden."
		arguments[argument_index] = direction_action
		arguments[argument_index + 1] = Strings.ACTION_ATTACK
	return ""


func _error(message: String, line_number: int) -> Dictionary:
	return {"error": "%s (Zeile %d)" % [message, line_number]}
