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
	var alternative: ConditionalBlock

	func _init(
			parsed_condition: CodeCondition,
			parsed_body: Array[ParsedNode],
			parsed_source_line: int,
			parsed_source_text: String,
			parsed_alternative: ConditionalBlock = null
		) -> void:
		condition = parsed_condition
		body = parsed_body
		source_line = parsed_source_line
		source_text = parsed_source_text
		alternative = parsed_alternative


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


class ConditionLoopBlock:
	extends ParsedNode

	enum Mode {
		WHILE,
		UNTIL,
	}

	var mode: int
	var condition: CodeCondition
	var body: Array[ParsedNode] = []

	func _init(
			parsed_mode: int,
			parsed_condition: CodeCondition,
			parsed_body: Array[ParsedNode],
			parsed_source_line: int,
			parsed_source_text: String
		) -> void:
		mode = parsed_mode
		condition = parsed_condition
		body = parsed_body
		source_line = parsed_source_line
		source_text = parsed_source_text


class RangeLoopBlock:
	extends ParsedNode

	var variable_name: String
	var start_expression: CodeExpression
	var end_expression: CodeExpression
	var body: Array[ParsedNode] = []

	func _init(
			parsed_variable_name: String,
			parsed_start_expression: CodeExpression,
			parsed_end_expression: CodeExpression,
			parsed_body: Array[ParsedNode],
			parsed_source_line: int,
			parsed_source_text: String
		) -> void:
		variable_name = parsed_variable_name
		start_expression = parsed_start_expression
		end_expression = parsed_end_expression
		body = parsed_body
		source_line = parsed_source_line
		source_text = parsed_source_text


class ForEachBlock:
	extends ParsedNode

	var variable_name: String
	var collection_name: StringName
	var sensor_subject: StringName
	var body: Array[ParsedNode] = []

	func _init(
			parsed_variable_name: String,
			parsed_collection_name: StringName,
			parsed_sensor_subject: StringName,
			parsed_body: Array[ParsedNode],
			parsed_source_line: int,
			parsed_source_text: String
		) -> void:
		variable_name = parsed_variable_name
		collection_name = parsed_collection_name
		sensor_subject = parsed_sensor_subject
		body = parsed_body
		source_line = parsed_source_line
		source_text = parsed_source_text


class ForeverBlock:
	extends ParsedNode

	var body: Array[ParsedNode] = []

	func _init(
			parsed_body: Array[ParsedNode],
			parsed_source_line: int,
			parsed_source_text: String
		) -> void:
		body = parsed_body
		source_line = parsed_source_line
		source_text = parsed_source_text


class LoopControl:
	extends ParsedNode

	enum Kind {
		BREAK,
		CONTINUE,
	}

	var kind: int

	func _init(
			parsed_kind: int,
			parsed_source_line: int,
			parsed_source_text: String
		) -> void:
		kind = parsed_kind
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
		if node is ParsedCommand or node is Assignment or node is LoopControl:
			return 1
		if node is ConditionalBlock:
			var conditional_block: ConditionalBlock = node as ConditionalBlock
			var command_count: int = 0
			for child: ParsedNode in conditional_block.body:
				command_count += _count_commands_in_node(child)
			if conditional_block.alternative != null:
				command_count += _count_commands_in_node(conditional_block.alternative)
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
		if node is ConditionLoopBlock:
			return 1 + _count_commands_in_body((node as ConditionLoopBlock).body)
		if node is RangeLoopBlock:
			return 1 + _count_commands_in_body((node as RangeLoopBlock).body)
		if node is ForEachBlock:
			return 1 + _count_commands_in_body((node as ForEachBlock).body)
		if node is ForeverBlock:
			return 1 + _count_commands_in_body((node as ForeverBlock).body)
		return 0

	func _count_commands_in_body(body: Array[ParsedNode]) -> int:
		var result: int = 0
		for child: ParsedNode in body:
			result += _count_commands_in_node(child)
		return result


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
		block_depth: int,
		allows_conditional_alternative: bool = false,
		loop_depth: int = 0
	) -> Dictionary:
	var result: Array[ParsedNode] = []
	var line_index: int = start_index
	var repeat_template: PackedStringArray = Strings.KEYWORD_REPEAT.split(" ", false) \
		if locale == "de" else PackedStringArray(["repeat", "3", "times"])
	var repeat_keyword: String = repeat_template[0]

	while line_index < lines.size():
		var line_data: Dictionary = lines[line_index]
		var line: String = String(line_data.text).strip_edges()
		var source_line: int = int(line_data.line_number)

		if line.is_empty() or line.begins_with("#"):
			line_index += 1
			continue

		var alternative_kind: String = _get_conditional_alternative_kind(line, locale)
		if not alternative_kind.is_empty():
			if alternative_kind == "invalid":
				return _error("Ungültiger Sonst-Zweig: %s" % line, source_line)
			if not allows_conditional_alternative:
				return _error("Unerwarteter Sonst-Zweig: %s" % line, source_line)
			return {
				"nodes": result,
				"index": line_index,
				"closed": false,
				"terminator": alternative_kind,
			}

		if line == Strings.KEYWORD_END:
			if not expects_end:
				return _error("Unerwartetes '%s'." % Strings.KEYWORD_END, source_line)
			return {
				"nodes": result,
				"index": line_index,
				"closed": true,
				"terminator": "end",
			}

		if block_depth >= MAX_BLOCK_DEPTH:
			return _error(
				"Die maximale Blocktiefe von %d wurde überschritten." % MAX_BLOCK_DEPTH,
				source_line
			)

		var first_word: String = line.get_slice(" ", 0).to_lower()
		if _is_loop_control(line, locale):
			if loop_depth <= 0:
				return _error("'%s' ist nur innerhalb einer Schleife erlaubt." % line, source_line)
			var control_kind: int = LoopControl.Kind.BREAK \
				if _is_break_keyword(line, locale) else LoopControl.Kind.CONTINUE
			result.append(LoopControl.new(control_kind, source_line, line))
		elif _is_forever_header(line, locale):
			var forever_result: Dictionary = _parse_loop_body(
				lines, line_index, locale, block_depth, loop_depth, "Immer-Schleife"
			)
			if forever_result.has("error"):
				return forever_result
			var forever_body: Array[ParsedNode] = forever_result.body
			result.append(ForeverBlock.new(forever_body, source_line, line))
			line_index = int(forever_result.index)
		elif _is_while_header(line, locale):
			var while_condition_result: Dictionary = _parse_loop_condition(
				line_data, _while_keyword(locale), locale
			)
			if while_condition_result.has("error"):
				return while_condition_result
			var while_body_result: Dictionary = _parse_loop_body(
				lines, line_index, locale, block_depth, loop_depth, "Solange-Schleife"
			)
			if while_body_result.has("error"):
				return while_body_result
			var while_body: Array[ParsedNode] = while_body_result.body
			result.append(ConditionLoopBlock.new(
				ConditionLoopBlock.Mode.WHILE,
				while_condition_result.condition,
				while_body,
				source_line,
				line
			))
			line_index = int(while_body_result.index)
		elif _is_repeat_until_header(line, locale):
			var until_prefix: String = _repeat_keyword(locale) + " " + _until_keyword(locale)
			var until_condition_result: Dictionary = _parse_loop_condition(
				line_data, until_prefix, locale
			)
			if until_condition_result.has("error"):
				return until_condition_result
			var until_body_result: Dictionary = _parse_loop_body(
				lines, line_index, locale, block_depth, loop_depth, "Wiederhole-bis-Schleife"
			)
			if until_body_result.has("error"):
				return until_body_result
			var until_body: Array[ParsedNode] = until_body_result.body
			result.append(ConditionLoopBlock.new(
				ConditionLoopBlock.Mode.UNTIL,
				until_condition_result.condition,
				until_body,
				source_line,
				line
			))
			line_index = int(until_body_result.index)
		elif _is_for_header(first_word, locale):
			var for_result: Dictionary = _parse_for_loop(
				lines, line_index, locale, block_depth, loop_depth
			)
			if for_result.has("error"):
				return for_result
			result.append(for_result.block)
			line_index = int(for_result.index)
		elif first_word == repeat_keyword:
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
				block_depth + 1,
				false,
				loop_depth + 1
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
			var conditional_result: Dictionary = _parse_conditional_chain(
				lines,
				line_index,
				locale,
				block_depth,
				false,
				loop_depth
			)
			if conditional_result.has("error"):
				return conditional_result
			result.append(conditional_result.block)
			line_index = int(conditional_result.index)
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


func _parse_loop_body(
		lines: Array[Dictionary],
		header_index: int,
		locale: String,
		block_depth: int,
		loop_depth: int,
		loop_name: String
	) -> Dictionary:
	var source_line: int = int(lines[header_index].line_number)
	var body_result: Dictionary = _parse_block(
		lines,
		header_index + 1,
		true,
		locale,
		block_depth + 1,
		false,
		loop_depth + 1
	)
	if body_result.has("error"):
		return body_result
	if not bool(body_result.get("closed", false)):
		return _error("Die %s hat kein '%s'." % [loop_name, Strings.KEYWORD_END], source_line)
	var body: Array[ParsedNode] = body_result.nodes
	if body.is_empty():
		return _error("Die %s darf nicht leer sein." % loop_name, source_line)
	return {
		"body": body,
		"index": int(body_result.index),
	}


func _parse_loop_condition(
		line_data: Dictionary,
		prefix: String,
		locale: String
	) -> Dictionary:
	var source_text: String = String(line_data.text).strip_edges()
	var condition_text: String = source_text.substr(prefix.length()).strip_edges()
	if condition_text.is_empty():
		return _error("Der Schleifenbedingung fehlt ein Vergleich.", int(line_data.line_number))
	var condition_data: Dictionary = line_data.duplicate()
	condition_data["text"] = (Strings.KEYWORD_IF if locale == "de" else "if") \
		+ " " + condition_text
	return _parse_condition(condition_data, locale)


func _parse_for_loop(
		lines: Array[Dictionary],
		header_index: int,
		locale: String,
		block_depth: int,
		loop_depth: int
	) -> Dictionary:
	var line_data: Dictionary = lines[header_index]
	var source_text: String = String(line_data.text).strip_edges()
	var source_line: int = int(line_data.line_number)
	var parts: PackedStringArray = source_text.split(" ", false)
	var each_keyword: String = Strings.KEYWORD_EACH if locale == "de" else "each"
	var in_keyword: String = Strings.KEYWORD_IN if locale == "de" else "in"
	var from_keyword: String = Strings.KEYWORD_FROM if locale == "de" else "from"
	var until_keyword: String = Strings.KEYWORD_UNTIL if locale == "de" else "to"

	if parts.size() == 5 and parts[1].to_lower() == each_keyword \
			and parts[3].to_lower() == in_keyword:
		var variable_name: String = parts[2].to_lower()
		if not _is_valid_variable_name(variable_name):
			return _error("Ungültige Schleifenvariable: %s" % parts[2], source_line)
		var collection_text: String = parts[4].to_lower()
		var collection_name: StringName = &""
		var sensor_subject: StringName = &""
		if collection_text == ("inventar" if locale == "de" else "inventory"):
			collection_name = &"inventory"
		elif collection_text == ("sensor" if locale == "de" else "sensor"):
			collection_name = &"sensor"
			sensor_subject = Strings.translate_condition_name(locale, variable_name)
			if sensor_subject == &"" or sensor_subject == Strings.CONDITION_FREE:
				return _error(
					"Für den Sensor sind objekt, item, tier, gegner, wasser oder ziel erlaubt.",
					source_line
				)
		else:
			return _error("Unbekannte Sammlung: %s" % parts[4], source_line)

		var each_body_result: Dictionary = _parse_loop_body(
			lines, header_index, locale, block_depth, loop_depth, "Für-jedes-Schleife"
		)
		if each_body_result.has("error"):
			return each_body_result
		var each_body: Array[ParsedNode] = each_body_result.body
		return {
			"block": ForEachBlock.new(
				variable_name,
				collection_name,
				sensor_subject,
				each_body,
				source_line,
				source_text
			),
			"index": int(each_body_result.index),
		}

	if parts.size() != 6 or parts[2].to_lower() != from_keyword \
			or parts[4].to_lower() != until_keyword:
		return _error(
			"Ungültige Für-Schleife. Beispiel: für schritt von 1 bis 5",
			source_line
		)
	var range_variable_name: String = parts[1].to_lower()
	if not _is_valid_variable_name(range_variable_name) \
			or _is_reserved_variable_name(range_variable_name, locale):
		return _error("Ungültige Schleifenvariable: %s" % parts[1], source_line)
	var start_result: Dictionary = _parse_expression(parts[3], locale, source_line)
	if start_result.has("error"):
		return start_result
	var end_result: Dictionary = _parse_expression(parts[5], locale, source_line)
	if end_result.has("error"):
		return end_result
	var range_body_result: Dictionary = _parse_loop_body(
		lines, header_index, locale, block_depth, loop_depth, "Für-Schleife"
	)
	if range_body_result.has("error"):
		return range_body_result
	var range_body: Array[ParsedNode] = range_body_result.body
	return {
		"block": RangeLoopBlock.new(
			range_variable_name,
			start_result.expression,
			end_result.expression,
			range_body,
			source_line,
			source_text
		),
		"index": int(range_body_result.index),
	}


func _is_loop_control(line: String, locale: String) -> bool:
	var normalized_line: String = line.to_lower()
	return normalized_line in [
		_break_keyword(locale),
		_continue_keyword(locale),
	]


func _is_break_keyword(line: String, locale: String) -> bool:
	return line.to_lower() == _break_keyword(locale)


func _is_forever_header(line: String, locale: String) -> bool:
	return line.to_lower() == (Strings.KEYWORD_FOREVER if locale == "de" else "forever")


func _is_while_header(line: String, locale: String) -> bool:
	var keyword: String = _while_keyword(locale)
	var normalized_line: String = line.to_lower()
	return normalized_line == keyword or normalized_line.begins_with(keyword + " ")


func _is_repeat_until_header(line: String, locale: String) -> bool:
	var prefix: String = _repeat_keyword(locale) + " " + _until_keyword(locale)
	var normalized_line: String = line.to_lower()
	return normalized_line == prefix or normalized_line.begins_with(prefix + " ")


func _is_for_header(first_word: String, locale: String) -> bool:
	return first_word == (Strings.KEYWORD_FOR if locale == "de" else "for")


func _while_keyword(locale: String) -> String:
	return Strings.KEYWORD_WHILE if locale == "de" else "while"


func _repeat_keyword(locale: String) -> String:
	return "wiederhole" if locale == "de" else "repeat"


func _until_keyword(locale: String) -> String:
	return Strings.KEYWORD_UNTIL if locale == "de" else "until"


func _break_keyword(locale: String) -> String:
	return Strings.KEYWORD_BREAK if locale == "de" else "break"


func _continue_keyword(locale: String) -> String:
	return Strings.KEYWORD_CONTINUE if locale == "de" else "continue"


func _parse_conditional_chain(
		lines: Array[Dictionary],
		header_index: int,
		locale: String,
		block_depth: int,
		is_alternative: bool,
		loop_depth: int
	) -> Dictionary:
	var header_data: Dictionary = lines[header_index]
	var source_text: String = String(header_data.text).strip_edges()
	var source_line: int = int(header_data.line_number)
	var condition_data: Dictionary = header_data.duplicate()
	if is_alternative:
		condition_data["text"] = _strip_conditional_alternative_prefix(source_text, locale)
	var condition_result: Dictionary = _parse_condition(condition_data, locale)
	if condition_result.has("error"):
		return condition_result

	var body_result: Dictionary = _parse_block(
		lines,
		header_index + 1,
		true,
		locale,
		block_depth + 1,
		true,
		loop_depth
	)
	if body_result.has("error"):
		return body_result
	var terminator: String = String(body_result.get("terminator", ""))
	if terminator.is_empty():
		return _error(
			"Der Wenn-Block hat kein '%s'." % Strings.KEYWORD_END,
			source_line
		)

	var alternative: ConditionalBlock = null
	var final_index: int = int(body_result.index)
	if terminator == "else_if":
		var alternative_result: Dictionary = _parse_conditional_chain(
			lines,
			final_index,
			locale,
			block_depth,
			true,
			loop_depth
		)
		if alternative_result.has("error"):
			return alternative_result
		alternative = alternative_result.block as ConditionalBlock
		final_index = int(alternative_result.index)
	elif terminator == "else":
		var else_header_data: Dictionary = lines[final_index]
		var else_source_text: String = String(else_header_data.text).strip_edges()
		var else_source_line: int = int(else_header_data.line_number)
		var else_body_result: Dictionary = _parse_block(
			lines,
			final_index + 1,
			true,
			locale,
			block_depth + 1,
			false,
			loop_depth
		)
		if else_body_result.has("error"):
			return else_body_result
		if String(else_body_result.get("terminator", "")) != "end":
			return _error(
				"Der Sonst-Block hat kein '%s'." % Strings.KEYWORD_END,
				else_source_line
			)
		var else_body: Array[ParsedNode] = else_body_result.nodes
		alternative = ConditionalBlock.new(
			null,
			else_body,
			else_source_line,
			else_source_text
		)
		final_index = int(else_body_result.index)
	elif terminator != "end":
		return _error("Unbekanntes Ende des Wenn-Blocks.", source_line)

	var body: Array[ParsedNode] = body_result.nodes
	return {
		"block": ConditionalBlock.new(
			condition_result.condition,
			body,
			source_line,
			source_text,
			alternative
		),
		"index": final_index,
	}


func _get_conditional_alternative_kind(line: String, locale: String) -> String:
	var normalized_line: String = line.strip_edges().to_lower()
	var else_keywords: PackedStringArray = PackedStringArray(["else"])
	var if_keyword: String = "if"
	if locale == "de":
		else_keywords = PackedStringArray([
			Strings.KEYWORD_ELSE,
			Strings.KEYWORD_ELSE_ALIAS,
		])
		if_keyword = Strings.KEYWORD_IF
	for else_keyword: String in else_keywords:
		if normalized_line == else_keyword:
			return "else"
		var prefix: String = else_keyword + " "
		if not normalized_line.begins_with(prefix):
			continue
		var remainder: String = normalized_line.substr(prefix.length()).strip_edges()
		if remainder == if_keyword or remainder.begins_with(if_keyword + " "):
			return "else_if"
		if locale == "de" and not remainder.is_empty():
			return "else_if"
		return "invalid"
	return ""


func _strip_conditional_alternative_prefix(line: String, locale: String) -> String:
	var else_keywords: PackedStringArray = PackedStringArray(["else"])
	if locale == "de":
		else_keywords = PackedStringArray([
			Strings.KEYWORD_ELSE,
			Strings.KEYWORD_ELSE_ALIAS,
		])
	var normalized_line: String = line.strip_edges()
	for else_keyword: String in else_keywords:
		var prefix: String = else_keyword + " "
		if normalized_line.to_lower().begins_with(prefix):
			var remainder: String = normalized_line.substr(prefix.length()).strip_edges()
			if locale == "de" and remainder.get_slice(" ", 0).to_lower() != Strings.KEYWORD_IF:
				return Strings.KEYWORD_IF + " " + remainder
			return remainder
	return normalized_line


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
		if node is ParsedCommand or node is Assignment or node is LoopControl:
			command_count += 1
		elif node is ConditionalBlock:
			var conditional_block: ConditionalBlock = node as ConditionalBlock
			command_count += 1 + _count_commands(conditional_block.body)
			if conditional_block.alternative != null:
				var alternative_nodes: Array[ParsedNode] = [conditional_block.alternative]
				command_count += _count_commands(alternative_nodes)
		elif node is RepeatBlock:
			var repeat_block: RepeatBlock = node as RepeatBlock
			var repeat_count: int = 1
			if repeat_block.count_expression.kind == CodeExpression.Kind.LITERAL \
					and repeat_block.count_expression.literal_value is int:
				repeat_count = maxi(int(repeat_block.count_expression.literal_value), 0)
			command_count += 1 + _count_commands(repeat_block.body) * repeat_count
		elif node is ConditionLoopBlock:
			command_count += 1 + _count_commands((node as ConditionLoopBlock).body)
		elif node is RangeLoopBlock:
			command_count += 1 + _count_commands((node as RangeLoopBlock).body)
		elif node is ForEachBlock:
			command_count += 1 + _count_commands((node as ForEachBlock).body)
		elif node is ForeverBlock:
			command_count += 1 + _count_commands((node as ForeverBlock).body)
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
		Strings.KEYWORD_ELSE,
		Strings.KEYWORD_ELSE_ALIAS,
		Strings.KEYWORD_WHILE,
		Strings.KEYWORD_UNTIL,
		Strings.KEYWORD_FOR,
		Strings.KEYWORD_EACH,
		Strings.KEYWORD_FROM,
		Strings.KEYWORD_IN,
		Strings.KEYWORD_FOREVER,
		Strings.KEYWORD_BREAK,
		Strings.KEYWORD_CONTINUE,
		"wiederhole", "mal", "inventar", "sensor",
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

	if action == Strings.ACTION_DROP_ITEM:
		if arguments.size() < 1 or arguments.size() > 2 or not arguments[0].is_valid_int():
			return "Der Drop-Befehl benötigt einen Item-Index und optional eine Richtung."
		if arguments[0].to_int() < 1:
			return "Der Item-Index muss bei 1 beginnen."
		if arguments.size() == 2:
			var drop_localized_actions: Dictionary = Strings.ACTION_NAMES.get(locale, {})
			var drop_direction_name: String = arguments[1].to_lower()
			if not drop_localized_actions.has(drop_direction_name):
				return "Unbekannte Drop-Richtung: %s" % arguments[1]
			var drop_direction_action: String = drop_localized_actions[drop_direction_name]
			if not Strings.direction_map.has(drop_direction_action):
				return "Unbekannte Drop-Richtung: %s" % arguments[1]
			arguments[1] = drop_direction_action
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
