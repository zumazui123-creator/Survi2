extends Node2D
@onready var inputName = %InputFuncName
@onready var codeText =  %PopupPanel/VBoxContainer/CodeEdit
@onready var loadBtn = %BtnCotainer/LoadBtn
@onready var exitBtn = %BtnCotainer/ExitBtn


func checkFuncName():
	print("Checking Func Name")
	var funcNameLen = inputName.text.length() 

func _on_load_btn_pressed() -> void:
	pass # Replace with function body.
