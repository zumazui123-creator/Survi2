extends Node
class_name RLTrainer

signal training_started()
signal training_finished(steps: int, total_reward: float)
signal training_stopped(steps: int, total_reward: float)
signal training_failed(message: String)
signal agent_changed(value: RLAgent)
signal rollout_started(index: int, total: int)
signal rollout_finished(
	index: int,
	total: int,
	steps: int,
	reward: float,
	terminated: bool,
	truncated: bool
)

@export var agent: RLAgent
@export var environment: Survi2NavigationEnv
@export var agents_root: Node
@export_range(1, 1000, 1) var rollout_count: int = 10

var training: bool = false
var total_reward: float = 0.0
var completed_steps: int = 0
var current_rollout: int = 0
var completed_rollouts: int = 0
var rollout_reward: float = 0.0
var rollout_steps: int = 0
var _stop_requested: bool = false


func set_agent(value: RLAgent) -> bool:
	if training or not is_instance_valid(value):
		return false
	agent = value
	agent_changed.emit(agent)
	return true


func get_available_agents() -> Array[RLAgent]:
	var result: Array[RLAgent] = []
	if is_instance_valid(agents_root):
		for child: Node in agents_root.get_children():
			if child is RLAgent:
				result.append(child as RLAgent)
	if is_instance_valid(agent) and not result.has(agent):
		result.append(agent)
	return result


func start_training() -> bool:
	return _start_training_run(false)


func start_random_policy() -> bool:
	return _start_training_run(true)


func stop_training() -> void:
	if not training:
		return
	_stop_requested = true


func _start_training_run(random_policy: bool) -> bool:
	if training:
		return false
	if not is_instance_valid(agent) or not is_instance_valid(environment):
		return _fail_start("Agent oder Environment ist nicht zugewiesen")
	if not (environment.action_space is DiscreteSpace):
		return _fail_start("Das Environment benötigt einen DiscreteSpace")
	if environment.state == Env.State.CLOSED:
		return _fail_start("Das Environment ist geschlossen")
	if environment.has_terminated():
		return _fail_start("Die Player-Episode wurde durch Ziel oder Tod beendet")
	if environment.state == Env.State.FINISHED \
			and not environment.can_continue_after_truncation():
		return _fail_start("Die Player-Episode wurde durch Ziel oder Tod beendet")
	if environment.state != Env.State.READY \
			and not environment.can_continue_after_truncation():
		return _fail_start("Das Environment ist noch nicht bereit")

	_stop_requested = false
	training = true
	total_reward = 0.0
	completed_steps = 0
	current_rollout = 0
	completed_rollouts = 0
	rollout_reward = 0.0
	rollout_steps = 0
	agent.on_training_started()
	training_started.emit()
	_run_training_run(random_policy)
	return true


func _run_training_run(random_policy: bool) -> void:
	var failure_message: String = ""
	var run_terminated: bool = false

	for rollout_index: int in range(rollout_count):
		if _stop_requested:
			break
		if environment.state == Env.State.FINISHED \
				and not environment.continue_after_truncation():
			failure_message = "Der nächste Trainingsabschnitt kann nicht gestartet werden"
			break

		current_rollout = rollout_index + 1
		rollout_reward = 0.0
		rollout_steps = 0
		rollout_started.emit(current_rollout, rollout_count)
		var outcome: Dictionary = await _run_rollout(random_policy)
		failure_message = String(outcome.get("error", ""))
		if not failure_message.is_empty():
			break

		var terminated: bool = bool(outcome.get("terminated", false))
		var truncated: bool = bool(outcome.get("truncated", false))
		if _stop_requested and not terminated and not truncated:
			break
		if not terminated and not truncated:
			failure_message = "Der Trainingsabschnitt endete ohne terminated oder truncated"
			break

		completed_rollouts += 1
		agent.on_episode_finished(terminated, truncated)
		rollout_finished.emit(
			current_rollout,
			rollout_count,
			rollout_steps,
			rollout_reward,
			terminated,
			truncated
		)
		if terminated:
			run_terminated = true
			break
		if _stop_requested:
			break
		if current_rollout < rollout_count:
			await get_tree().process_frame

	environment.release_ai_control()
	training = false
	if not failure_message.is_empty():
		push_error("RLTrainer: " + failure_message)
		training_failed.emit(failure_message)
		return
	if _stop_requested and not run_terminated:
		training_stopped.emit(completed_steps, total_reward)
		return

	training_finished.emit(completed_steps, total_reward)
	print(
		"AI training finished | Rollouts: ",
		completed_rollouts,
		"/",
		rollout_count,
		" | Steps: ",
		completed_steps,
		" | Total reward: ",
		total_reward,
		" | Terminated: ",
		run_terminated,
		" | Agent: ",
		agent.get_algorithm_name()
	)


func _run_rollout(random_policy: bool) -> Dictionary:
	var state: Dictionary = environment.observe()
	var available_actions: DiscreteSpace = environment.action_space as DiscreteSpace
	var failure_message: String = ""
	var rollout_terminated: bool = false
	var rollout_truncated: bool = false

	while not _stop_requested and not environment.is_finished():
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
		rollout_reward += result.reward
		rollout_steps += 1
		rollout_terminated = result.terminated
		rollout_truncated = result.truncated

		if result.is_done():
			break
		await get_tree().process_frame

	return {
		"error": failure_message,
		"terminated": rollout_terminated,
		"truncated": rollout_truncated,
	}


func _fail_start(message: String) -> bool:
	push_error("RLTrainer: " + message)
	training_failed.emit(message)
	return false
