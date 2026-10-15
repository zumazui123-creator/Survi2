extends Resource
class_name VillageRoleDefinition

@export_group("Identity")
@export var role_id: StringName = &"farmer"
@export var display_name: String = "Bauerndorf"
@export_multiline var description: String = "Ein Dorf mit eigener Aufgabe und passenden Bewohnern."
@export var map_color: Color = Color(0.85, 0.65, 0.25, 1.0)
@export var large_village_only: bool = false

@export_group("Population")
@export_range(0, 30, 1) var minimum_residents: int = 2
@export_range(0, 30, 1) var maximum_residents: int = 4
@export var resident_actor_id: StringName = &"man"
@export_range(0, 30, 1) var minimum_pigs: int = 0
@export_range(0, 30, 1) var maximum_pigs: int = 0
@export_range(0, 10, 1) var merchant_count: int = 0

@export_group("Occupation")
@export var hostile_actor_ids: Array[StringName] = []
@export_range(0, 30, 1) var minimum_hostiles: int = 0
@export_range(0, 30, 1) var maximum_hostiles: int = 0

@export_group("Structures")
@export var wall_building_id: StringName = &"wall"
@export_range(0.0, 1.0, 0.05) var wall_density: float = 1.0
@export var feature_building_id: StringName = &""
@export_range(0, 4, 1) var feature_building_count: int = 0

@export_group("Loot")
@export var loot: Dictionary = {}


func get_resident_count(rng: RandomNumberGenerator) -> int:
	return _random_count(rng, minimum_residents, maximum_residents)


func get_pig_count(rng: RandomNumberGenerator) -> int:
	return _random_count(rng, minimum_pigs, maximum_pigs)


func get_hostile_count(rng: RandomNumberGenerator) -> int:
	if hostile_actor_ids.is_empty():
		return 0
	return _random_count(rng, minimum_hostiles, maximum_hostiles)


func get_random_hostile_actor_id(rng: RandomNumberGenerator) -> StringName:
	if hostile_actor_ids.is_empty():
		return &""
	return hostile_actor_ids[rng.randi_range(0, hostile_actor_ids.size() - 1)]


func _random_count(rng: RandomNumberGenerator, minimum: int, maximum: int) -> int:
	return rng.randi_range(mini(minimum, maximum), maxi(minimum, maximum))
