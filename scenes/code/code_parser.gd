extends RefCounted
class_name CodeParser

const MAX_EXPANDED_COMMANDS := 1000
const MAX_FUNCTION_DEPTH := 32


class ParsedCommand:
	extends RefCounted

	var action: StringName
	var arguments: PackedStringArray
	var source_line: int
	var source_text: String

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
		var parts := PackedStringArray([String(action)])
		parts.append_array(arguments)
		return parts


class ParseResult:
	extends RefCounted

	var commands: Array[ParsedCommand] = []
	var error_message := ""

	func has_error() -> bool:
		return not error_message.is_empty()


func parse(
		source_code: String,
		functions: Dictionary = {},
		locale: String = Strings.current_locale
	) -> ParseResult:
	var result := ParseResult.new()
	if not Strings.ACTION_NAMES.has(locale):
		result.error_message = "Unbekannte Code-Sprache: %s" % locale
		return result

	var source_lines := _create_source_lines(source_code)
	var expanded_functions := _expand_functions(source_lines, functions)
	if expanded_functions.has("error"):
		result.error_message = expanded_functions.error
		return result

	var expanded_repeats := _expand_repeat_block(expanded_functions.lines, 0, false)
	if expanded_repeats.has("error"):
		result.error_message = expanded_repeats.error
		return result

	for line_data: Dictionary in expanded_repeats.lines:
		var parsed_command := _parse_command(line_data, locale)
		if parsed_command.has("error"):
			result.error_message = parsed_command.error
			return result
		result.commands.append(parsed_command.command)

	return result


func _create_source_lines(source_code: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var lines := source_code.split("\n", true)
	for line_index in range(lines.size()):
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
		var line := String(line_data.text).strip_edges()
		if line.is_empty() or line.begins_with("#") or not functions.has(line):
			result.append(line_data)
			if result.size() > MAX_EXPANDED_COMMANDS:
				return _error(
					"Das Programm überschreitet das Limit von %d Befehlen." % MAX_EXPANDED_COMMANDS,
					int(line_data.line_number)
				)
			continue

		if line in call_stack:
			var recursion_path := " -> ".join(call_stack + [line])
			return _error(
				"Rekursive Funktion erkannt: %s" % recursion_path,
				int(line_data.line_number)
			)
		if call_stack.size() >= MAX_FUNCTION_DEPTH:
			return _error(
				"Die maximale Funktionstiefe von %d wurde überschritten." % MAX_FUNCTION_DEPTH,
				int(line_data.line_number)
			)

		var function_body := _normalize_function_body(functions[line])
		if not function_body.valid:
			return _error("Ungültiger Funktionsinhalt für '%s'." % line, int(line_data.line_number))

		var function_lines: Array[Dictionary] = []
		for function_line in function_body.lines:
			function_lines.append({
				"text": String(function_line),
				"line_number": int(line_data.line_number),
			})

		var nested_stack := call_stack.duplicate()
		nested_stack.append(line)
		var expanded_body := _expand_functions(function_lines, functions, nested_stack)
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
		var lines := PackedStringArray()
		for line in body:
			lines.append(String(line))
		return {"valid": true, "lines": lines}
	return {"valid": false, "lines": PackedStringArray()}


func _expand_repeat_block(
		lines: Array[Dictionary],
		start_index: int,
		expects_end: bool
	) -> Dictionary:
	var result: Array[Dictionary] = []
	var line_index := start_index
	var repeat_template := Strings.KEYWORD_REPEAT.split(" ", false)
	var repeat_keyword := repeat_template[0]

	while line_index < lines.size():
		var line_data := lines[line_index]
		var line := String(line_data.text).strip_edges()
		var source_line := int(line_data.line_number)

		if line.is_empty() or line.begins_with("#"):
			line_index += 1
			continue

		if line == Strings.KEYWORD_END:
			if not expects_end:
				return _error("Unerwartetes '%s'." % Strings.KEYWORD_END, source_line)
			return {"lines": result, "index": line_index, "closed": true}

		if line.get_slice(" ", 0) == repeat_keyword:
			var repeat_parts := line.split(" ", false)
			if not _is_valid_repeat_syntax(repeat_parts, repeat_template):
				return _error("Ungültige Wiederholung: %s" % line, source_line)

			var repeat_count := repeat_parts[1].to_int()
			if repeat_count < 0:
				return _error("Die Anzahl der Wiederholungen darf nicht negativ sein.", source_line)

			var parsed_block := _expand_repeat_block(lines, line_index + 1, true)
			if parsed_block.has("error"):
				return parsed_block
			if not parsed_block.get("closed", false):
				return _error(
					"Der Wiederholungsblock hat kein '%s'." % Strings.KEYWORD_END,
					source_line
				)

			var block: Array = parsed_block.lines
			if block.size() * repeat_count + result.size() > MAX_EXPANDED_COMMANDS:
				return _error(
					"Das Programm überschreitet das Limit von %d Befehlen." % MAX_EXPANDED_COMMANDS,
					source_line
				)
			for _repeat_index in range(repeat_count):
				result.append_array(block)
			line_index = int(parsed_block.index)
		else:
			result.append(line_data)
			if result.size() > MAX_EXPANDED_COMMANDS:
				return _error(
					"Das Programm überschreitet das Limit von %d Befehlen." % MAX_EXPANDED_COMMANDS,
					source_line
				)

		line_index += 1

	return {"lines": result, "index": line_index, "closed": false}


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
	var source_text := String(line_data.text).strip_edges()
	var source_line := int(line_data.line_number)
	var normalized_line := Strings.remap_code_cmd_to_action(locale, source_text)
	if normalized_line.is_empty():
		return _error("Unbekannter Befehl: %s" % source_text, source_line)

	var parts := normalized_line.split(" ", false)
	var action := StringName(parts[0])
	var arguments: PackedStringArray = parts.slice(1)
	var validation_error := _validate_and_normalize_arguments(action, arguments, locale)
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

	if action == Strings.ACTION_ATTACK:
		return "" if arguments.is_empty() else "Der Angriffsbefehl akzeptiert keine Argumente."

	if action == Strings.ACTION_BUILD or action == Strings.ACTION_PAINT:
		if arguments.size() != 2:
			return "Der Bau-Befehl benötigt einen Typ und eine Richtung."
		var localized_actions: Dictionary = Strings.ACTION_NAMES.get(locale, {})
		var direction_name := arguments[1]
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
		if arguments[0].to_int() < 0:
			return "Der Item-Index darf nicht negativ sein."
		return ""

	if action == Strings.ACTION_SAY:
		return ""

	return "Unbekannte Aktion: %s" % action


func _error(message: String, line_number: int) -> Dictionary:
	return {"error": "%s (Zeile %d)" % [message, line_number]}
