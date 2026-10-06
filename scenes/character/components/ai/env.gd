extends Node
class_name Env

enum State {
	NOT_READY,
	READY,
	STEPPING,
	FINISHED,
	CLOSED,
}

var action_space: Space
var observation_space: Space
var state := State.NOT_READY


func observe() -> Dictionary:
	push_error("Env.observe() must be implemented by a concrete environment")
	return {}


func step(_action: Variant) -> EnvStepResult:
	push_error("Env.step() must be implemented by a concrete environment")
	return EnvStepResult.new()


func seed(seed_value: int) -> void:
	if action_space != null:
		action_space.seed(seed_value)
	if observation_space != null:
		observation_space.seed(seed_value + 1)


func is_finished() -> bool:
	return state == State.FINISHED or state == State.CLOSED


func render() -> void:
	pass


func close() -> void:
	state = State.CLOSED
