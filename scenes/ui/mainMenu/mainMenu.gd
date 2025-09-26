extends Control
@onready var labyrinthLevelList = $HBoxContainer/LevelContainer/VBoxContainer/LabyrinthLevelList

var selcted_level : int = 0

func _ready():
	if OS.has_feature("dedicated_server"):
		Multihelper.create_game()

func server_offline():
	$connectTimer.start()

func _on_hostDebugButton_pressed():
	print("selec levvel"+str(selcted_level))
	Multihelper.setLevel(selcted_level)
	Multihelper.create_game()

func _on_connect_timer_timeout():
	Multihelper.join_game()


func _on_main_level_list_item_selected(index: int) -> void:
	selcted_level = index

func _on_labyrinth_level_list_item_selected(index: int) -> void:
	selcted_level = index + 100 # 100 is a indicator fpr Labyrinth levels
