extends Resource
class_name NavigationRewardPolicy

@export var goal_reward := 10.0
@export var death_reward := -10.0
@export var blocked_reward := -0.2
@export var step_reward := -0.01


func calculate(movement_succeeded: bool, goal_reached: bool, player_died: bool) -> float:
	if player_died:
		return death_reward
	if goal_reached:
		return goal_reward
	if not movement_succeeded:
		return blocked_reward
	return step_reward
