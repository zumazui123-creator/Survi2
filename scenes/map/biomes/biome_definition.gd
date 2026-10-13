extends Resource
class_name BiomeDefinition

@export var biome_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var map_color: Color = Color.WHITE
@export var ground_atlas_coords: Array[Vector2i] = []
@export var path_atlas_coords: Array[Vector2i] = []

@export_group("Vegetation and resources")
@export_range(0.0, 1.0, 0.01) var tree_density: float = 0.0
@export var tree_object_ids: PackedStringArray = PackedStringArray()
@export var resource_object_weights: Dictionary = {}

@export_group("Environmental hazards")
@export_range(0.1, 2.0, 0.05) var movement_speed_multiplier: float = 1.0
@export_range(0.0, 10.0, 0.05) var hydration_drain_per_second: float = 0.0
@export_range(0.0, 10.0, 0.05) var damage_per_second: float = 0.0
@export var hazard_description: String


func get_random_ground_atlas(rng: RandomNumberGenerator) -> Vector2i:
	if ground_atlas_coords.is_empty():
		return Vector2i.ZERO
	return ground_atlas_coords[rng.randi_range(0, ground_atlas_coords.size() - 1)]


func get_random_path_atlas(rng: RandomNumberGenerator) -> Vector2i:
	if path_atlas_coords.is_empty():
		return get_random_ground_atlas(rng)
	return path_atlas_coords[rng.randi_range(0, path_atlas_coords.size() - 1)]


func get_valid_tree_ids() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for object_id: String in tree_object_ids:
		if Items.get_object_definition(object_id) != null:
			result.append(object_id)
	return result
