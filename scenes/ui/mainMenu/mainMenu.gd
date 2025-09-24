extends Control
@onready var levelList = $LevelContainer/VBoxContainer/LevelList

func _ready():
	if OS.has_feature("dedicated_server"):
		Multihelper.create_game()

func server_offline():
	$connectTimer.start()

func _on_hostDebugButton_pressed():
	var selc_items = levelList.get_selected_items()
	var selcted_level : int = 0
	if not selc_items.is_empty():
		selcted_level = selc_items[0]
	print("selec levvel"+str(selcted_level))
	Multihelper.setLevel(selcted_level)
	Multihelper.create_game()

func _on_connect_timer_timeout():
	Multihelper.join_game()
