extends RefCounted
class_name BridgeRepairPuzzleInstance

var puzzle_index: int
var definition: BridgeRepairPuzzleDefinition
var plan: LandmarkPlan
var bridge_tiles: Array[Vector2i] = []
var gap_tiles: Array[Vector2i] = []
var repaired_tiles: Dictionary[Vector2i, bool] = {}
var treasure_tile: Vector2i
var source_id: StringName
var visual: BridgeRepairPuzzleVisual
var announced_peers: Dictionary[int, bool] = {}
var bridge_repaired: bool = false
var treasure_claimed: bool = false


func _init(
		new_index: int,
		new_definition: BridgeRepairPuzzleDefinition,
		new_plan: LandmarkPlan
	) -> void:
	puzzle_index = new_index
	definition = new_definition
	plan = new_plan
	source_id = StringName("bridge_puzzle:%d:%d" % [
		plan.center_tile.x,
		plan.center_tile.y,
	])


func is_gap_tile(tile: Vector2i) -> bool:
	return tile in gap_tiles


func is_repaired(tile: Vector2i) -> bool:
	return repaired_tiles.has(tile)


func get_repaired_count() -> int:
	return repaired_tiles.size()
