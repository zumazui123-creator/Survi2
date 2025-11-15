extends Node


@onready var code_edit = %CodeEdit
@onready var item_list = %ItemList
@onready var player =  "res://scenes/character/player.gd"
@onready var net_control = %NetControl
@onready var inputFuncName = %InputFuncName
@onready var code_func = $"../PopupPanel/HBoxContainer/VBoxContainer/CodeEdit"
@onready var funcHandler = $"../../FunctionHandler"
@onready var popup = %PopupPanel
@onready var exit_btn = $"../PopupPanel/HBoxContainer/VBoxContainer/BtnContainer/ExitBtn"
@onready var tab_containerki = $TabContainerKI
@onready var tab_container = $TabContainerKI

var highlighter := MyCodeHighLighter.new()

func init_tab_container() -> void:
	if Multihelper.level["type"] == Constants.MAP_KI:
		tab_container.visible = false
		tab_containerki.visible = true
	else:
		tab_container.visible = true
		tab_containerki.visible = false
		
func _ready():
	exit_btn.pressed.connect(_on_exit_btn_pressed)
	highlighter.setup_custom_highlighter(code_edit)
	init_tab_container()

func _on_exit_btn_pressed():
	popup.hide()
	
func _on_links_button_pressed() -> void:
	code_edit.insert_text_at_caret(Strings.ACTION_WALK_LEFT + "\n")

func _on_oben_button_pressed() -> void:
	code_edit.insert_text_at_caret(Strings.ACTION_WALK_UP + "\n")

func _on_rechts_button_pressed() -> void:
	code_edit.insert_text_at_caret(Strings.ACTION_WALK_RIGHT + "\n")
	
func _on_unten_button_pressed() -> void:
	code_edit.insert_text_at_caret(Strings.ACTION_WALK_DOWN + "\n")

func _on_attacke_button_pressed() -> void:
	code_edit.insert_text_at_caret(Strings.ACTION_ATTACK + "\n")

func _on_sage_button_pressed() -> void:
	code_edit.insert_text_at_caret(Strings.ACTION_SAY + "\n")

func _on_item_list_item_activated(index: int) -> void:
	var item_text = item_list.get_item_text(index)
	if item_text == Strings.KEYWORD_REPEAT:
		item_text = Strings.KEYWORD_REPEAT_FULL
	
	code_edit.insert_text_at_caret(item_text+"\n")

func _on_create_function_pressed() -> void:
	popup.popup_centered()

func _on_load_function_pressed() -> void:
	net_control.send_rpc_request(Strings.RPC_METHOD_LOAD_FUNCTIONS, {})
	
func _on_code_delete_button_pressed() -> void:
	code_edit.text = ""

func _on_play_button_pressed() -> void:
	net_control.send_rpc_request(Strings.RPC_METHOD_PLAY_SEQUENCE, {"message": code_edit.text})

func _on_stop_button_pressed() -> void:
	net_control.send_text(Strings.CMD_END_SEQUENCE + "\n")
	net_control.send_text(Strings.CMD_STOP_SEQUENCE + "\n")

func checkInputFuncName():
	print("checkInputFuncName")

func _on_create_btn_pressed() -> void:
	var message = (
		Strings.RPC_METHOD_CREATE_FUNCTION
		+ "\n"
		+ Strings.KEYWORD_FUNC
		+ " "
		+ inputFuncName.text
		+ "\n"
		+ code_func.text
		+ "\n"
		+ Strings.KEYWORD_END_FUNC
	)
	net_control.send_rpc_request(Strings.RPC_METHOD_CREATE_FUNCTION, {"message": message})
