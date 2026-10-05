extends Node
class_name RLTrainer

@export var agent: RLAgent
@export var environment: RLEnvironment

# --- Training config ---
@export var max_steps_per_episode := 100
@export var episodes := 1000
@export var epsilon_decay := 0.995
@export var min_epsilon := 0.01

# --- Runtime ---
var current_episode := 0
var training := false
var total_reward := 0.0


func _ready():
	randomize()


# --- Public API ---

func start_training():
	if not agent or not environment:
		push_error("RLTrainer: Agent or Environment not assigned")
		return

	training = true
	current_episode = 0
	_run_training_loop()


func stop_training():
	training = false


# --- Core Loop ---

func _run_training_loop() -> void:
	while training and current_episode < episodes:
		await _run_episode()
		current_episode += 1

	training = false
	print("✅ Training finished")


func _run_episode() -> void:
	var state = environment.reset()
	var done := false
	var step := 0
	total_reward = 0.0

	while not done and step < max_steps_per_episode:
		var action = agent.choose_action(state)
		var result = environment.step(action)

		agent.learn(
			state,
			action,
			result.reward,
			result.state
		)

		state = result.state
		done = result.done
		total_reward += result.reward
		step += 1

		# Optional: slow down for visualization
		await get_tree().process_frame

	# --- Epsilon decay ---
	agent.epsilon = max(
		min_epsilon,
		agent.epsilon * epsilon_decay
	)

	# --- Debug ---
	_log_episode(step)


# --- Debug / Monitoring ---

func _log_episode(steps: int):
	print(
		"Episode ",
		current_episode,
		" | Steps: ",
		steps,
		" | Total Reward: ",
		total_reward,
		" | Epsilon: ",
		agent.epsilon
	)
