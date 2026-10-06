extends Resource
class_name NavigationRewardPolicy

@export var goal_reward: float = 10.0:
	set(value):
		goal_reward = value
		emit_changed()

@export var death_reward: float = -10.0:
	set(value):
		death_reward = value
		emit_changed()

@export var blocked_reward: float = -0.2:
	set(value):
		blocked_reward = value
		emit_changed()

@export var step_reward: float = -0.01:
	set(value):
		step_reward = value
		emit_changed()


func calculate(movement_succeeded: bool, goal_reached: bool, player_died: bool) -> float:
	if player_died:
		return death_reward
	if goal_reached:
		return goal_reward
	if not movement_succeeded:
		return blocked_reward
	return step_reward
