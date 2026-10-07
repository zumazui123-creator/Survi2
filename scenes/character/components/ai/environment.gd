extends Env
class_name Survi2NavigationEnv

signal step_completed(result: EnvStepResult)
signal environment_finished(terminated: bool, truncated: bool)

const ACTION_UP: int = 0
const ACTION_DOWN: int = 1
const ACTION_LEFT: int = 2
const ACTION_RIGHT: int = 3
const ACTION_COUNT: int = 4
const GOAL_DELTA_LIMIT: float = 1000000.0

const ACTION_DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.RIGHT,
]
const ACTION_NAMES: Array[StringName] = [
	&"up",
	&"down",
	&"left",
	&"right",
]

@export_group("References")
@export var player: CharacterBody2D
@export var sensor: PlayerSensor
@export var movement: PlayerMovement
@export var stats: PlayerStats
@export var goal_tracker: PlayerGoalTracker

@export_group("Episode")
@export_range(1, 100000, 1) var max_steps: int = 500
@export var reward_policy: NavigationRewardPolicy = NavigationRewardPolicy.new()

var step_count: int = 0
var _goal_reached: bool = false
var _player_died: bool = false
var _last_transition_terminated: bool = false
var _last_transition_truncated: bool = false


func _ready() -> void:
	action_space = DiscreteSpace.new(ACTION_COUNT)
	_rebuild_observation_space()

	if not _has_required_references():
		push_error("Survi2NavigationEnv: required player references are missing")
		return
	if not sensor.radius_changed.is_connected(_on_sensor_radius_changed):
		sensor.radius_changed.connect(_on_sensor_radius_changed)
	if not goal_tracker.goal_reached.is_connected(_on_goal_reached):
		goal_tracker.goal_reached.connect(_on_goal_reached)
	if not stats.died.is_connected(_on_player_died):
		stats.died.connect(_on_player_died)
	state = State.READY


func _rebuild_observation_space() -> void:
	observation_space = DictSpace.new({
		"local_map": BoxSpace.new(
			sensor.get_observation_shape() if is_instance_valid(sensor) else PackedInt32Array(),
			0.0,
			1.0,
			BoxSpace.ElementType.BYTE
		),
		"stats": BoxSpace.new(
			PackedInt32Array([PlayerSensor.STAT_COUNT]),
			0.0,
			1.0,
			BoxSpace.ElementType.FLOAT
		),
		"inventory": BoxSpace.new(
			sensor.get_inventory_observation_shape() if is_instance_valid(sensor) else PackedInt32Array(),
			0.0,
			PlayerSensor.MAX_INVENTORY_ITEM_COUNT,
			BoxSpace.ElementType.FLOAT
		),
		"equipped_item": BoxSpace.new(
			sensor.get_inventory_observation_shape() if is_instance_valid(sensor) else PackedInt32Array(),
			0.0,
			1.0,
			BoxSpace.ElementType.BYTE
		),
		"goal_delta": BoxSpace.new(
			PackedInt32Array([2]),
			-GOAL_DELTA_LIMIT,
			GOAL_DELTA_LIMIT,
			BoxSpace.ElementType.FLOAT
		),
		"action_mask": BoxSpace.new(
			PackedInt32Array([ACTION_COUNT]),
			0.0,
			1.0,
			BoxSpace.ElementType.BYTE
		),
	})

func observe() -> Dictionary:
	if not is_instance_valid(sensor):
		return {}
	var observation: Dictionary = sensor.scan()
	if observation_space != null and not observation_space.contains(observation):
		push_error("Survi2NavigationEnv: sensor returned an invalid observation")
	return observation


func step(action: Variant) -> EnvStepResult:
	if state != State.READY:
		return _invalid_step_result("Environment is not ready for another step")
	if action_space == null or not action_space.contains(action):
		return _invalid_step_result("Action is outside action_space")
	if not player.is_multiplayer_authority():
		return _invalid_step_result("Only the authoritative player can be AI-controlled")
	if not sensor.is_ready_to_scan():
		return _invalid_step_result("Map and sensor are not ready")

	if _is_terminated():
		return _finish_without_action()
	if not movement.acquire_control(PlayerMovement.ControlMode.AI):
		return _invalid_step_result("Player control is owned by another controller")

	state = State.STEPPING
	var action_index: int = int(action)
	var movement_succeeded: bool = false
	var movement_started: bool = movement.request_tile_step(
		ACTION_DIRECTIONS[action_index],
		PlayerMovement.ControlMode.AI
	)
	if movement_started:
		var movement_result: Array = await movement.tile_step_resolved
		movement_succeeded = movement_result.size() >= 2 and bool(movement_result[1])

	step_count += 1
	var terminated: bool = _is_terminated()
	var truncated: bool = not terminated and step_count >= max_steps
	var observation: Dictionary = observe()
	var reward: float = reward_policy.calculate(
		movement_succeeded,
		_goal_reached,
		_player_died
	)
	var result: EnvStepResult = EnvStepResult.new(
		observation,
		reward,
		terminated,
		truncated,
		_build_info(action_index, movement_succeeded)
	)
	_last_transition_terminated = terminated
	_last_transition_truncated = truncated

	if result.is_done():
		state = State.FINISHED
		movement.release_control(PlayerMovement.ControlMode.AI)
		environment_finished.emit(terminated, truncated)
	else:
		state = State.READY
	step_completed.emit(result)
	return result


func close() -> void:
	release_ai_control()
	super()


func release_ai_control() -> void:
	if is_instance_valid(movement):
		movement.release_control(PlayerMovement.ControlMode.AI)


func can_continue_after_truncation() -> bool:
	if state != State.FINISHED \
			or not _last_transition_truncated \
			or _last_transition_terminated:
		return false
	return not _is_terminated()


func continue_after_truncation() -> bool:
	if not can_continue_after_truncation():
		return false
	step_count = 0
	_last_transition_terminated = false
	_last_transition_truncated = false
	state = State.READY
	return true


func has_terminated() -> bool:
	return _is_terminated()


func _finish_without_action() -> EnvStepResult:
	state = State.FINISHED
	movement.release_control(PlayerMovement.ControlMode.AI)
	var result: EnvStepResult = EnvStepResult.new(
		observe(),
		reward_policy.calculate(false, _goal_reached, _player_died),
		true,
		false,
		_build_info(-1, false)
	)
	_last_transition_terminated = true
	_last_transition_truncated = false
	environment_finished.emit(true, false)
	step_completed.emit(result)
	return result


func _invalid_step_result(message: String) -> EnvStepResult:
	push_error("Survi2NavigationEnv: " + message)
	return EnvStepResult.new(
		observe(),
		0.0,
		state == State.FINISHED,
		false,
		{
			"error": message,
			"step_count": step_count,
		}
	)


func _build_info(action: int, movement_succeeded: bool) -> Dictionary:
	return {
		"step_count": step_count,
		"action": action,
		"action_name": ACTION_NAMES[action] if action >= 0 and action < ACTION_NAMES.size() else &"none",
		"movement_succeeded": movement_succeeded,
		"map_position": movement.current_map_position,
		"goal_reached": _goal_reached,
		"player_died": _player_died,
	}


func _is_terminated() -> bool:
	_goal_reached = _goal_reached \
		or goal_tracker.is_completed \
		or stats.terminated
	_player_died = _player_died or stats.hp <= 0.0
	return _goal_reached or _player_died


func _has_required_references() -> bool:
	return is_instance_valid(player) \
		and is_instance_valid(sensor) \
		and is_instance_valid(movement) \
		and is_instance_valid(stats) \
		and is_instance_valid(goal_tracker) \
		and reward_policy != null


func _on_goal_reached() -> void:
	_goal_reached = true


func _on_player_died() -> void:
	_player_died = true


func _on_sensor_radius_changed(_radius: int) -> void:
	_rebuild_observation_space()


func _exit_tree() -> void:
	close()
