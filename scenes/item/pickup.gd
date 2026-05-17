extends Area2D

@export var itemId : String:
	set(value):
		$Sprite2D.texture = load(Constants.PATH_ITEMS+value+".png")
		itemId = value

@export var stackCount := 1

@rpc("any_peer", "call_remote", "reliable")
func _on_body_entered(body):
	if multiplayer.is_server() and body.is_in_group(Strings.GROUP_PLAYER):
		Inventory.addItem(body.name, itemId, stackCount)
		queue_free()
