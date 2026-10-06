extends RLAgent
class_name QLearningAgent

@export_range(0.0, 1.0, 0.001) var learning_rate: float = 0.1
@export_range(0.0, 1.0, 0.001) var discount: float = 0.95
@export_range(0.0, 1.0, 0.001) var epsilon: float = 0.2
@export_range(0.0, 1.0, 0.001) var epsilon_decay: float = 0.995
@export_range(0.0, 1.0, 0.001) var min_epsilon: float = 0.01

var q_table: Dictionary = {}


func get_algorithm_name() -> String:
	return "Tabellarisches Q-Learning"


func get_parameter_definitions() -> Array[Dictionary]:
	return [
		_parameter(&"learning_rate", "Lernrate (Alpha)", 0.0, 1.0, 0.01,
			"Stärke eines einzelnen Q-Learning-Updates."),
		_parameter(&"discount", "Discount (Gamma)", 0.0, 1.0, 0.01,
			"Gewicht zukünftiger Rewards."),
		_parameter(&"epsilon", "Exploration (Epsilon)", 0.0, 1.0, 0.01,
			"Wahrscheinlichkeit für eine zufällige Aktion."),
		_parameter(&"epsilon_decay", "Epsilon-Abnahme", 0.0, 1.0, 0.001,
			"Epsilon wird nach einer beendeten Episode damit multipliziert."),
		_parameter(&"min_epsilon", "Min. Epsilon", 0.0, 1.0, 0.01,
			"Untere Grenze für die Exploration."),
	]


func get_parameter_value(key: StringName) -> Variant:
	match key:
		&"learning_rate":
			return learning_rate
		&"discount":
			return discount
		&"epsilon":
			return epsilon
		&"epsilon_decay":
			return epsilon_decay
		&"min_epsilon":
			return min_epsilon
	return null


func set_parameter_value(key: StringName, value: Variant) -> void:
	var numeric_value: float = clampf(float(value), 0.0, 1.0)
	match key:
		&"learning_rate":
			learning_rate = numeric_value
		&"discount":
			discount = numeric_value
		&"epsilon":
			epsilon = numeric_value
		&"epsilon_decay":
			epsilon_decay = numeric_value
		&"min_epsilon":
			min_epsilon = numeric_value
		_:
			return
	configuration_changed.emit(key, get_parameter_value(key))


func get_runtime_metrics() -> Array[Dictionary]:
	return [
		{
			"key": &"epsilon",
			"label": "Aktuelles Epsilon",
			"value": "%.3f" % epsilon,
		},
		{
			"key": &"q_states",
			"label": "Gelernte Zustände",
			"value": str(q_table.size()),
		},
	]


func get_model_summary() -> String:
	return "%d Q-Zustände" % q_table.size()


func reset_model() -> void:
	q_table.clear()
	model_changed.emit()


func clear_policy() -> void:
	reset_model()


func get_learned_state_count() -> int:
	return q_table.size()


func on_episode_finished(_terminated: bool, _truncated: bool) -> void:
	epsilon = maxf(min_epsilon, epsilon * epsilon_decay)
	configuration_changed.emit(&"epsilon", epsilon)


func choose_action(state: Dictionary, available_actions: DiscreteSpace) -> int:
	var key: String = encode_state(state)
	_ensure_state(key, available_actions.size)

	if randf() < epsilon:
		return int(available_actions.sample())

	var action_values: Array = q_table[key]
	return action_values.find(action_values.max())


func learn_from_transition(
		state: Dictionary,
		action: int,
		result: EnvStepResult,
		action_space: DiscreteSpace
	) -> void:
	var state_key: String = encode_state(state)
	var next_state_key: String = encode_state(result.observation)
	_ensure_state(state_key, action_space.size)
	_ensure_state(next_state_key, action_space.size)
	if action < 0 or action >= action_space.size:
		return

	var action_values: Array = q_table[state_key]
	var target: float = result.reward
	if not result.terminated:
		var next_action_values: Array = q_table[next_state_key]
		target += discount * float(next_action_values.max())
	action_values[action] = float(action_values[action]) + learning_rate * (
		target - float(action_values[action])
	)
	q_table[state_key] = action_values
	model_changed.emit()


func encode_state(state: Dictionary) -> String:
	return str(state)


func _ensure_state(key: String, action_count: int) -> void:
	if q_table.has(key):
		return
	var action_values: Array[float] = []
	action_values.resize(action_count)
	action_values.fill(0.0)
	q_table[key] = action_values


func _parameter(
		key: StringName,
		label: String,
		minimum: float,
		maximum: float,
		step: float,
		tooltip: String
	) -> Dictionary:
	return {
		"key": key,
		"label": label,
		"type": RLAgent.ParameterType.FLOAT,
		"min": minimum,
		"max": maximum,
		"step": step,
		"tooltip": tooltip,
	}
