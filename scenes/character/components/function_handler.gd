extends Node
class_name FunctionHandler

## UI-independent storage for user-defined CodePlayer functions.
signal functions_changed

var functions: Dictionary = {}


func replace_function(function_name: String, function_body: String) -> void:
	functions[function_name] = function_body.split("\n", false)
	functions_changed.emit()


func add_functions(new_functions: Dictionary) -> void:
	for function_name_value: Variant in new_functions.keys():
		var function_name: String = String(function_name_value)
		var function_body: String = String(new_functions[function_name_value])
		functions[function_name] = function_body.split("\n", false)
	functions_changed.emit()


func set_func(packets: Dictionary) -> bool:
	if packets.is_empty():
		push_warning("FunctionHandler: received an empty function packet")
		return false
	add_functions(packets)
	return true


func get_function_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for function_name_value: Variant in functions.keys():
		names.append(String(function_name_value))
	names.sort()
	return names


func get_function_body(function_name: String) -> PackedStringArray:
	if not functions.has(function_name):
		push_warning("FunctionHandler: function '%s' was not found" % function_name)
		return PackedStringArray()
	return PackedStringArray(functions[function_name])
