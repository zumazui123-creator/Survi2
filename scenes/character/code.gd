extends Node2D


@onready var code_edit = %CodeEdit
@onready var item_list = %ItemList
@onready var player =  "res://scenes/character/player.gd"
@onready var net_control = %NetControl
@onready var inputFuncName = %InputFuncName
@onready var code_func = $"../PopupPanel/HBoxContainer/VBoxContainer/CodeEdit"

func _on_links_button_pressed() -> void:
	code_edit.insert_text_at_caret("links\n")

func _on_oben_button_pressed() -> void:
	code_edit.insert_text_at_caret("oben\n")

func _on_rechts_button_pressed() -> void:
	code_edit.insert_text_at_caret("rechts\n")
	
func _on_unten_button_pressed() -> void:
	code_edit.insert_text_at_caret("unten\n")

func _on_attacke_button_pressed() -> void:
	code_edit.insert_text_at_caret("attacke\n")

func _on_sage_button_pressed() -> void:
	code_edit.insert_text_at_caret("sage\n")
	
func _on_item_list_item_clicked(index: int, at_position: Vector2, mouse_button_index: int) -> void:
	var item_text = item_list.get_item_text(index)
	if item_text == "wiederhole 3 mal":
		item_text = "wiederhole 3 mal\n\nende"
	
	code_edit.insert_text_at_caret(item_text+"\n")
	

@onready var popup = %PopupPanel
func _on_create_function_pressed() -> void:
	popup.popup_centered()

func _on_code_delete_button_pressed() -> void:
	code_edit.text = ""

func _on_play_button_pressed() -> void:
	net_control.send_text("play_it_now\n"+code_edit.text )

func _on_stop_button_pressed() -> void:
	net_control.send_text("End Sequenz\n")
	net_control.send_text("Stop Sequenz\n")


func checkInputFuncName():
	print("checkInputFuncName")

func _on_create_btn_pressed() -> void:
	var prefixCreateFunc = "create_function\n"
	var funcName = "func " + inputFuncName.text + "\n"
	var codeStr = code_func.text + "\n"
	net_control.send_text( prefixCreateFunc + funcName + codeStr + "\nende" )
