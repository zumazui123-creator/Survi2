extends RefCounted
class_name BossTerritoryState

var definition: BossTerritoryDefinition
var plan: LandmarkPlan
var marker: BossTerritoryMarker
var approach_warning_shown: bool = false
var villager_warning_shown: bool = false
var boss_seen: bool = false
var boss_defeated: bool = false
var shake_cooldown: float = 0.0


func _init(
		new_definition: BossTerritoryDefinition,
		new_plan: LandmarkPlan
	) -> void:
	definition = new_definition
	plan = new_plan


func get_distance_to(tile: Vector2i) -> float:
	return Vector2(tile).distance_to(Vector2(plan.center_tile))
