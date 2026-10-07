extends Node
class_name RLAgent

## Algorithm-independent contract used by RLTrainer and RLPlaygroundUI.
## Concrete agents expose their editor fields through get_parameter_definitions()
## and receive complete environment transitions through learn_from_transition().

signal configuration_changed(key: StringName, value: Variant)
signal model_changed()

enum ParameterType {
	FLOAT,
	INTEGER,
	BOOLEAN,
}


func get_algorithm_name() -> String:
	return "Unbekannter RL-Agent"


func get_parameter_definitions() -> Array[Dictionary]:
	return []


func get_parameter_value(_key: StringName) -> Variant:
	return null


func set_parameter_value(_key: StringName, _value: Variant) -> void:
	pass


func get_runtime_metrics() -> Array[Dictionary]:
	return []


func get_model_summary() -> String:
	return "Kein Modellstatus verfügbar"


func reset_model() -> void:
	model_changed.emit()


func on_training_started() -> void:
	pass


func on_episode_finished(_terminated: bool, _truncated: bool) -> void:
	pass


func choose_action(_state: Dictionary, available_actions: DiscreteSpace) -> int:
	push_error("RLAgent.choose_action() muss vom konkreten Agenten implementiert werden")
	return int(available_actions.sample())


func learn_from_transition(
		_state: Dictionary,
		_action: int,
		_result: EnvStepResult,
		_action_space: DiscreteSpace
	) -> void:
	pass
