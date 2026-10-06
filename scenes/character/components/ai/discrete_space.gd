extends Space
class_name DiscreteSpace

var size: int


func _init(value_count := 0) -> void:
	super()
	size = maxi(value_count, 0)


func sample() -> Variant:
	if size <= 0:
		push_error("DiscreteSpace cannot sample an empty space")
		return -1
	return _rng.randi_range(0, size - 1)


func contains(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and int(value) >= 0 and int(value) < size
