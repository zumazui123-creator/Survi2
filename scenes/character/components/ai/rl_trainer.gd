extends Node
class_name RLTrainer

signal training_started()
signal training_finished(steps: int, total_reward: float)

@export var agent: RLAgent
@export var environment: Survi2NavigationEnv
@export_range(0.0, 1.0, 0.001) var epsilon_decay := 0.995
@export_range(0.0, 1.0, 0.001) var min_epsilon := 0.01

var training := false
var total_reward := 0.0
var completed_steps := 0


func start_training() -> void:
	_start_episode(false)


func start_random_policy() -> void:
	_start_episode(true)


func stop_training() -> void:
	training = false
	if is_instance_valid(environment) and not environment.is_finished():
		environment.close()


func _start_episode(random_policy: bool) -> void:
	if training:
		return
	if not is_instance_valid(agent) or not is_instance_valid(environment):
		push_error("RLTrainer: Agent or Environment not assigned")
		return
	if environment.is_finished():
		push_error("RLTrainer: Environment is finished and has no reset yet")
		return
	if not (environment.action_space is DiscreteSpace):
		push_error("RLTrainer: Environment requires a DiscreteSpace")
		return

	training = true
	total_reward = 0.0
	completed_steps = 0
	training_started.emit()
	_run_episode(random_policy)


func _run_episode(random_policy: bool) -> void:
	var state := environment.observe()
	var available_actions := environment.action_space as DiscreteSpace

	while training and not environment.is_finished():
		var action := int(available_actions.sample()) if random_policy else agent.choose_action(
			state,
			available_actions
		)
		var result: EnvStepResult = await environment.step(action)
		if result.info.has("error"):
			push_error("RLTrainer: " + String(result.info.error))
			break

		agent.learn(
			state,
			action,
			result.reward,
			result.observation,
			result.terminated,
			available_actions.size
		)
		state = result.observation
		total_reward += result.reward
		completed_steps += 1

		if result.is_done():
			break
		await get_tree().process_frame

	agent.epsilon = maxf(min_epsilon, agent.epsilon * epsilon_decay)
	training = false
	training_finished.emit(completed_steps, total_reward)
	print(
		"AI episode finished | Steps: ",
		completed_steps,
		" | Total reward: ",
		total_reward,
		" | Epsilon: ",
		agent.epsilon
	)
