extends Node
class_name CodeEditorController

var code_player: CodePlayer
var function_library: FunctionHandler
var highlighter: MyCodeHighLighter

@onready var code_edit: CodeEdit = %CodeEdit
@onready var item_list: ItemList = %ItemList
@onready var function_name_input: LineEdit = %InputFuncName
@onready var function_code_edit: CodeEdit = %FunctionCodeEdit
@onready var function_list: ItemList = %FuncList
@onready var function_popup: PopupPanel = %PopupFunction
@onready var function_exit_button: Button = %ExitBtn
@onready var play_button: Button = $TabContainer/Code/ButtonCotainer/PlayButton
@onready var stop_button: Button = $TabContainer/Code/ButtonCotainer/StopButton


func _ready() -> void:
	function_exit_button.pressed.connect(_on_exit_button_pressed)
	highlighter = MyCodeHighLighter.new()
	highlighter.setup_custom_highlighter(code_edit)
	_refresh_function_lists()
	_set_execution_buttons(false)
	if Multihelper.code_player_enabled:
		print("Debug Code Playing enabled.")


func bind_components(value_code_player: CodePlayer, value_function_library: FunctionHandler) -> void:
	_disconnect_components()
	code_player = value_code_player
	function_library = value_function_library
	if is_instance_valid(code_player):
		code_player.execution_started.connect(_on_execution_started)
		code_player.execution_finished.connect(_on_execution_ended)
		code_player.execution_cancelled.connect(_on_execution_ended)
	if is_instance_valid(function_library):
		function_library.functions_changed.connect(_refresh_function_lists)
	_refresh_function_lists()
	_set_execution_buttons(is_instance_valid(code_player) and code_player.is_running)


func unbind_components() -> void:
	_disconnect_components()
	code_player = null
	function_library = null
	_set_execution_buttons(false)


func _disconnect_components() -> void:
	if is_instance_valid(code_player):
		if code_player.execution_started.is_connected(_on_execution_started):
			code_player.execution_started.disconnect(_on_execution_started)
		if code_player.execution_finished.is_connected(_on_execution_ended):
			code_player.execution_finished.disconnect(_on_execution_ended)
		if code_player.execution_cancelled.is_connected(_on_execution_ended):
			code_player.execution_cancelled.disconnect(_on_execution_ended)
	if is_instance_valid(function_library) \
			and function_library.functions_changed.is_connected(_refresh_function_lists):
		function_library.functions_changed.disconnect(_refresh_function_lists)


func _on_execution_started(_command_count: int) -> void:
	_set_execution_buttons(true)


func _on_execution_ended() -> void:
	_set_execution_buttons(false)


func _set_execution_buttons(running: bool) -> void:
	play_button.disabled = running or not is_instance_valid(code_player)
	stop_button.disabled = not running or not is_instance_valid(code_player)


func _refresh_function_lists() -> void:
	if not is_instance_valid(item_list) or not is_instance_valid(function_list):
		return
	item_list.clear()
	function_list.clear()
	item_list.add_item(Strings.KEYWORD_REPEAT)
	item_list.add_item(Strings.KEYWORD_IF)
	for combo_command: String in _get_combo_commands():
		item_list.add_item(combo_command)
	item_list.add_item(Strings.KEYWORD_USE_ITEM)
	if not is_instance_valid(function_library):
		return
	for function_name: String in function_library.get_function_names():
		item_list.add_item(function_name)
		function_list.add_item(function_name)


func _get_combo_commands() -> PackedStringArray:
	if not is_instance_valid(code_player) or not is_instance_valid(code_player.player):
		return PackedStringArray()
	var player_combo: PlayerComboController = code_player.player.get("combo") as PlayerComboController
	if not is_instance_valid(player_combo):
		return PackedStringArray()
	return player_combo.get_code_commands()


func _insert_text(text: String) -> void:
	code_edit.insert_text_at_caret(text + "\n")


func _on_exit_button_pressed() -> void:
	function_popup.hide()


func _on_links_button_pressed() -> void:
	_insert_text("links")


func _on_oben_button_pressed() -> void:
	_insert_text("oben")


func _on_rechts_button_pressed() -> void:
	_insert_text("rechts")


func _on_unten_button_pressed() -> void:
	_insert_text("unten")


func _on_attacke_button_pressed() -> void:
	_insert_text("attacke")


func _on_trinke_button_pressed() -> void:
	_insert_text("trinke")


func _on_sage_button_pressed() -> void:
	_insert_text("sage")


func _on_item_list_item_activated(index: int) -> void:
	var item_text: String = item_list.get_item_text(index)
	if item_text == Strings.KEYWORD_REPEAT:
		item_text = Strings.KEYWORD_REPEAT_FULL
	elif item_text == Strings.KEYWORD_IF:
		item_text = Strings.KEYWORD_IF_FULL
	code_edit.insert_text_at_caret(item_text + "\n")


func _on_create_function_pressed() -> void:
	function_popup.popup_centered()


func _on_load_function_pressed() -> void:
	print("todo load func")


func _on_code_delete_button_pressed() -> void:
	code_edit.text = ""


func _on_play_button_pressed() -> void:
	if not is_instance_valid(code_player) or not Multihelper.code_player_enabled:
		return
	var functions: Dictionary = function_library.functions if is_instance_valid(function_library) else {}
	code_player.play(code_edit.text, functions)


func _on_stop_button_pressed() -> void:
	if is_instance_valid(code_player):
		code_player.cancel()


func _on_create_btn_pressed() -> void:
	if not Multihelper.code_player_enabled or not is_instance_valid(function_library):
		return
	var function_name: String = function_name_input.text.strip_edges()
	if function_name.is_empty():
		return
	var data: Dictionary = {function_name: function_code_edit.text}
	if function_library.set_func(data):
		highlighter._apply_keywords(
			code_edit.syntax_highlighter,
			[function_name],
			Color.CHARTREUSE
		)


func _on_func_list_item_activated(index: int) -> void:
	if not is_instance_valid(function_library):
		return
	var function_name: String = function_list.get_item_text(index)
	function_name_input.text = function_name
	function_code_edit.text = "\n".join(function_library.get_function_body(function_name))


func _exit_tree() -> void:
	_disconnect_components()
