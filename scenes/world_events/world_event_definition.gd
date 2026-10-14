extends Resource
class_name WorldEventDefinition

enum Activation {
	MAP_START,
	NIGHT,
}

enum Placement {
	WORLD,
	VILLAGE_INTERIOR,
	VILLAGE_OUTSIDE,
}

enum FriendlyRole {
	NONE,
	MERCHANT,
	ESCAPED_PIG,
	CARAVAN,
}

enum TargetRole {
	PLAYERS,
	VILLAGE_RESIDENT,
	SPAWNED_FRIENDLY,
}

@export var event_id: StringName
@export var display_name: String
@export_multiline var description: String
@export_range(0.0, 1.0, 0.05) var spawn_probability: float = 0.65
@export var always_plan: bool = false
@export var activation: Activation = Activation.MAP_START
@export var placement: Placement = Placement.WORLD
@export_range(0, 12, 1) var reservation_radius_tiles: int = 3
@export var marker_style: StringName
@export var marker_color: Color = Color(1.0, 0.75, 0.2, 1.0)
@export var glowing: bool = false
@export var friendly_role: FriendlyRole = FriendlyRole.NONE
@export var navigation_required: bool = false
@export var deliver_loot_at_destination: bool = false
@export var target_role: TargetRole = TargetRole.PLAYERS
@export var retarget_village_residents: bool = false
@export var hostile_actor_id: StringName
@export_range(0, 20, 1) var minimum_hostiles: int = 0
@export_range(0, 20, 1) var maximum_hostiles: int = 0
@export var loot: Dictionary = {}
@export var map_color: Color = Color(1.0, 0.72, 0.15, 1.0)


func get_hostile_count(rng: RandomNumberGenerator) -> int:
	var minimum: int = mini(minimum_hostiles, maximum_hostiles)
	var maximum: int = maxi(minimum_hostiles, maximum_hostiles)
	return rng.randi_range(minimum, maximum)
