extends RefCounted
class_name ArrowGauntletPuzzleInstance

var puzzle_index: int
var definition: ArrowGauntletPuzzleDefinition
var plan: LandmarkPlan
var start_tile: Vector2i
var treasure_tile: Vector2i
var barrier_tiles: Array[Vector2i] = []
var visual: ArrowGauntletPuzzleVisual
var announced_peers: Dictionary[int, bool] = {}
var volley_remaining: float = 0.0
var volley_index: int = 0
var treasure_claimed: bool = false


func _init(
		new_index: int,
		new_definition: ArrowGauntletPuzzleDefinition,
		new_plan: LandmarkPlan
	) -> void:
	puzzle_index = new_index
	definition = new_definition
	plan = new_plan
	start_tile = plan.center_tile + definition.start_offset
	treasure_tile = plan.center_tile + definition.treasure_offset
	volley_remaining = definition.volley_interval_seconds


func is_player_near(tile: Vector2i) -> bool:
	return Vector2(tile).distance_to(Vector2(plan.center_tile)) \
		<= float(definition.activation_radius_tiles)
