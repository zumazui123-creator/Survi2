extends Node2D


@onready var code_edit = $CodeContainer/CodeEdit
@onready var item_list = $ActionsContainer/HBoxContainer/VBoxContainer3/ItemList
@onready var player =  "res://scenes/character/player.gd"

func _ready() -> void:
	code_edit.code_completion_enabled = true
	code_edit.code_completion_prefixes = ["links","ob"]

func _process(delta: float) -> void:
	pass

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
	pass # Replace with function body.

func _on_code_delete_button_pressed() -> void:
	code_edit.text = ""
