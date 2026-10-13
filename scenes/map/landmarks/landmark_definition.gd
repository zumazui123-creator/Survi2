extends Resource
class_name LandmarkDefinition

enum Category {
	COMMON,
	RARE,
	UNIQUE,
}

@export var landmark_id: StringName
@export var display_name: String
@export_multiline var description: String
@export_multiline var danger_description: String
@export_multiline var reward_description: String
@export var size_tiles: Vector2i = Vector2i(7, 7)
@export_range(1, 32, 1) var edge_margin_tiles: int = 6
@export_range(0, 64, 1) var spacing_tiles: int = 5
@export_range(1, 5000, 1) var placement_attempts: int = 800
@export_group("Generation")
@export var category: Category = Category.COMMON
@export_range(1, 8, 1) var minimum_instances: int = 1
@export_range(1, 8, 1) var maximum_instances: int = 1
@export_range(0, 200, 1) var generation_priority: int = 50
@export_group("Presentation and content")
@export var map_color: Color = Color(0.6, 0.6, 0.6, 1.0)
@export var loot: Dictionary = {}
@export var enemy_spawns: Dictionary = {}
@export var structure_style: StringName = &"none"
@export var boss_actor_id: StringName = &""
@export_group("Hazards")
@export var hazard_building_id: StringName = &""
@export var hazard_offsets: Array[Vector2i] = []
@export_group("Special behavior")
@export var is_bridge: bool = false
@export var is_golem_temple: bool = false
@export var is_forest_arena: bool = false
@export var spawn_merchant: bool = false
@export_range(0, 12, 1) var nocturnal_enemy_count: int = 0
@export_group("Biome placement")
@export var allowed_biomes: Array[StringName] = []
@export_range(0, 16, 1) var biome_border_margin_tiles: int = 0


func get_normalized_size() -> Vector2i:
	return Vector2i(maxi(size_tiles.x, 1), maxi(size_tiles.y, 1))


func get_instance_count(rng: RandomNumberGenerator) -> int:
	if category == Category.UNIQUE:
		return 1
	var minimum: int = maxi(minimum_instances, 1)
	var maximum: int = maxi(maximum_instances, minimum)
	return rng.randi_range(minimum, maximum)
