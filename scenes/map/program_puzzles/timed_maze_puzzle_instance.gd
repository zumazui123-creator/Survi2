extends RefCounted
class_name TimedMazePuzzleInstance

var puzzle_index: int
var definition: TimedMazePuzzleDefinition
var plan: LandmarkPlan
var wall_tiles: Array[Vector2i] = []
var start_tile: Vector2i
var goal_tile: Vector2i
var visual: TimedMazePuzzleVisual
var announced_peers: Dictionary[int, bool] = {}
var active_peer_id: int = -1
var time_remaining: float = 0.0
var last_displayed_second: int = -1
var completed: bool = false


func _init(
		new_index: int,
		new_definition: TimedMazePuzzleDefinition,
		new_plan: LandmarkPlan
	) -> void:
	puzzle_index = new_index
	definition = new_definition
	plan = new_plan


func reset_attempt() -> void:
	active_peer_id = -1
	time_remaining = 0.0
	last_displayed_second = -1
