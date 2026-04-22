extends Control
@onready var labyrinthLevelList = $HBoxContainer/LabrinthContainer/VBoxContainer/LabyrinthLevelList
@onready var mainLevelList = $HBoxContainer/MainContainer/VBoxContainer/MainLevelList
@onready var turnierLevelList = $HBoxContainer/TurnierContainer/VBoxContainer/TunierLevelList
@onready var kiList =  $HBoxContainer/KI_PLaygroundMap/VBoxContainer/KI_PLaygroundList
@onready var hostAsPlayerBtn = $HBoxContainer2/PanelContainer/VBoxContainer/HBoxContainer2/HostWithPlayerContainer/HostAsPlayerBtn
@onready var codePlayerBtn = $HBoxContainer2/PanelContainer/VBoxContainer/HBoxContainer2/CodePlayerContainer/CodePlayerBtn

var selcted_level : Dictionary = {}

func _ready():
	selcted_level = Levels.LabyrinthLevels.get(0)
	
	Multihelper.code_player_enabled = codePlayerBtn.button_pressed
	
	for labyLvl in Levels.LabyrinthLevels:
		labyrinthLevelList.add_item("Level "+str(labyLvl))
		
	for mainLvl in Levels.MainLevels:
		mainLevelList.add_item("Level "+str(mainLvl))	
		

		
func server_offline():
	$connectTimer.start()

func _on_main_level_list_item_selected(index: int) -> void:
	selcted_level = Levels.MainLevels[index]

func _on_labyrinth_level_list_item_selected(index: int) -> void:
	#selcted_level = index + 100 # 100 is a indicator fpr Labyrinth levels
	selcted_level = Levels.LabyrinthLevels[index]

func _on_tunier_level_list_item_selected(index: int) -> void:
	selcted_level = Levels.TurnierLevels[index]


func _on_start_btn_pressed() -> void:
	print("selec level"+str(selcted_level))
	Multihelper.setLevel(selcted_level)
	Multihelper.create_game()

func _on_code_player_btn_toggled(toggled_on: bool) -> void:
	Multihelper.code_player_enabled = toggled_on
