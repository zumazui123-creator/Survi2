extends Node2D

var retry = false
var charactersFolder = "res://assets/characters/bodies/"
var selectedCharacterIndex = 0
var charactersLen = 9
#@onready var levelList = $VBoxContainer2/LevelContainer/VBoxContainer/LevelList

func _ready():
	if retry:
		%RetryWindow.visible = true
	setActiveCharacter()

func _on_button_pressed():
	if %nameInput.text == "":
		%nameInput.text = "Unknow"
	print("_on_button_pressed selceted char:"+str(selectedCharacterIndex))
	Multihelper.requestSpawn(%nameInput.text, 
		multiplayer.get_unique_id(), 
		str(selectedCharacterIndex)+".png",
	)
	queue_free()

func _on_prev_character_button_pressed():
	selectedCharacterIndex -= 1
	if selectedCharacterIndex < 0:
		selectedCharacterIndex = charactersLen - 1
	setActiveCharacter()

func _on_next_character_button_pressed():
	selectedCharacterIndex += 1
	if selectedCharacterIndex == charactersLen:
		selectedCharacterIndex = 0
	setActiveCharacter()

func setActiveCharacter():
	%selectedBody.texture = load(charactersFolder+str(selectedCharacterIndex)+".png")
