extends Node

@onready var item_list = %ItemList
@onready var func_list = %FuncList
@onready var code_edit = $"../CanvasLayer/PopupPanel/HBoxContainer/VBoxContainer/CodeEdit"
@onready var input_func_name = %InputFuncName

var functions: Dictionary = {}

func add_func(function_names: Array):
	print("loading func: ")
	print(str(function_names))
	
	item_list.clear()
	func_list.clear()
	
	item_list.add_item(Strings.KEYWORD_REPEAT)
	for func_name in function_names:
		item_list.add_item(func_name)
		func_list.add_item(func_name)
	

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
		add_func(functions.keys())
		
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

func _on_func_list_item_activated(index: int) -> void:
	print("_on_func_list_item_activated")
	input_func_name.text = func_list.get_item_text(index)
	if functions.has(input_func_name.text):
		code_edit.text = ""
		for action in functions[input_func_name.text]:
			code_edit.text += action +"\n"
	else:
		printerr("Function '" + input_func_name.text + "' not found.")
