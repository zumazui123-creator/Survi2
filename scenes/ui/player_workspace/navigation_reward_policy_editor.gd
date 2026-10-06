extends PanelContainer
class_name NavigationRewardPolicyEditor

var policy: NavigationRewardPolicy
var _syncing: bool = false

@onready var policy_type_label: Label = %RewardPolicyTypeValue
@onready var goal_reward_input: SpinBox = %GoalRewardInput
@onready var death_reward_input: SpinBox = %DeathRewardInput
@onready var blocked_reward_input: SpinBox = %BlockedRewardInput
@onready var step_reward_input: SpinBox = %StepRewardInput


func bind_policy(value: NavigationRewardPolicy) -> void:
	if is_instance_valid(policy) and policy.changed.is_connected(_on_policy_changed):
		policy.changed.disconnect(_on_policy_changed)
	policy = value
	if not is_instance_valid(policy):
		policy_type_label.text = "Nicht verbunden"
		set_editable(false)
		return
	if not policy.changed.is_connected(_on_policy_changed):
		policy.changed.connect(_on_policy_changed)
	policy_type_label.text = "NavigationRewardPolicy"
	_sync_from_policy()


func set_editable(value: bool) -> void:
	goal_reward_input.editable = value
	death_reward_input.editable = value
	blocked_reward_input.editable = value
	step_reward_input.editable = value


func _sync_from_policy() -> void:
	if not is_instance_valid(policy):
		return
	_syncing = true
	goal_reward_input.value = policy.goal_reward
	death_reward_input.value = policy.death_reward
	blocked_reward_input.value = policy.blocked_reward
	step_reward_input.value = policy.step_reward
	_syncing = false


func _on_policy_changed() -> void:
	_sync_from_policy()


func _on_goal_reward_changed(value: float) -> void:
	if not _syncing and is_instance_valid(policy):
		policy.goal_reward = value


func _on_death_reward_changed(value: float) -> void:
	if not _syncing and is_instance_valid(policy):
		policy.death_reward = value


func _on_blocked_reward_changed(value: float) -> void:
	if not _syncing and is_instance_valid(policy):
		policy.blocked_reward = value


func _on_step_reward_changed(value: float) -> void:
	if not _syncing and is_instance_valid(policy):
		policy.step_reward = value
