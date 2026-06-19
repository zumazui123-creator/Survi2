extends Node
class_name RLAgent

var q_table := {}  # Dictionary: state -> action_values

var learning_rate := 0.1
var discount := 0.95
var epsilon := 0.2  # Exploration

const ACTIONS = 4

func encode_state(state: Array) -> String:
	return ",".join(state.map(func(x): return str(x)))

func choose_action(state: Array) -> int:
	var key = encode_state(state)

	if not q_table.has(key):
		q_table[key] = []
		for i in ACTIONS:
			q_table[key].append(0.0)

	# Exploration
	if randf() < epsilon:
		return randi() % ACTIONS

	# Exploitation
	return q_table[key].find(q_table[key].max())

func learn(state, action, reward, next_state):
	var s = encode_state(state)
	var s2 = encode_state(next_state)

	if not q_table.has(s2):
		q_table[s2] = []
		for i in ACTIONS:
			q_table[s2].append(0.0)

	var best_next = q_table[s2].max()

	q_table[s][action] += learning_rate * (
		reward + discount * best_next - q_table[s][action]
	)
