extends Node
class_name RLTrainer

signal training_started()
signal training_finished(steps: int, total_reward: float)
signal training_stopped(steps: int, total_reward: float)
signal training_failed(message: String)
signal agent_changed(value: RLAgent)

@export var agent: RLAgent
@export var environment: Survi2NavigationEnv

var training: bool = false
var total_reward: float = 0.0
var completed_steps: int = 0
var _stop_requested: bool = false


func set_agent(value: RLAgent) -> bool:
	if training or not is_instance_valid(value):
		return false
	agent = value
	agent_changed.emit(agent)
	return true


func start_training() -> bool:
	return _start_episode(false)


func start_random_policy() -> bool:
	return _start_episode(true)


func stop_training() -> void:
	if not training:
		return
	_stop_requested = true
	training = false


func _start_episode(random_policy: bool) -> bool:
	if training:
		return false
	if not is_instance_valid(agent) or not is_instance_valid(environment):
		return _fail_start("Agent oder Environment ist nicht zugewiesen")
	if environment.is_finished():
		return _fail_start("Die Episode ist bereits beendet; lade das Level für eine neue Episode neu")
	if not (environment.action_space is DiscreteSpace):
		return _fail_start("Das Environment benötigt einen DiscreteSpace")

	_stop_requested = false
	training = true
	if environment.step_count == 0:
		total_reward = 0.0
		completed_steps = 0
	training_started.emit()
	_run_episode(random_policy)
	return true


func _run_episode(random_policy: bool) -> void:
	var state: Dictionary = environment.observe()
	var available_actions: DiscreteSpace = environment.action_space as DiscreteSpace
	var failure_message: String = ""
	var episode_terminated: bool = false
	var episode_truncated: bool = false

	while training and not environment.is_finished():
		var action: int = int(available_actions.sample()) if random_policy else agent.choose_action(
			state,
			available_actions
		)
		var result: EnvStepResult = await environment.step(action)
		if result.info.has("error"):
			failure_message = String(result.info.error)
			break

		agent.learn_from_transition(
			state,
			action,
			result,
			available_actions
		)
		state = result.observation
		total_reward += result.reward
		completed_steps += 1
		episode_terminated = result.terminated
		episode_truncated = result.truncated

		if result.is_done():
			break
		await get_tree().process_frame

	environment.release_ai_control()
	training = false
	if not failure_message.is_empty():
		push_error("RLTrainer: " + failure_message)
		training_failed.emit(failure_message)
		return
	if _stop_requested:
		training_stopped.emit(completed_steps, total_reward)
		return

	agent.on_episode_finished(episode_terminated, episode_truncated)
	training_finished.emit(completed_steps, total_reward)
	print(
		"AI episode finished | Steps: ",
		completed_steps,
		" | Total reward: ",
		total_reward,
		" | Agent: ",
		agent.get_algorithm_name()
	)


func _fail_start(message: String) -> bool:
	push_error("RLTrainer: " + message)
	training_failed.emit(message)
	return false
