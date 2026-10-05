extends Node

@export var code_player : CodePlayer
@onready var code_edit = %CodeEdit
@onready var item_list = %ItemList
@onready var player =  "res://scenes/character/player.gd"
@onready var net_control = %NetControl
@onready var inputFuncName = %InputFuncName
@onready var code_func = $"../PopupFunction/HBoxContainer/VBoxContainer/CodeEdit"
@onready var funcHandler = $"../../FunctionHandler"
@onready var popup = %PopupFunction
@onready var exit_btn = $"../PopupFunction/HBoxContainer/VBoxContainer/BtnContainer/ExitBtn"

@onready var tab_container = $TabContainer
@onready var function_handler = $"../../FunctionHandler"
var highlighter : MyCodeHighLighter

func init_tab_container() -> void:
	item_list.add_item("wiederhole 3 mal")
	item_list.add_item("nutze item 3")
		
func _ready():
	if Multihelper.code_player_enabled:
		print("Debug Code Playing enabled.")
	exit_btn.pressed.connect(_on_exit_btn_pressed)
	highlighter = MyCodeHighLighter.new()
	highlighter.setup_custom_highlighter(code_edit)
	init_tab_container()

func _on_exit_btn_pressed():
	popup.hide()

func _insert_text(text : String):
	code_edit.insert_text_at_caret(text + "\n")
	
func _on_links_button_pressed(button: Button) -> void:
	_insert_text(button.text)

func _on_oben_button_pressed(button: Button) -> void:
	_insert_text(button.text)

func _on_rechts_button_pressed(button: Button) -> void:
	_insert_text(button.text)
	
func _on_unten_button_pressed(button: Button) -> void:
	_insert_text(button.text)

func _on_attacke_button_pressed(button: Button) -> void:
	_insert_text(button.text)

func _on_sage_button_pressed(button: Button) -> void:
	_insert_text(button.text)

func _on_item_list_item_activated(index: int) -> void:
	var item_text = item_list.get_item_text(index)
	if item_text == Strings.KEYWORD_REPEAT:
		item_text = Strings.KEYWORD_REPEAT_FULL
	if item_text == Strings.KEYWORD_USE_ITEM:
		item_text = Strings.KEYWORD_USE_ITEM
	code_edit.insert_text_at_caret(item_text+"\n")

func _on_create_function_pressed() -> void:
	popup.popup_centered()

func _on_load_function_pressed() -> void:
	print("todo load func")
	#net_control.send_rpc_request(Strings.RPC_METHOD_LOAD_FUNCTIONS, {})
	
func _on_code_delete_button_pressed() -> void:
	code_edit.text = ""

func _on_play_button_pressed() -> void:
	if code_player != null && Multihelper.code_player_enabled:
		Multihelper.is_stopped = false
		code_player.play(code_edit.text)
		return
	#net_control.send_rpc_request(Strings.RPC_METHOD_PLAY_SEQUENCE, {"message": code_edit.text})

func _on_stop_button_pressed() -> void:
	print("_on_stop_button_pressed")
	Multihelper.is_stopped = true
	#net_control.send_text(Strings.CMD_END_SEQUENCE + "\n")
	#net_control.send_text(Strings.CMD_STOP_SEQUENCE + "\n")

func checkInputFuncName():
	print("checkInputFuncName")

func _on_create_btn_pressed() -> void:
	if Multihelper.code_player_enabled:
		print("create func")
		var funcName = inputFuncName.text
		var data := {
			inputFuncName.text: code_func.text ,
			}
		function_handler.set_func( data )
		highlighter._apply_keywords(code_edit.syntax_highlighter, [funcName], Color.CHARTREUSE)
	#var message = (
		#Strings.RPC_METHOD_CREATE_FUNCTION
		#+ "\n"
		#+ Strings.KEYWORD_FUNC
		#+ " "
		#+ inputFuncName.text
		#+ "\n"
		#+ code_func.text
		#+ "\n"
		#+ Strings.KEYWORD_END_FUNC
	#)

	
	#net_control.send_rpc_request(Strings.RPC_METHOD_CREATE_FUNCTION, {"message": message})
