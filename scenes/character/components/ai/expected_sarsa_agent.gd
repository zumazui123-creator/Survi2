extends RLAgent
class_name ExpectedSarsaAgent

@export_range(0.0, 1.0, 0.001) var learning_rate: float = 0.1
@export_range(0.0, 1.0, 0.001) var discount: float = 0.95
@export_range(0.0, 1.0, 0.001) var epsilon: float = 0.2
@export_range(0.0, 1.0, 0.001) var epsilon_decay: float = 0.995
@export_range(0.0, 1.0, 0.001) var min_epsilon: float = 0.01
@export_range(2, 10, 1) var stat_bin_count: int = 4
@export_range(1, 10, 1) var distance_bin_size: int = 3
@export_range(0, 4, 1) var memory_length: int = 2

var q_table: Dictionary = {}
var _encoder: SurvivalStateEncoder = SurvivalStateEncoder.new()
var _state_history: Array[String] = []
var _action_history: Array[int] = []
var _reward_history: Array[int] = []


func _ready() -> void:
	_sync_encoder()


func get_algorithm_name() -> String:
	return "Expected SARSA (Survival)"


func get_parameter_definitions() -> Array[Dictionary]:
	return [
		_float_parameter(&"learning_rate", "Lernrate (Alpha)", 0.0, 1.0, 0.01,
			"Stärke eines Expected-SARSA-Updates."),
		_float_parameter(&"discount", "Discount (Gamma)", 0.0, 1.0, 0.01,
			"Gewicht zukünftiger Rewards."),
		_float_parameter(&"epsilon", "Exploration (Epsilon)", 0.0, 1.0, 0.01,
			"Wahrscheinlichkeit einer zufälligen erlaubten Aktion."),
		_float_parameter(&"epsilon_decay", "Epsilon-Abnahme", 0.0, 1.0, 0.001,
			"Epsilon wird nach jeder Episode damit multipliziert."),
		_float_parameter(&"min_epsilon", "Min. Epsilon", 0.0, 1.0, 0.01,
			"Untere Grenze für Exploration."),
		_integer_parameter(&"stat_bin_count", "Survival-Bins", 2, 10, 1,
			"Anzahl Kategorien für HP, Hydration und Nahrung. Änderung löscht das Modell."),
		_integer_parameter(&"distance_bin_size", "Distanz-Bin (Tiles)", 1, 10, 1,
			"Mehrere Entfernungen werden zusammengefasst. Änderung löscht das Modell."),
		_integer_parameter(&"memory_length", "Gedächtnis (Schritte)", 0, 4, 1,
			"Vorherige kompakte Zustände, Aktionen und Rewards. Änderung löscht das Modell."),
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
		&"stat_bin_count":
			return stat_bin_count
		&"distance_bin_size":
			return distance_bin_size
		&"memory_length":
			return memory_length
	return null


func set_parameter_value(key: StringName, value: Variant) -> void:
	var encoding_changed: bool = false
	match key:
		&"learning_rate":
			learning_rate = clampf(float(value), 0.0, 1.0)
		&"discount":
			discount = clampf(float(value), 0.0, 1.0)
		&"epsilon":
			epsilon = clampf(float(value), 0.0, 1.0)
		&"epsilon_decay":
			epsilon_decay = clampf(float(value), 0.0, 1.0)
		&"min_epsilon":
			min_epsilon = clampf(float(value), 0.0, 1.0)
			epsilon = maxf(epsilon, min_epsilon)
		&"stat_bin_count":
			var new_stat_bin_count: int = clampi(int(value), 2, 10)
			encoding_changed = new_stat_bin_count != stat_bin_count
			stat_bin_count = new_stat_bin_count
		&"distance_bin_size":
			var new_distance_bin_size: int = clampi(int(value), 1, 10)
			encoding_changed = new_distance_bin_size != distance_bin_size
			distance_bin_size = new_distance_bin_size
		&"memory_length":
			var new_memory_length: int = clampi(int(value), 0, 4)
			encoding_changed = new_memory_length != memory_length
			memory_length = new_memory_length
		_:
			return
	_sync_encoder()
	if encoding_changed:
		reset_model()
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
			"label": "Kompakte Zustände",
			"value": str(q_table.size()),
		},
		{
			"key": &"state_encoder",
			"label": "Zustandskodierung",
			"value": _encoder.get_description(),
		},
		{
			"key": &"temporal_memory",
			"label": "Zeitliches Gedächtnis",
			"value": "%d / %d Schritte" % [_state_history.size(), memory_length],
		},
	]


func get_model_summary() -> String:
	return "%d Expected-SARSA-Zustände" % q_table.size()


func reset_model() -> void:
	q_table.clear()
	_clear_memory()
	model_changed.emit()


func on_training_started() -> void:
	_clear_memory()


func on_episode_finished(terminated: bool, _truncated: bool) -> void:
	epsilon = maxf(min_epsilon, epsilon * epsilon_decay)
	configuration_changed.emit(&"epsilon", epsilon)
	if terminated:
		_clear_memory()


func choose_action(state: Dictionary, available_actions: DiscreteSpace) -> int:
	var compact_state: String = _encoder.encode(state)
	var state_key: String = _encode_with_history(
		compact_state,
		_state_history,
		_action_history,
		_reward_history
	)
	_ensure_state(state_key, available_actions.size)
	var valid_actions: Array[int] = _get_valid_actions(state, available_actions.size)
	if randf() < epsilon:
		return valid_actions[randi_range(0, valid_actions.size() - 1)]

	var action_values: Array = q_table[state_key]
	var best_actions: Array[int] = _get_best_actions(action_values, valid_actions)
	return best_actions[randi_range(0, best_actions.size() - 1)]


func learn_from_transition(
		state: Dictionary,
		action: int,
		result: EnvStepResult,
		action_space: DiscreteSpace
	) -> void:
	if action < 0 or action >= action_space.size:
		return
	var compact_state: String = _encoder.encode(state)
	var state_key: String = _encode_with_history(
		compact_state,
		_state_history,
		_action_history,
		_reward_history
	)
	_ensure_state(state_key, action_space.size)

	var target: float = result.reward
	if not result.terminated:
		var next_state_history: Array[String] = []
		var next_action_history: Array[int] = []
		var next_reward_history: Array[int] = []
		next_state_history.assign(_state_history)
		next_action_history.assign(_action_history)
		next_reward_history.assign(_reward_history)
		_append_transition_to(
			next_state_history,
			next_action_history,
			next_reward_history,
			compact_state,
			action,
			_reward_bucket(result.reward)
		)
		var next_compact_state: String = _encoder.encode(result.observation)
		var next_state_key: String = _encode_with_history(
			next_compact_state,
			next_state_history,
			next_action_history,
			next_reward_history
		)
		_ensure_state(next_state_key, action_space.size)
		var next_action_values: Array = q_table[next_state_key]
		var next_valid_actions: Array[int] = _get_valid_actions(
			result.observation,
			action_space.size
		)
		target += discount * _expected_policy_value(next_action_values, next_valid_actions)

	var action_values: Array = q_table[state_key]
	var current_value: float = float(action_values[action])
	action_values[action] = current_value + learning_rate * (target - current_value)
	q_table[state_key] = action_values
	_append_transition_to(
		_state_history,
		_action_history,
		_reward_history,
		compact_state,
		action,
		_reward_bucket(result.reward)
	)
	model_changed.emit()


func encode_state(state: Dictionary) -> String:
	return _encode_with_history(
		_encoder.encode(state),
		_state_history,
		_action_history,
		_reward_history
	)


func _encode_with_history(
		compact_state: String,
		state_history: Array[String],
		action_history: Array[int],
		reward_history: Array[int]
	) -> String:
	if memory_length <= 0 or state_history.is_empty():
		return compact_state
	var entries: Array[String] = []
	var first_index: int = maxi(0, state_history.size() - memory_length)
	for history_index: int in range(first_index, state_history.size()):
		var action: int = action_history[history_index] \
				if history_index < action_history.size() else -1
		var reward: int = reward_history[history_index] \
				if history_index < reward_history.size() else 0
		entries.append("{%s;a=%d;r=%d}" % [
			state_history[history_index],
			action,
			reward,
		])
	return "%s|history=%s" % [compact_state, ";".join(entries)]


func _append_transition_to(
		state_history: Array[String],
		action_history: Array[int],
		reward_history: Array[int],
		compact_state: String,
		action: int,
		reward: int
	) -> void:
	if memory_length <= 0:
		state_history.clear()
		action_history.clear()
		reward_history.clear()
		return
	state_history.append(compact_state)
	action_history.append(action)
	reward_history.append(reward)
	while state_history.size() > memory_length:
		state_history.pop_front()
		action_history.pop_front()
		reward_history.pop_front()


func _reward_bucket(reward: float) -> int:
	if reward <= -1.0:
		return -2
	if reward <= -0.05:
		return -1
	if reward < 1.0:
		return 0
	return 1


func _clear_memory() -> void:
	_state_history.clear()
	_action_history.clear()
	_reward_history.clear()


func _expected_policy_value(action_values: Array, valid_actions: Array[int]) -> float:
	var best_actions: Array[int] = _get_best_actions(action_values, valid_actions)
	var exploration_average: float = 0.0
	for action: int in valid_actions:
		exploration_average += float(action_values[action])
	exploration_average /= float(valid_actions.size())
	var greedy_value: float = float(action_values[best_actions[0]])
	return epsilon * exploration_average + (1.0 - epsilon) * greedy_value


func _get_best_actions(action_values: Array, valid_actions: Array[int]) -> Array[int]:
	var best_actions: Array[int] = []
	var best_value: float = -INF
	for action: int in valid_actions:
		var value: float = float(action_values[action])
		if value > best_value:
			best_value = value
			best_actions.clear()
			best_actions.append(action)
		elif is_equal_approx(value, best_value):
			best_actions.append(action)
	return best_actions


func _get_valid_actions(state: Dictionary, action_count: int) -> Array[int]:
	var valid_actions: Array[int] = []
	var action_mask: PackedByteArray = state.get("action_mask", PackedByteArray())
	for action: int in range(action_count):
		if action >= action_mask.size() or action_mask[action] != 0:
			valid_actions.append(action)
	if valid_actions.is_empty():
		for action: int in range(action_count):
			valid_actions.append(action)
	return valid_actions


func _ensure_state(key: String, action_count: int) -> void:
	if q_table.has(key):
		return
	var action_values: Array[float] = []
	action_values.resize(action_count)
	action_values.fill(0.0)
	q_table[key] = action_values


func _sync_encoder() -> void:
	_encoder.configure(stat_bin_count, distance_bin_size)


func _float_parameter(
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


func _integer_parameter(
		key: StringName,
		label: String,
		minimum: int,
		maximum: int,
		step: int,
		tooltip: String
	) -> Dictionary:
	return {
		"key": key,
		"label": label,
		"type": RLAgent.ParameterType.INTEGER,
		"min": minimum,
		"max": maximum,
		"step": step,
		"tooltip": tooltip,
	}
