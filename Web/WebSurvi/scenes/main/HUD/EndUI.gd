extends Control
@onready var label = $VBoxContainer2/Container/VBoxContainer/Label

var playerDied :bool
var playerId : String 

func setLabel(labelText : String):
	label.text = labelText
	
func setPlayerLiveStatus(is_playerDied: bool, set_playerId : String):
	self.playerDied = is_playerDied
	self.playerId = set_playerId


func next_level():
	if playerDied:
		print("DIED")
		Multihelper.rebornPlayer(playerId)

	if Multihelper.level["type"] == Constants.MAP_LABY and Multihelper.level["level"] < Levels.max_laby_level:
		Multihelper.level = Levels.LabyrinthLevels[Multihelper.level["level"]+1]
		
	if Multihelper.level["type"] == Constants.MAP_TOURMENT and Multihelper.level["level"] < Levels.max_tourment_level:
		Multihelper.level = Levels.TurnierLevels[Multihelper.level["level"]+1]
		
	Multihelper.map.generateMap(Multihelper.level)
	Multihelper.spawnPlayers()

func retry():
	Multihelper.spawnPlayers()
	
func _on_next_button_pressed() -> void:
	self.visible = false
	print("_on_next_button_pressed")
	next_level()


func _on_retry_button_pressed() -> void:
	retry()
	self.visible = false
	
	
