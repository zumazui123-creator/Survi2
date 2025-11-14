extends Node2D

@onready var code_edit = $CodeEdit
@onready var item_list = $HBoxContainer/VBoxContainer3/ItemList
@onready var player =  "res://scenes/character/player.gd"
var SyntaxHighlighter = load("res://scenes/main/SyntaxHighLight.gd")

func _ready() -> void:
	code_edit.syntax_highlighter = SyntaxHighlighter.new()
	
	code_edit.code_completion_enabled = true
	code_edit.code_completion_prefixes = ["links","ob"]

func _process(delta: float) -> void:
	pass

func _on_button_pressed_links() -> void:
	#code_edit.get_text_with_cursor_char()
	
	code_edit.insert_text_at_caret("links\n")
	#code_edit.text += "oben\n"


func _on_button_pressed_oben() -> void:
	code_edit.insert_text_at_caret("oben\n")


func _on_item_list_item_clicked(index: int, at_position: Vector2, mouse_button_index: int) -> void:
	var item_text = item_list.get_item_text(index)
	code_edit.insert_text_at_caret(item_text+"\n")
	
