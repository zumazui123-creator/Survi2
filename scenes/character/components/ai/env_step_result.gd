extends RefCounted
class_name EnvStepResult

var observation: Dictionary
var reward: float
var terminated: bool
var truncated: bool
var info: Dictionary


func _init(
		value_observation: Dictionary = {},
		value_reward := 0.0,
		value_terminated := false,
		value_truncated := false,
		value_info: Dictionary = {}
	) -> void:
	observation = value_observation
	reward = value_reward
	terminated = value_terminated
	truncated = value_truncated
	info = value_info


func is_done() -> bool:
	return terminated or truncated
