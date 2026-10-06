extends Space
class_name DictSpace

var spaces: Dictionary = {}


func _init(value_spaces: Dictionary = {}) -> void:
	super()
	spaces = value_spaces.duplicate()


func sample() -> Variant:
	var result := {}
	for key in _sorted_keys():
		var child_space := spaces[key] as Space
		if child_space == null:
			push_error("DictSpace contains an invalid child space for key: %s" % key)
			return {}
		result[key] = child_space.sample()
	return result


func contains(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.size() != spaces.size():
		return false
	for key in spaces:
		if not value.has(key):
			return false
		var child_space := spaces[key] as Space
		if child_space == null or not child_space.contains(value[key]):
			return false
	return true


func seed(seed_value: int) -> void:
	super(seed_value)
	var child_seed := seed_value
	for key in _sorted_keys():
		var child_space := spaces[key] as Space
		if child_space != null:
			child_space.seed(child_seed)
		child_seed += 1


func _sorted_keys() -> Array:
	var keys := spaces.keys()
	keys.sort()
	return keys
