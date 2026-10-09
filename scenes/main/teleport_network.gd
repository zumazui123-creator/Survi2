extends Node
class_name TeleportNetwork

var _pads_by_owner: Dictionary[int, Array] = {}


func register_pad(pad: TeleportPadBuilding) -> void:
	if not is_instance_valid(pad):
		return
	var pads: Array = _pads_by_owner.get(pad.builder_peer_id, [])
	if pad not in pads:
		pads.append(pad)
	_pads_by_owner[pad.builder_peer_id] = pads
	_repair_pairs(pad.builder_peer_id)


func unregister_pad(pad: TeleportPadBuilding) -> void:
	if not is_instance_valid(pad):
		return
	var pads: Array = _pads_by_owner.get(pad.builder_peer_id, [])
	pads.erase(pad)
	_pads_by_owner[pad.builder_peer_id] = pads
	_repair_pairs(pad.builder_peer_id)


func clear() -> void:
	for owner_value: Variant in _pads_by_owner.keys():
		var owner_id: int = int(owner_value)
		for pad_value: Variant in _pads_by_owner[owner_id]:
			var pad: TeleportPadBuilding = pad_value as TeleportPadBuilding
			if is_instance_valid(pad):
				pad.set_partner(null)
	_pads_by_owner.clear()


func _repair_pairs(owner_id: int) -> void:
	var valid_pads: Array[TeleportPadBuilding] = []
	for pad_value: Variant in _pads_by_owner.get(owner_id, []):
		var pad: TeleportPadBuilding = pad_value as TeleportPadBuilding
		if is_instance_valid(pad) and not pad.is_queued_for_deletion():
			pad.set_partner(null)
			valid_pads.append(pad)
	_pads_by_owner[owner_id] = valid_pads
	var index: int = 0
	while index + 1 < valid_pads.size():
		valid_pads[index].set_partner(valid_pads[index + 1])
		valid_pads[index + 1].set_partner(valid_pads[index])
		index += 2
