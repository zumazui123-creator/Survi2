extends Resource
class_name VillageDefinition

@export_group("Amount and placement")
@export_range(0, 50, 1) var minimum_villages: int = 10
@export_range(0, 50, 1) var maximum_villages: int = 12
@export_range(1, 64, 1) var map_edge_margin_tiles: int = 8
@export_range(0, 64, 1) var village_spacing_tiles: int = 8
@export_range(1, 2000, 1) var placement_attempts_per_village: int = 600

@export_group("Village size")
@export var minimum_size_tiles: Vector2i = Vector2i(7, 7)
@export var maximum_size_tiles: Vector2i = Vector2i(11, 11)

@export_group("Population")
@export_range(0, 30, 1) var minimum_residents: int = 2
@export_range(0, 30, 1) var maximum_residents: int = 4
@export_range(0, 30, 1) var minimum_pigs: int = 2
@export_range(0, 30, 1) var maximum_pigs: int = 5

@export_group("Large village")
@export var generate_large_village: bool = true
@export var large_village_size_tiles: Vector2i = Vector2i(15, 15)
@export_range(0, 50, 1) var large_minimum_residents: int = 7
@export_range(0, 50, 1) var large_maximum_residents: int = 10
@export_range(0, 50, 1) var large_minimum_pigs: int = 4
@export_range(0, 50, 1) var large_maximum_pigs: int = 7
@export var large_village_loot: Dictionary = {
	"crystalShard": 3,
	"energy_drink": 2,
	"magicAxe1": 1,
	"magicSpear1": 1,
	"magicSword1": 1,
}

@export_group("Buildings")
@export var wall_building_id: StringName = &"wall"


func get_village_count(rng: RandomNumberGenerator) -> int:
	var lower: int = mini(minimum_villages, maximum_villages)
	var upper: int = maxi(minimum_villages, maximum_villages)
	return rng.randi_range(lower, upper)


func get_random_size(rng: RandomNumberGenerator, is_large: bool = false) -> Vector2i:
	if is_large:
		return _normalize_size(large_village_size_tiles)
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


func get_minimum_size(is_large: bool = false) -> Vector2i:
	if is_large:
		return _normalize_size(large_village_size_tiles)
	return _normalize_size(Vector2i(
		mini(minimum_size_tiles.x, maximum_size_tiles.x),
		mini(minimum_size_tiles.y, maximum_size_tiles.y)
	))


func get_resident_count(rng: RandomNumberGenerator, is_large: bool = false) -> int:
	if is_large:
		return rng.randi_range(
			mini(large_minimum_residents, large_maximum_residents),
			maxi(large_minimum_residents, large_maximum_residents)
		)
	return rng.randi_range(
		mini(minimum_residents, maximum_residents),
		maxi(minimum_residents, maximum_residents)
	)


func get_pig_count(rng: RandomNumberGenerator, is_large: bool = false) -> int:
	if is_large:
		return rng.randi_range(
			mini(large_minimum_pigs, large_maximum_pigs),
			maxi(large_minimum_pigs, large_maximum_pigs)
		)
	return rng.randi_range(
		mini(minimum_pigs, maximum_pigs),
		maxi(minimum_pigs, maximum_pigs)
	)


func _make_odd(value: int) -> int:
	return value if value % 2 == 1 else value + 1


func _normalize_size(value: Vector2i) -> Vector2i:
	return Vector2i(
		_make_odd(maxi(value.x, 5)),
		_make_odd(maxi(value.y, 5))
	)
