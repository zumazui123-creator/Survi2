extends Node

## Stores custom functions sent from the Python backend.

signal functions_updated(function_names: Array[String])

# A dictionary where keys are function names (String) and values are
# the code blocks (PackedStringArray).
var functions: Dictionary = {}

## Receives a JSON string from the backend, parses it, and stores the functions.
func set_func(packets: String) -> bool:
	print("Received functions: " + packets)
	if packets.is_empty():
		printerr("Received empty function packet.")
		return false

	var result = JSON.parse_string(packets)

	if result == null:
		printerr("Failed to parse JSON from function packet.")
		return false

	if typeof(result) == TYPE_DICTIONARY:
		functions = result
		print("Successfully parsed and stored functions.")
		print(str(functions))
		functions_updated.emit(functions.keys()) # Emit the signal with the new function names
		return true
	else:
		printerr("Parsed JSON is not a dictionary.")
		return false

## Returns the code block for a given function name.
func get_function_body(func_name: String) -> PackedStringArray:
	if functions.has(func_name):
		return functions[func_name]
	else:
		printerr("Function '" + func_name + "' not found.")
		return []

## Returns a list of all available function names.
func get_function_list() -> Array[String]:
	return functions.keys()
