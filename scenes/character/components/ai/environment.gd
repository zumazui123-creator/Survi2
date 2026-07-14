extends Node

# --- Grid config ---
@export var grid_width := 5
@export var grid_height := 5

# --- Rewards ---
@export var reward_goal := 10.0
@export var reward_step := -1.0
@export var reward_wall := -10.0

# --- State ---
var agent_pos: Vector2i
var goal_pos: Vector2i

# Optional: Walls
var walls := []  # Array[Vector2i]

# --- Public API ---

func reset() -> Array:
	agent_pos = Vector2i(
		randi() % grid_width,
		randi() % grid_height
	)

	goal_pos = Vector2i(
		randi() % grid_width,
		randi() % grid_height
	)

	# Ziel darf nicht auf Agent liegen
	while goal_pos == agent_pos:
		goal_pos = Vector2i(
			randi() % grid_width,
			randi() % grid_height
		)

	return get_state()


func step(action: int) -> Dictionary:
	var reward := reward_step
	var done := false

	var direction := action_to_dir(action)
	var next_pos := agent_pos + direction

	# --- Wand / Grenze ---
	if not is_inside(next_pos) or next_pos in walls:
		reward = reward_wall
	else:
		agent_pos = next_pos

	# --- Ziel erreicht ---
	if agent_pos == goal_pos:
		reward = reward_goal
		done = true

	return {
		"state": get_state(),
		"reward": reward,
		"done": done
	}


# --- Helpers ---

func get_state() -> Array:
	# Diskreter, einfacher State
	return [
		agent_pos.x,
		agent_pos.y,
		goal_pos.x,
		goal_pos.y
	]


func action_to_dir(action: int) -> Vector2i:
	match action:
		0: return Vector2i.UP
		1: return Vector2i.DOWN
		2: return Vector2i.LEFT
		3: return Vector2i.RIGHT
		_: return Vector2i.ZERO


func is_inside(pos: Vector2i) -> bool:
	return (
		pos.x >= 0 and
		pos.y >= 0 and
		pos.x < grid_width and
		pos.y < grid_height
	)
