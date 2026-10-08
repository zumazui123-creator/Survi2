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


class CodeExpression:
	extends RefCounted

	enum Kind {
		LITERAL,
		VARIABLE,
		BINARY,
		DISTANCE_QUERY,
		PLAYER_STAT,
	}

	var kind: int
	var literal_value: Variant
	var variable_name: String = ""
	var binary_operator: StringName = &""
	var left: CodeExpression
	var right: CodeExpression
	var subject: StringName = &""
	var stat_name: StringName = &""

	func _init(parsed_kind: int) -> void:
		kind = parsed_kind


class Assignment:
	extends ParsedNode

	var variable_name: String
	var expression: CodeExpression

	func _init(
			parsed_variable_name: String,
			parsed_expression: CodeExpression,
			parsed_source_line: int,
			parsed_source_text: String
		) -> void:
		variable_name = parsed_variable_name
		expression = parsed_expression
		source_line = parsed_source_line
		source_text = parsed_source_text


class CodeCondition:
	extends RefCounted

	enum Mode {
		DIRECTION,
		DISTANCE,
		EXPRESSION,
	}

	var subject: StringName
	var mode: int
	var direction_action: StringName
	var comparison_operator: StringName
	var distance_tiles: int
	var left_expression: CodeExpression
	var right_expression: CodeExpression

	func _init(
			parsed_subject: StringName,
			parsed_mode: int,
			parsed_direction_action: StringName = &"",
			parsed_comparison_operator: StringName = &"",
			parsed_distance_tiles: int = -1,
			parsed_left_expression: CodeExpression = null,
			parsed_right_expression: CodeExpression = null
		) -> void:
		subject = parsed_subject
		mode = parsed_mode
		direction_action = parsed_direction_action
		comparison_operator = parsed_comparison_operator
		distance_tiles = parsed_distance_tiles
		left_expression = parsed_left_expression
		right_expression = parsed_right_expression


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


class RepeatBlock:
	extends ParsedNode

	var count_expression: CodeExpression
	var body: Array[ParsedNode] = []

	func _init(
			parsed_count_expression: CodeExpression,
			parsed_body: Array[ParsedNode],
			parsed_source_line: int,
			parsed_source_text: String
		) -> void:
		count_expression = parsed_count_expression
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
		if node is ParsedCommand or node is Assignment:
			return 1
		if node is ConditionalBlock:
			var conditional_block: ConditionalBlock = node as ConditionalBlock
			var command_count: int = 0
			for child: ParsedNode in conditional_block.body:
				command_count += _count_commands_in_node(child)
			return 1 + command_count
		if node is RepeatBlock:
			var repeat_block: RepeatBlock = node as RepeatBlock
			var body_count: int = 0
			for child: ParsedNode in repeat_block.body:
				body_count += _count_commands_in_node(child)
			var repeat_count: int = 1
			if repeat_block.count_expression.kind == CodeExpression.Kind.LITERAL \
					and repeat_block.count_expression.literal_value is int:
				repeat_count = maxi(int(repeat_block.count_expression.literal_value), 0)
			return 1 + body_count * repeat_count
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
			var count_expression_result: Dictionary = _parse_expression(
				repeat_parts[1],
				locale,
				source_line
			)
			if count_expression_result.has("error"):
				return count_expression_result
			var count_expression: CodeExpression = count_expression_result.expression
			if count_expression.kind == CodeExpression.Kind.LITERAL:
				if not count_expression.literal_value is int:
					return _error("Die Wiederholungsanzahl muss eine ganze Zahl sein.", source_line)
				if int(count_expression.literal_value) < 0:
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
			result.append(RepeatBlock.new(count_expression, repeat_body, source_line, line))
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
		elif line.contains("="):
			var assignment_result: Dictionary = _parse_assignment(line_data, locale)
			if assignment_result.has("error"):
				return assignment_result
			result.append(assignment_result.assignment)
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
	if parts.size() == 4:
		return _parse_expression_condition(parts, locale, source_line)
	if parts.size() != 3 and parts.size() != 5:
		return _error("Ungültige Wenn-Bedingung: %s" % source_text, source_line)

	var subject: StringName = Strings.translate_condition_name(locale, parts[1])
	if subject == &"":
		return _error("Unbekannte Bedingung: %s" % parts[1], source_line)
	if parts.size() == 5:
		return _parse_distance_condition(parts, subject, locale, source_line)

	var localized_actions: Dictionary = Strings.ACTION_NAMES.get(locale, {})
	var direction_name: String = parts[2].to_lower()
	if not localized_actions.has(direction_name):
		return _error("Unbekannte Richtung: %s" % parts[2], source_line)
	var direction_action: StringName = StringName(localized_actions[direction_name])
	if not Strings.direction_map.has(String(direction_action)):
		return _error("Unbekannte Richtung: %s" % parts[2], source_line)

	return {
		"condition": CodeCondition.new(
			subject,
			CodeCondition.Mode.DIRECTION,
			direction_action
		),
	}


func _parse_expression_condition(
		parts: PackedStringArray,
		locale: String,
		source_line: int
	) -> Dictionary:
	var left_result: Dictionary = _parse_expression(parts[1], locale, source_line)
	if left_result.has("error"):
		return left_result
	var comparison_operator: StringName = Strings.translate_condition_comparison(locale, parts[2])
	if comparison_operator == &"":
		return _error(
			"Unbekannter Vergleich '%s'. Erlaubt sind kleiner, größer und gleich." % parts[2],
			source_line
		)
	var right_result: Dictionary = _parse_expression(parts[3], locale, source_line)
	if right_result.has("error"):
		return right_result
	return {
		"condition": CodeCondition.new(
			&"",
			CodeCondition.Mode.EXPRESSION,
			&"",
			comparison_operator,
			-1,
			left_result.expression,
			right_result.expression
		),
	}


func _parse_distance_condition(
		parts: PackedStringArray,
		subject: StringName,
		locale: String,
		source_line: int
	) -> Dictionary:
	if not Strings.is_condition_distance_keyword(locale, parts[2]):
		return _error("Erwartet wurde 'abstand', nicht '%s'." % parts[2], source_line)

	var comparison_operator: StringName = Strings.translate_condition_comparison(locale, parts[3])
	if comparison_operator == &"":
		return _error(
			"Unbekannter Vergleich '%s'. Erlaubt sind kleiner, größer und gleich." % parts[3],
			source_line
		)
	if not parts[4].is_valid_int():
		return _error("Der Abstand muss eine ganze Zahl sein.", source_line)

	var distance_tiles: int = parts[4].to_int()
	if distance_tiles < 0:
		return _error("Der Abstand darf nicht negativ sein.", source_line)

	return {
		"condition": CodeCondition.new(
			subject,
			CodeCondition.Mode.DISTANCE,
			&"",
			comparison_operator,
			distance_tiles
		),
	}


func _count_commands(nodes: Array[ParsedNode]) -> int:
	var command_count: int = 0
	for node: ParsedNode in nodes:
		if node is ParsedCommand or node is Assignment:
			command_count += 1
		elif node is ConditionalBlock:
			var conditional_block: ConditionalBlock = node as ConditionalBlock
			command_count += 1 + _count_commands(conditional_block.body)
		elif node is RepeatBlock:
			var repeat_block: RepeatBlock = node as RepeatBlock
			var repeat_count: int = 1
			if repeat_block.count_expression.kind == CodeExpression.Kind.LITERAL \
					and repeat_block.count_expression.literal_value is int:
				repeat_count = maxi(int(repeat_block.count_expression.literal_value), 0)
			command_count += 1 + _count_commands(repeat_block.body) * repeat_count
	return command_count


func _is_valid_repeat_syntax(parts: PackedStringArray, template: PackedStringArray) -> bool:
	if parts.size() != template.size() or parts.size() < 3:
		return false
	for token_index in range(parts.size()):
		if token_index == 1:
			continue
		if parts[token_index] != template[token_index]:
			return false
	return true


func _parse_assignment(line_data: Dictionary, locale: String) -> Dictionary:
	var source_text: String = String(line_data.text).strip_edges()
	var source_line: int = int(line_data.line_number)
	if source_text.count("=") != 1:
		return _error("Eine Zuweisung benötigt genau ein '='.", source_line)

	var equals_index: int = source_text.find("=")
	var variable_name: String = source_text.substr(0, equals_index).strip_edges().to_lower()
	var expression_text: String = source_text.substr(equals_index + 1).strip_edges()
	if not _is_valid_variable_name(variable_name):
		return _error(
			"'%s' ist kein gültiger Variablenname. Beispiel: wasser_abstand" % variable_name,
			source_line
		)
	if _is_reserved_variable_name(variable_name, locale):
		return _error("'%s' ist ein reserviertes Wort." % variable_name, source_line)
	if expression_text.is_empty():
		return _error("Rechts vom '=' fehlt ein Wert.", source_line)

	var expression_result: Dictionary = _parse_expression(expression_text, locale, source_line)
	if expression_result.has("error"):
		return expression_result
	return {
		"assignment": Assignment.new(
			variable_name,
			expression_result.expression,
			source_line,
			source_text
		),
	}


func _parse_expression(expression_text: String, locale: String, source_line: int) -> Dictionary:
	var text: String = expression_text.strip_edges()
	if text.is_empty():
		return _error("Der Ausdruck ist leer.", source_line)

	if text.begins_with("\"") or text.ends_with("\""):
		if text.length() < 2 or not text.begins_with("\"") or not text.ends_with("\""):
			return _error("Ein Text muss vollständig in Anführungszeichen stehen.", source_line)
		var string_expression: CodeExpression = CodeExpression.new(CodeExpression.Kind.LITERAL)
		string_expression.literal_value = text.substr(1, text.length() - 2)
		return {"expression": string_expression}

	if text.is_valid_int():
		var integer_expression: CodeExpression = CodeExpression.new(CodeExpression.Kind.LITERAL)
		integer_expression.literal_value = text.to_int()
		return {"expression": integer_expression}
	if text.is_valid_float():
		var float_expression: CodeExpression = CodeExpression.new(CodeExpression.Kind.LITERAL)
		float_expression.literal_value = text.to_float()
		return {"expression": float_expression}

	var parts: PackedStringArray = text.split(" ", false)
	if parts.size() == 3 and parts[1] in ["+", "-"]:
		var left_result: Dictionary = _parse_expression(parts[0], locale, source_line)
		if left_result.has("error"):
			return left_result
		var right_result: Dictionary = _parse_expression(parts[2], locale, source_line)
		if right_result.has("error"):
			return right_result
		var binary_expression: CodeExpression = CodeExpression.new(CodeExpression.Kind.BINARY)
		binary_expression.binary_operator = &"add" if parts[1] == "+" else &"subtract"
		binary_expression.left = left_result.expression
		binary_expression.right = right_result.expression
		return {"expression": binary_expression}

	if parts.size() == 3 and parts[0].to_lower() == "abstand" \
			and parts[1].to_lower() == "zu":
		var subject: StringName = Strings.translate_condition_name(locale, parts[2])
		if subject == &"" or subject == Strings.CONDITION_FREE:
			return _error("Unbekanntes Abstandsziel: %s" % parts[2], source_line)
		var distance_expression: CodeExpression = CodeExpression.new(
			CodeExpression.Kind.DISTANCE_QUERY
		)
		distance_expression.subject = subject
		return {"expression": distance_expression}

	if parts.size() == 2 and parts[0].to_lower() == "spieler":
		var stat_name: StringName = Strings.translate_player_stat_name(locale, parts[1])
		if stat_name == &"":
			return _error("Unbekannter Spielerwert: %s" % parts[1], source_line)
		var stat_expression: CodeExpression = CodeExpression.new(CodeExpression.Kind.PLAYER_STAT)
		stat_expression.stat_name = stat_name
		return {"expression": stat_expression}

	if parts.size() == 1 and _is_valid_variable_name(text):
		var variable_expression: CodeExpression = CodeExpression.new(CodeExpression.Kind.VARIABLE)
		variable_expression.variable_name = text.to_lower()
		return {"expression": variable_expression}

	return _error("Ungültiger Ausdruck: %s" % text, source_line)


func _is_valid_variable_name(variable_name: String) -> bool:
	if variable_name.is_empty():
		return false
	var first_character: String = variable_name.substr(0, 1)
	if not "abcdefghijklmnopqrstuvwxyz_".contains(first_character.to_lower()):
		return false
	for character_index: int in range(1, variable_name.length()):
		var character: String = variable_name.substr(character_index, 1).to_lower()
		if not "abcdefghijklmnopqrstuvwxyz_0123456789".contains(character):
			return false
	return true


func _is_reserved_variable_name(variable_name: String, locale: String) -> bool:
	if variable_name in [
		Strings.KEYWORD_IF,
		Strings.KEYWORD_END,
		Strings.KEYWORD_FUNC,
		"wiederhole",
		"mal",
		"abstand",
		"spieler",
	]:
		return true
	if Strings.ACTION_NAMES.get(locale, {}).has(variable_name):
		return true
	return Strings.translate_condition_name(locale, variable_name) != &""


func _parse_command(line_data: Dictionary, locale: String) -> Dictionary:
	var source_text: String = String(line_data.text).strip_edges()
	var source_line: int = int(line_data.line_number)
	var normalized_line: String = Strings.remap_code_cmd_to_action(locale, source_text)
	if normalized_line.is_empty():
		var suggestion: String = _find_command_suggestion(source_text, locale)
		var message: String = "Unbekannter Befehl: %s" % source_text
		if not suggestion.is_empty():
			message += ". Meintest du '%s'?" % suggestion
		return _error(message, source_line)

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
			if not arguments[0].is_valid_int() and not _is_valid_variable_name(arguments[0]):
				return "Die Schrittanzahl muss eine ganze Zahl oder Variable sein."
			if arguments[0].is_valid_int() and arguments[0].to_int() < 0:
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


func _find_command_suggestion(source_text: String, locale: String) -> String:
	var first_word: String = source_text.get_slice(" ", 0).to_lower()
	var best_match: String = ""
	var best_similarity: float = 0.0
	for entry: Dictionary in CodeCommandCatalog.get_entries(locale):
		var trigger: String = String(entry.get("trigger", ""))
		if trigger.contains(" ") or trigger.is_empty():
			continue
		var similarity: float = first_word.similarity(trigger)
		if similarity > best_similarity:
			best_similarity = similarity
			best_match = trigger
	return best_match if best_similarity >= 0.5 else ""


func _error(message: String, line_number: int) -> Dictionary:
	return {"error": "%s (Zeile %d)" % [message, line_number]}
