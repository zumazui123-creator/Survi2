extends Node

@onready var item_list = %ItemList
@onready var func_list = %FuncList
@onready var code_edit = $"../CodeLayer/PopupPanel/HBoxContainer/VBoxContainer/CodeEdit"
@onready var input_func_name = %InputFuncName

var functions: Dictionary = {}

func replace_function(new_func_name, new_func_body):
	var splitted_lines = new_func_body.split("\n", false)
	functions[new_func_name] = splitted_lines
	
func add_functions(new_functions: Dictionary):
	print(new_functions)
	for new_function_name in new_functions.keys():
		if new_function_name in functions.keys():
			replace_function(new_function_name,new_functions[new_function_name])
		else:
			var funtion_body = new_functions[new_function_name].split("\n", false)
			functions.get_or_add(new_function_name, funtion_body)

func reload_functions_names():
	print("loading func: ")
	item_list.clear()
	func_list.clear()
	
	item_list.add_item(Strings.KEYWORD_REPEAT)
	item_list.add_item(Strings.KEYWORD_USE_ITEM)
	
	for func_name in functions.keys():
		item_list.add_item(func_name)
		func_list.add_item(func_name)
	

## Receives a JSON string from the backend, parses it, and stores the functions.
func set_func(packets: Dictionary) -> bool:
	print("Received functions: " + str(packets))
	if packets.is_empty():
		printerr("Received empty function packet.")
		return false

	if packets == null:
		printerr("Failed to parse JSON from function packet.")
		return false

	if typeof(packets) == TYPE_DICTIONARY:
		print("Successfully parsed and stored functions.")
		print(str(packets))
		add_functions(packets)
		reload_functions_names()
		
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
		for line in functions[input_func_name.text]:
			code_edit.text += line + "\n"
		
	else:
		printerr("Function '" + input_func_name.text + "' not found.")
