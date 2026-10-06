extends Space
class_name BoxSpace

enum ElementType {
	BYTE,
	FLOAT,
}

var shape := PackedInt32Array()
var low := 0.0
var high := 1.0
var element_type := ElementType.FLOAT


func _init(
		value_shape: PackedInt32Array = PackedInt32Array(),
		minimum := 0.0,
		maximum := 1.0,
		value_type := ElementType.FLOAT
	) -> void:
	super()
	shape = value_shape.duplicate()
	low = minimum
	high = maximum
	element_type = value_type


func sample() -> Variant:
	var count := get_element_count()
	if count <= 0 or low > high:
		push_error("BoxSpace cannot sample an invalid shape or range")
		return null

	if element_type == ElementType.BYTE:
		var byte_values := PackedByteArray()
		byte_values.resize(count)
		var minimum_byte := clampi(int(ceil(low)), 0, 255)
		var maximum_byte := clampi(int(floor(high)), 0, 255)
		for index in range(count):
			byte_values[index] = _rng.randi_range(minimum_byte, maximum_byte)
		return byte_values

	var float_values := PackedFloat32Array()
	float_values.resize(count)
	for index in range(count):
		float_values[index] = _rng.randf_range(low, high)
	return float_values


func contains(value: Variant) -> bool:
	var count := get_element_count()
	if element_type == ElementType.BYTE:
		if not (value is PackedByteArray) or value.size() != count:
			return false
	else:
		if not (value is PackedFloat32Array) or value.size() != count:
			return false

	for element in value:
		var number := float(element)
		if number < low or number > high:
			return false
	return true


func get_element_count() -> int:
	if shape.is_empty():
		return 0
	var count := 1
	for dimension in shape:
		if dimension <= 0:
			return 0
		count *= dimension
	return count
