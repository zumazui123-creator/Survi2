extends Node
class_name RLAgent

@export_range(0.0, 1.0, 0.001) var learning_rate := 0.1
@export_range(0.0, 1.0, 0.001) var discount := 0.95
@export_range(0.0, 1.0, 0.001) var epsilon := 0.2

var q_table: Dictionary = {}


func choose_action(state: Dictionary, available_actions: DiscreteSpace) -> int:
	var key := encode_state(state)
	_ensure_state(key, available_actions.size)

	if randf() < epsilon:
		return int(available_actions.sample())

	var action_values: Array = q_table[key]
	return action_values.find(action_values.max())


func learn(
		state: Dictionary,
		action: int,
		reward: float,
		next_state: Dictionary,
		terminated: bool,
		action_count: int
	) -> void:
	var state_key := encode_state(state)
	var next_state_key := encode_state(next_state)
	_ensure_state(state_key, action_count)
	_ensure_state(next_state_key, action_count)
	if action < 0 or action >= action_count:
		return

	var action_values: Array = q_table[state_key]
	var target := reward
	if not terminated:
		var next_action_values: Array = q_table[next_state_key]
		target += discount * float(next_action_values.max())
	action_values[action] = float(action_values[action]) + learning_rate * (
		target - float(action_values[action])
	)
	q_table[state_key] = action_values


func encode_state(state: Dictionary) -> String:
	# The complete fixed observation is used as the state key. This keeps the
	# environment contract correct; a larger model can replace this table later.
	return str(state)


func _ensure_state(key: String, action_count: int) -> void:
	if q_table.has(key):
		return
	var action_values: Array[float] = []
	action_values.resize(action_count)
	action_values.fill(0.0)
	q_table[key] = action_values
