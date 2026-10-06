extends RefCounted
class_name Space

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func sample() -> Variant:
	push_error("Space.sample() must be implemented by a concrete space")
	return null


func contains(_value: Variant) -> bool:
	return false


func seed(seed_value: int) -> void:
	_rng.seed = seed_value
