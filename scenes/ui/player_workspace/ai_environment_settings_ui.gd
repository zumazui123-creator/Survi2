extends MarginContainer
class_name AIEnvironmentSettingsUI

var environment: Survi2NavigationEnv
var trainer: RLTrainer
var sensor: PlayerSensor

@onready var sensor_visualization_toggle: CheckButton = %SensorVisualizationToggle
@onready var sensor_radius_input: SpinBox = %SensorRadiusInput
@onready var reward_policy_editor: NavigationRewardPolicyEditor = %RewardSettingsPanel


func bind_components(
		value_environment: Survi2NavigationEnv,
		value_trainer: RLTrainer
	) -> void:
	_disconnect_components()
	environment = value_environment
	trainer = value_trainer
	sensor = environment.sensor if is_instance_valid(environment) else null
	reward_policy_editor.bind_policy(
		environment.reward_policy if is_instance_valid(environment) else null
	)
	_connect_components()
	_sync_controls()


func _connect_components() -> void:
	if is_instance_valid(sensor):
		if not sensor.radius_changed.is_connected(_on_sensor_radius_updated):
			sensor.radius_changed.connect(_on_sensor_radius_updated)
		if not sensor.visualization_changed.is_connected(_on_sensor_visualization_updated):
			sensor.visualization_changed.connect(_on_sensor_visualization_updated)
	if is_instance_valid(trainer):
		if not trainer.training_started.is_connected(_on_training_started):
			trainer.training_started.connect(_on_training_started)
		if not trainer.training_finished.is_connected(_on_training_finished):
			trainer.training_finished.connect(_on_training_finished)
		if not trainer.training_stopped.is_connected(_on_training_finished):
			trainer.training_stopped.connect(_on_training_finished)
		if not trainer.training_failed.is_connected(_on_training_failed):
			trainer.training_failed.connect(_on_training_failed)


func _disconnect_components() -> void:
	if is_instance_valid(sensor):
		if sensor.radius_changed.is_connected(_on_sensor_radius_updated):
			sensor.radius_changed.disconnect(_on_sensor_radius_updated)
		if sensor.visualization_changed.is_connected(_on_sensor_visualization_updated):
			sensor.visualization_changed.disconnect(_on_sensor_visualization_updated)
	if is_instance_valid(trainer):
		if trainer.training_started.is_connected(_on_training_started):
			trainer.training_started.disconnect(_on_training_started)
		if trainer.training_finished.is_connected(_on_training_finished):
			trainer.training_finished.disconnect(_on_training_finished)
		if trainer.training_stopped.is_connected(_on_training_finished):
			trainer.training_stopped.disconnect(_on_training_finished)
		if trainer.training_failed.is_connected(_on_training_failed):
			trainer.training_failed.disconnect(_on_training_failed)


func _sync_controls() -> void:
	var sensor_available: bool = is_instance_valid(sensor)
	var settings_editable: bool = not is_instance_valid(trainer) or not trainer.training
	sensor_visualization_toggle.disabled = not sensor_available
	sensor_radius_input.editable = sensor_available and settings_editable
	reward_policy_editor.set_editable(is_instance_valid(environment) and settings_editable)
	if not sensor_available:
		sensor_visualization_toggle.set_pressed_no_signal(false)
		return
	sensor_visualization_toggle.set_pressed_no_signal(sensor.is_visualization_enabled())
	sensor_radius_input.set_value_no_signal(float(sensor.scan_radius_tiles))


func _on_sensor_visualization_toggled(value: bool) -> void:
	if is_instance_valid(sensor):
		sensor.set_visualization_enabled(value)


func _on_sensor_radius_changed(value: float) -> void:
	if is_instance_valid(sensor):
		sensor.set_scan_radius(int(value))


func _on_sensor_radius_updated(value: int) -> void:
	sensor_radius_input.set_value_no_signal(float(value))


func _on_sensor_visualization_updated(value: bool) -> void:
	sensor_visualization_toggle.set_pressed_no_signal(value)


func _on_training_started() -> void:
	_sync_controls()


func _on_training_finished(_steps: int, _total_reward: float) -> void:
	_sync_controls()


func _on_training_failed(_message: String) -> void:
	_sync_controls()


func _exit_tree() -> void:
	if is_instance_valid(sensor):
		sensor.set_visualization_enabled(false)
	_disconnect_components()
