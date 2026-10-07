extends MarginContainer
class_name RLPlaygroundUI

var agent: RLAgent
var trainer: RLTrainer
var environment: Survi2NavigationEnv
var sensor: PlayerSensor
var _episode_reward: float = 0.0
var _last_terminated: bool = false
var _last_truncated: bool = false
var _requested_run_status: String = "Agent läuft"
var _parameter_controls: Dictionary = {}

@onready var description_label: Label = %AgentDescription
@onready var ai_status_label: Label = %AIStatusValue
@onready var environment_status_label: Label = %EnvironmentStatusValue
@onready var algorithm_label: Label = %AlgorithmValue
@onready var episode_steps_label: Label = %EpisodeStepsValue
@onready var episode_reward_label: Label = %EpisodeRewardValue
@onready var model_summary_label: Label = %ModelSummaryValue
@onready var last_action_label: Label = %LastActionValue
@onready var agent_metrics_title: Label = %AgentMetricsTitle
@onready var agent_metrics_grid: GridContainer = %AgentMetricsGrid
@onready var max_steps_input: SpinBox = %MaxStepsInput
@onready var agent_settings_grid: GridContainer = %AgentSettingsGrid
@onready var sensor_visualization_toggle: CheckButton = %SensorVisualizationToggle
@onready var sensor_radius_input: SpinBox = %SensorRadiusInput
@onready var reward_policy_editor: NavigationRewardPolicyEditor = %RewardSettingsPanel
@onready var start_training_button: Button = %StartTrainingButton
@onready var random_policy_button: Button = %RandomPolicyButton
@onready var stop_training_button: Button = %StopTrainingButton
@onready var reset_agent_button: Button = %ClearPolicyButton


func bind_components(
		value_agent: RLAgent,
		value_trainer: RLTrainer,
		value_environment: Survi2NavigationEnv
	) -> void:
	_disconnect_components()
	agent = value_agent
	trainer = value_trainer
	environment = value_environment
	sensor = environment.sensor if is_instance_valid(environment) else null
	_sync_sensor_controls()

	if not _has_valid_components():
		_set_ai_status("Nicht verfügbar")
		environment_status_label.text = "Player-AI ist nicht vollständig verbunden"
		reward_policy_editor.bind_policy(null)
		_set_controls_enabled(false)
		return

	if not trainer.set_agent(agent):
		_set_ai_status("Agent kann während eines laufenden Trainings nicht gewechselt werden")
		_set_controls_enabled(false)
		return
	_connect_components()
	reward_policy_editor.bind_policy(environment.reward_policy)
	algorithm_label.text = agent.get_algorithm_name()
	description_label.text = "%s auf dem TileMap-Environment" % agent.get_algorithm_name()
	max_steps_input.value = float(environment.max_steps)
	_build_agent_parameter_editor()
	_refresh_metrics()
	_set_ai_status("Bereit")
	_refresh_controls()


func _has_valid_components() -> bool:
	return is_instance_valid(agent) \
			and is_instance_valid(trainer) \
			and is_instance_valid(environment)


func _connect_components() -> void:
	if not trainer.training_started.is_connected(_on_training_started):
		trainer.training_started.connect(_on_training_started)
	if not trainer.training_finished.is_connected(_on_training_finished):
		trainer.training_finished.connect(_on_training_finished)
	if not trainer.training_stopped.is_connected(_on_training_stopped):
		trainer.training_stopped.connect(_on_training_stopped)
	if not trainer.training_failed.is_connected(_on_training_failed):
		trainer.training_failed.connect(_on_training_failed)
	if not trainer.agent_changed.is_connected(_on_trainer_agent_changed):
		trainer.agent_changed.connect(_on_trainer_agent_changed)
	if not environment.step_completed.is_connected(_on_step_completed):
		environment.step_completed.connect(_on_step_completed)
	if is_instance_valid(sensor):
		if not sensor.radius_changed.is_connected(_on_bound_sensor_radius_changed):
			sensor.radius_changed.connect(_on_bound_sensor_radius_changed)
		if not sensor.visualization_changed.is_connected(_on_bound_sensor_visualization_changed):
			sensor.visualization_changed.connect(_on_bound_sensor_visualization_changed)
	if not agent.configuration_changed.is_connected(_on_agent_configuration_changed):
		agent.configuration_changed.connect(_on_agent_configuration_changed)
	if not agent.model_changed.is_connected(_on_agent_model_changed):
		agent.model_changed.connect(_on_agent_model_changed)


func _disconnect_components() -> void:
	if is_instance_valid(trainer):
		if trainer.training_started.is_connected(_on_training_started):
			trainer.training_started.disconnect(_on_training_started)
		if trainer.training_finished.is_connected(_on_training_finished):
			trainer.training_finished.disconnect(_on_training_finished)
		if trainer.training_stopped.is_connected(_on_training_stopped):
			trainer.training_stopped.disconnect(_on_training_stopped)
		if trainer.training_failed.is_connected(_on_training_failed):
			trainer.training_failed.disconnect(_on_training_failed)
		if trainer.agent_changed.is_connected(_on_trainer_agent_changed):
			trainer.agent_changed.disconnect(_on_trainer_agent_changed)
	if is_instance_valid(environment) and environment.step_completed.is_connected(_on_step_completed):
		environment.step_completed.disconnect(_on_step_completed)
	if is_instance_valid(sensor):
		if sensor.radius_changed.is_connected(_on_bound_sensor_radius_changed):
			sensor.radius_changed.disconnect(_on_bound_sensor_radius_changed)
		if sensor.visualization_changed.is_connected(_on_bound_sensor_visualization_changed):
			sensor.visualization_changed.disconnect(_on_bound_sensor_visualization_changed)
	if is_instance_valid(agent):
		if agent.configuration_changed.is_connected(_on_agent_configuration_changed):
			agent.configuration_changed.disconnect(_on_agent_configuration_changed)
		if agent.model_changed.is_connected(_on_agent_model_changed):
			agent.model_changed.disconnect(_on_agent_model_changed)


func _on_trainer_agent_changed(value: RLAgent) -> void:
	if value == agent or not is_instance_valid(value):
		return
	if is_instance_valid(agent):
		if agent.configuration_changed.is_connected(_on_agent_configuration_changed):
			agent.configuration_changed.disconnect(_on_agent_configuration_changed)
		if agent.model_changed.is_connected(_on_agent_model_changed):
			agent.model_changed.disconnect(_on_agent_model_changed)
	agent = value
	agent.configuration_changed.connect(_on_agent_configuration_changed)
	agent.model_changed.connect(_on_agent_model_changed)
	algorithm_label.text = agent.get_algorithm_name()
	description_label.text = "%s auf dem TileMap-Environment" % agent.get_algorithm_name()
	_build_agent_parameter_editor()
	_refresh_metrics()
	_refresh_controls()


func _build_agent_parameter_editor() -> void:
	_clear_container(agent_settings_grid)
	_parameter_controls.clear()
	var definitions: Array[Dictionary] = agent.get_parameter_definitions()
	if definitions.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "Dieser Agent besitzt keine konfigurierbaren Parameter."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		agent_settings_grid.add_child(empty_label)
		return

	for definition: Dictionary in definitions:
		_add_agent_parameter(definition)


func _add_agent_parameter(definition: Dictionary) -> void:
	var key: StringName = StringName(definition.get("key", &""))
	if key == &"":
		return
	var tooltip: String = String(definition.get("tooltip", ""))
	var parameter_label: Label = Label.new()
	parameter_label.text = String(definition.get("label", key))
	parameter_label.tooltip_text = tooltip
	agent_settings_grid.add_child(parameter_label)

	var parameter_type: int = int(definition.get("type", RLAgent.ParameterType.FLOAT))
	if parameter_type == RLAgent.ParameterType.BOOLEAN:
		var checkbox: CheckBox = CheckBox.new()
		checkbox.button_pressed = bool(agent.get_parameter_value(key))
		checkbox.tooltip_text = tooltip
		checkbox.toggled.connect(_on_boolean_parameter_changed.bind(key))
		agent_settings_grid.add_child(checkbox)
		_parameter_controls[key] = checkbox
		return

	var spin_box: SpinBox = SpinBox.new()
	spin_box.custom_minimum_size = Vector2(135.0, 0.0)
	spin_box.min_value = float(definition.get("min", 0.0))
	spin_box.max_value = float(definition.get("max", 1.0))
	spin_box.step = float(definition.get("step", 1.0))
	spin_box.value = float(agent.get_parameter_value(key))
	spin_box.tooltip_text = tooltip
	spin_box.value_changed.connect(_on_numeric_parameter_changed.bind(key, parameter_type))
	agent_settings_grid.add_child(spin_box)
	_parameter_controls[key] = spin_box


func _on_numeric_parameter_changed(value: float, key: StringName, parameter_type: int) -> void:
	if not is_instance_valid(agent):
		return
	var parameter_value: Variant = int(value) if parameter_type == RLAgent.ParameterType.INTEGER else value
	agent.set_parameter_value(key, parameter_value)


func _on_boolean_parameter_changed(value: bool, key: StringName) -> void:
	if is_instance_valid(agent):
		agent.set_parameter_value(key, value)


func _on_agent_configuration_changed(key: StringName, value: Variant) -> void:
	var control: Control = _parameter_controls.get(key) as Control
	if control is SpinBox:
		(control as SpinBox).set_value_no_signal(float(value))
	elif control is CheckBox:
		(control as CheckBox).set_pressed_no_signal(bool(value))
	_render_agent_metrics()


func _on_agent_model_changed() -> void:
	model_summary_label.text = agent.get_model_summary()
	_render_agent_metrics()


func _render_agent_metrics() -> void:
	_clear_container(agent_metrics_grid)
	var metrics: Array[Dictionary] = agent.get_runtime_metrics()
	agent_metrics_title.visible = not metrics.is_empty()
	agent_metrics_grid.visible = not metrics.is_empty()
	for metric: Dictionary in metrics:
		var metric_label: Label = Label.new()
		metric_label.text = String(metric.get("label", "Metrik"))
		agent_metrics_grid.add_child(metric_label)
		var metric_value: Label = Label.new()
		metric_value.text = String(metric.get("value", "–"))
		metric_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		agent_metrics_grid.add_child(metric_value)


func _clear_container(container: Container) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _refresh_metrics() -> void:
	if not _has_valid_components():
		return
	episode_steps_label.text = "%d / %d" % [environment.step_count, environment.max_steps]
	episode_reward_label.text = "%.3f" % _episode_reward
	model_summary_label.text = agent.get_model_summary()
	environment_status_label.text = _environment_state_text()
	_render_agent_metrics()


func _refresh_controls() -> void:
	if not _has_valid_components():
		_set_controls_enabled(false)
		return
	var is_training: bool = trainer.training
	var can_start: bool = not is_training and environment.state == Env.State.READY
	start_training_button.disabled = not can_start
	random_policy_button.disabled = not can_start
	stop_training_button.disabled = not is_training
	reset_agent_button.disabled = is_training
	_set_inputs_editable(can_start)
	_refresh_sensor_controls()


func _set_controls_enabled(value: bool) -> void:
	start_training_button.disabled = not value
	random_policy_button.disabled = not value
	stop_training_button.disabled = true
	reset_agent_button.disabled = not value
	_set_inputs_editable(value)
	_refresh_sensor_controls()


func _set_inputs_editable(value: bool) -> void:
	max_steps_input.editable = value
	for control_value: Variant in _parameter_controls.values():
		var control: Control = control_value as Control
		if control is SpinBox:
			(control as SpinBox).editable = value
		elif control is CheckBox:
			(control as CheckBox).disabled = not value
	reward_policy_editor.set_editable(value)
	if is_instance_valid(sensor_radius_input):
		sensor_radius_input.editable = value and is_instance_valid(sensor)


func _sync_sensor_controls() -> void:
	var sensor_available: bool = is_instance_valid(sensor)
	sensor_visualization_toggle.disabled = not sensor_available
	sensor_radius_input.editable = sensor_available \
		and (not is_instance_valid(trainer) or not trainer.training)
	if not sensor_available:
		sensor_visualization_toggle.set_pressed_no_signal(false)
		return
	sensor_visualization_toggle.set_pressed_no_signal(sensor.is_visualization_enabled())
	sensor_radius_input.set_value_no_signal(float(sensor.scan_radius_tiles))


func _refresh_sensor_controls() -> void:
	var sensor_available: bool = is_instance_valid(sensor)
	sensor_visualization_toggle.disabled = not sensor_available
	sensor_radius_input.editable = sensor_available \
		and (not is_instance_valid(trainer) or not trainer.training)


func _on_sensor_visualization_toggled(value: bool) -> void:
	if is_instance_valid(sensor):
		sensor.set_visualization_enabled(value)


func _on_sensor_radius_changed(value: float) -> void:
	if is_instance_valid(sensor):
		sensor.set_scan_radius(int(value))


func _on_bound_sensor_radius_changed(value: int) -> void:
	sensor_radius_input.set_value_no_signal(float(value))


func _on_bound_sensor_visualization_changed(value: bool) -> void:
	sensor_visualization_toggle.set_pressed_no_signal(value)


func _environment_state_text() -> String:
	if not is_instance_valid(environment):
		return "Nicht verbunden"
	if is_instance_valid(trainer) and trainer.training:
		return "Aktion wird ausgeführt" if environment.state == Env.State.STEPPING else "Episode aktiv"
	match environment.state:
		Env.State.NOT_READY:
			return "Nicht bereit"
		Env.State.READY:
			return "Bereit für step(action)"
		Env.State.STEPPING:
			return "Aktion wird ausgeführt"
		Env.State.FINISHED:
			return "Episode beendet"
		Env.State.CLOSED:
			return "Geschlossen"
	return "Unbekannt"


func _set_ai_status(value: String) -> void:
	ai_status_label.text = value


func _can_start() -> bool:
	if not _has_valid_components():
		_set_ai_status("Player-AI ist nicht verbunden")
		return false
	if environment.state == Env.State.FINISHED or environment.state == Env.State.CLOSED:
		_set_ai_status("Episode beendet – Level für eine neue Episode neu laden")
		return false
	if environment.state != Env.State.READY:
		_set_ai_status("Environment ist noch nicht bereit")
		return false
	if not is_instance_valid(environment.sensor) or not environment.sensor.is_ready_to_scan():
		_set_ai_status("Sensor wartet auf die TileMap")
		return false
	return true


func _on_start_training_pressed() -> void:
	if not _can_start():
		return
	_requested_run_status = "%s läuft" % agent.get_algorithm_name()
	trainer.start_training()


func _on_random_policy_pressed() -> void:
	if not _can_start():
		return
	_requested_run_status = "Zufallspolicy läuft"
	trainer.start_random_policy()


func _on_stop_training_pressed() -> void:
	if is_instance_valid(trainer):
		trainer.stop_training()
		_set_ai_status("Stop angefordert …")


func _on_reset_agent_pressed() -> void:
	if not is_instance_valid(agent) or (is_instance_valid(trainer) and trainer.training):
		return
	agent.reset_model()
	_set_ai_status("Agent-Modell zurückgesetzt")


func _on_training_started() -> void:
	_episode_reward = trainer.total_reward
	_last_terminated = false
	_last_truncated = false
	if trainer.completed_steps == 0:
		last_action_label.text = "–"
	_set_ai_status(_requested_run_status)
	_refresh_metrics()
	_refresh_controls()


func _on_step_completed(result: EnvStepResult) -> void:
	_episode_reward += result.reward
	_last_terminated = result.terminated
	_last_truncated = result.truncated
	var action_name: StringName = StringName(result.info.get("action_name", &"none"))
	var movement_succeeded: bool = bool(result.info.get("movement_succeeded", false))
	last_action_label.text = "%s · %s" % [
		_localized_action_name(action_name),
		"frei" if movement_succeeded else "blockiert",
	]
	_refresh_metrics()


func _localized_action_name(action_name: StringName) -> String:
	match action_name:
		&"up":
			return "oben"
		&"down":
			return "unten"
		&"left":
			return "links"
		&"right":
			return "rechts"
	return "keine Aktion"


func _on_training_finished(steps: int, total_reward: float) -> void:
	_episode_reward = total_reward
	if _last_terminated:
		_set_ai_status("Episode regulär beendet")
	elif _last_truncated:
		_set_ai_status("Schrittlimit nach %d Aktionen erreicht" % steps)
	else:
		_set_ai_status("Episode beendet")
	_refresh_metrics()
	_refresh_controls()


func _on_training_stopped(steps: int, total_reward: float) -> void:
	_episode_reward = total_reward
	_set_ai_status("Nach %d Aktionen angehalten" % steps)
	_refresh_metrics()
	_refresh_controls()


func _on_training_failed(message: String) -> void:
	_set_ai_status("Fehler: " + message)
	_refresh_metrics()
	_refresh_controls()


func _on_max_steps_changed(value: float) -> void:
	if is_instance_valid(environment):
		environment.max_steps = maxi(1, int(value))
		_refresh_metrics()


func _exit_tree() -> void:
	if is_instance_valid(sensor):
		sensor.set_visualization_enabled(false)
	_disconnect_components()
