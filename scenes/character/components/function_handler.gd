extends Node
class_name FunctionHandler

## UI-independent storage for user-defined CodePlayer functions.
signal functions_changed
signal profile_loaded(profile_id: String, function_count: int)

const MINIMUM_FUNCTION_NAME_LENGTH: int = FunctionNamePolicy.MINIMUM_NAME_LENGTH

var functions: Dictionary = {}
var active_profile_id: String = ""
var _profile_store: FunctionProfileStore = FunctionProfileStore.new()


func bind_player_profile(profile_id: String) -> void:
	active_profile_id = FunctionProfileStore.normalize_profile_id(profile_id)
	var stored_functions: Dictionary = _profile_store.load_functions(active_profile_id)
	functions.clear()
	var requires_migration: bool = false
	var has_invalid_stored_functions: bool = false

	for function_name_value: Variant in stored_functions.keys():
		var original_name: String = String(function_name_value)
		var normalized_name: String = normalize_function_name(original_name)
		if not is_valid_function_name(normalized_name):
			push_warning(
				"FunctionHandler: ignored invalid stored function '%s'"
				% original_name
			)
			has_invalid_stored_functions = true
			continue
		functions[normalized_name] = _function_body_to_lines(
			stored_functions[function_name_value]
		)
		if normalized_name != original_name:
			requires_migration = true

	if requires_migration and not has_invalid_stored_functions:
		_persist_functions()
	functions_changed.emit()
	profile_loaded.emit(active_profile_id, functions.size())


func replace_function(function_name: String, function_body: String) -> bool:
	var normalized_name: String = normalize_function_name(function_name)
	if not is_valid_function_name(normalized_name):
		return false
	functions[normalized_name] = function_body.split("\n", false)
	functions_changed.emit()
	return _persist_functions()


func add_functions(new_functions: Dictionary) -> bool:
	var added_function: bool = false
	for function_name_value: Variant in new_functions.keys():
		var original_name: String = String(function_name_value)
		var function_name: String = normalize_function_name(original_name)
		var validation_error: String = get_function_name_validation_error(original_name)
		if not validation_error.is_empty():
			push_warning(
				"FunctionHandler: invalid function name '%s': %s"
				% [original_name, validation_error]
			)
			continue
		functions[function_name] = _function_body_to_lines(
			new_functions[function_name_value]
		)
		added_function = true
	if added_function:
		functions_changed.emit()
		return _persist_functions()
	return false


func set_func(packets: Dictionary) -> bool:
	if packets.is_empty():
		push_warning("FunctionHandler: received an empty function packet")
		return false
	return add_functions(packets)


static func is_valid_function_name(function_name: String) -> bool:
	return FunctionNamePolicy.is_valid_name(function_name)


static func normalize_function_name(function_name: String) -> String:
	return FunctionNamePolicy.normalize_name(function_name)


static func get_function_name_validation_error(function_name: String) -> String:
	return FunctionNamePolicy.get_validation_error(function_name)


func has_function(function_name: String) -> bool:
	return functions.has(normalize_function_name(function_name))


func get_function_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for function_name_value: Variant in functions.keys():
		names.append(String(function_name_value))
	names.sort()
	return names


func get_function_body(function_name: String) -> PackedStringArray:
	var normalized_name: String = normalize_function_name(function_name)
	if not functions.has(normalized_name):
		push_warning("FunctionHandler: function '%s' was not found" % function_name)
		return PackedStringArray()
	return PackedStringArray(functions[normalized_name])


func save_active_profile() -> bool:
	return _persist_functions()


func _persist_functions() -> bool:
	if active_profile_id.is_empty():
		return true
	var serialized_functions: Dictionary = {}
	for function_name_value: Variant in functions.keys():
		var function_name: String = String(function_name_value)
		var function_lines: PackedStringArray = _function_body_to_lines(
			functions[function_name_value]
		)
		serialized_functions[function_name] = "\n".join(function_lines)
	return _profile_store.save_functions(active_profile_id, serialized_functions)


static func _function_body_to_lines(function_body: Variant) -> PackedStringArray:
	if function_body is PackedStringArray:
		return PackedStringArray(function_body)
	if function_body is Array:
		var result: PackedStringArray = PackedStringArray()
		for line_value: Variant in function_body:
			result.append(String(line_value))
		return result
	return String(function_body).split("\n", false)


func _exit_tree() -> void:
	_persist_functions()
