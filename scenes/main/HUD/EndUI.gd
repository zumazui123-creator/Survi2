extends Control
@onready var label = $VBoxContainer2/Container/VBoxContainer/Label

var playerDied :bool
var playerId : String 

func setLabel(labelText : String):
	label.text = labelText
	
func setPlayerStatus(playerDied: bool, playerId : String):
	self.playerDied = playerDied
	self.playerId = playerId
	
func _on_next_button_pressed() -> void:
	print("_on_next_button_pressed")
	self.visible = false
	if playerDied:
		print("DIED")
		Multihelper.rebornPlayer(playerId)

	if	Multihelper.level > 99:
		Multihelper.level += 1
	Multihelper.map.generateMap(Multihelper.level)
	Multihelper.spawnPlayers()


func _on_retry_button_pressed() -> void:
	self.visible = true
	Multihelper.spawnPlayers()
	
