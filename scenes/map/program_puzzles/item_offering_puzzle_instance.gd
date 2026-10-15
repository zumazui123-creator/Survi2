extends RefCounted
class_name ItemOfferingPuzzleInstance

var puzzle_index: int
var definition: ItemOfferingPuzzleDefinition
var plan: LandmarkPlan
var offering_tiles: Array[Vector2i] = []
var accepted_pickups: Dictionary[int, WorldPickup] = {}
var announced_peers: Dictionary[int, bool] = {}
var next_slot: int = 0
var completed: bool = false
var visual: ItemOfferingPuzzleVisual


func _init(
		new_index: int,
		new_definition: ItemOfferingPuzzleDefinition,
		new_plan: LandmarkPlan
	) -> void:
	puzzle_index = new_index
	definition = new_definition
	plan = new_plan


func get_offering_index(tile: Vector2i) -> int:
	return offering_tiles.find(tile)
