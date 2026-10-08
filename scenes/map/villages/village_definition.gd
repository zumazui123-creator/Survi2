extends Resource
class_name VillageDefinition

@export_group("Amount and placement")
@export_range(0, 20, 1) var minimum_villages: int = 1
@export_range(0, 20, 1) var maximum_villages: int = 3
@export_range(1, 64, 1) var map_edge_margin_tiles: int = 8
@export_range(0, 64, 1) var village_spacing_tiles: int = 8
@export_range(1, 500, 1) var placement_attempts_per_village: int = 80

@export_group("Village size")
@export var minimum_size_tiles: Vector2i = Vector2i(7, 7)
@export var maximum_size_tiles: Vector2i = Vector2i(11, 11)

@export_group("Population")
@export_range(0, 30, 1) var minimum_residents: int = 2
@export_range(0, 30, 1) var maximum_residents: int = 4
@export_range(0, 30, 1) var minimum_pigs: int = 2
@export_range(0, 30, 1) var maximum_pigs: int = 5

@export_group("Buildings")
@export var wall_building_id: StringName = &"wall"


func get_village_count(rng: RandomNumberGenerator) -> int:
	var lower: int = mini(minimum_villages, maximum_villages)
	var upper: int = maxi(minimum_villages, maximum_villages)
	return rng.randi_range(lower, upper)


func get_random_size(rng: RandomNumberGenerator) -> Vector2i:
	var minimum: Vector2i = Vector2i(
		mini(minimum_size_tiles.x, maximum_size_tiles.x),
		mini(minimum_size_tiles.y, maximum_size_tiles.y)
	)
	var maximum: Vector2i = Vector2i(
		maxi(minimum_size_tiles.x, maximum_size_tiles.x),
		maxi(minimum_size_tiles.y, maximum_size_tiles.y)
	)
	return Vector2i(
		_make_odd(rng.randi_range(maxi(minimum.x, 5), maxi(maximum.x, 5))),
		_make_odd(rng.randi_range(maxi(minimum.y, 5), maxi(maximum.y, 5)))
	)


func get_resident_count(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(
		mini(minimum_residents, maximum_residents),
		maxi(minimum_residents, maximum_residents)
	)


func get_pig_count(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(
		mini(minimum_pigs, maximum_pigs),
		maxi(minimum_pigs, maximum_pigs)
	)


func _make_odd(value: int) -> int:
	return value if value % 2 == 1 else value + 1
