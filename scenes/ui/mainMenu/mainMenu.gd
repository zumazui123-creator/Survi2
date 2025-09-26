extends Control
@onready var labyrinthLevelList = $HBoxContainer/LevelContainer/VBoxContainer/LabyrinthLevelList
@onready var mainLevelList = $HBoxContainer/LevelContainer2/VBoxContainer/MainLevelList


var selcted_level : Dictionary = {"level": 0,"type": 100}

func _ready():
	if OS.has_feature("dedicated_server"):
		Multihelper.create_game()
	for labyLvl in Levels.LabyrinthLevels:
		labyrinthLevelList.add_item("Level "+str(labyLvl))
		
	for mainLvl in Levels.MainLevels:
		mainLevelList.add_item("Level "+str(mainLvl))	
			
func server_offline():
	$connectTimer.start()

func _on_hostDebugButton_pressed():
	print("selec level"+str(selcted_level))
	Multihelper.setLevel(selcted_level)
	Multihelper.create_game()

func _on_connect_timer_timeout():
	Multihelper.join_game()


func _on_main_level_list_item_selected(index: int) -> void:
	selcted_level = Levels.MainLevels[index]

func _on_labyrinth_level_list_item_selected(index: int) -> void:
	#selcted_level = index + 100 # 100 is a indicator fpr Labyrinth levels
	selcted_level = Levels.LabyrinthLevels[index]
