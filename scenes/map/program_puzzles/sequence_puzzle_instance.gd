extends RefCounted
class_name SequencePuzzleInstance

var puzzle_index: int
var definition: SequencePuzzleDefinition
var plan: LandmarkPlan
var switch_tiles: Array[Vector2i] = []
var switch_numbers: Array[int] = []
var switch_visuals: Array[ProgramPuzzleSwitch] = []
var announced_peers: Dictionary[int, bool] = {}
var active_peer_id: int = -1
var next_number: int = 1
var time_remaining: float = 0.0
var last_displayed_second: int = -1
var completed: bool = false


func _init(
		new_index: int,
		new_definition: SequencePuzzleDefinition,
		new_plan: LandmarkPlan
	) -> void:
	puzzle_index = new_index
	definition = new_definition
	plan = new_plan


func get_switch_index(tile: Vector2i) -> int:
	return switch_tiles.find(tile)


func reset_progress() -> void:
	active_peer_id = -1
	next_number = 1
	time_remaining = 0.0
	last_displayed_second = -1
