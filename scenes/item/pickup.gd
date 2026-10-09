extends Area2D
class_name WorldPickup

@export var itemId: String:
	set(value):
		$Sprite2D.texture = Items.get_item_icon(value)
		itemId = value

@export var stackCount: int = 1

var _reserved_for_structure: bool = false


func is_available_for_structure() -> bool:
	return not _reserved_for_structure \
		and not is_queued_for_deletion() \
		and stackCount > 0 \
		and not itemId.is_empty()


func consume_for_structure(amount: int) -> int:
	if amount <= 0 or not is_available_for_structure():
		return 0
	var consumed: int = mini(amount, stackCount)
	stackCount -= consumed
	if stackCount <= 0:
		_reserved_for_structure = true
		queue_free()
	return consumed

@rpc("any_peer", "call_remote", "reliable")
func _on_body_entered(body: Node) -> void:
	if multiplayer.is_server() \
			and is_available_for_structure() \
			and body.is_in_group(Strings.GROUP_PLAYER):
		Inventory.addItem(body.name, itemId, stackCount)
		_reserved_for_structure = true
		queue_free()
