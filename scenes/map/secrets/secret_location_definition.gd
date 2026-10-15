extends Resource
class_name SecretLocationDefinition

enum AccessType {
	OPEN,
	TREE_COVER,
	DESTRUCTIBLE_WALL,
	TELEPORT,
	JUMP,
}

enum TerrainStyle {
	LAND,
	ISLAND,
	CHAMBER,
	GAP,
	PASSAGE,
}

@export_group("Identity")
@export var secret_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var location_type: StringName = &"secret"
@export var map_color: Color = Color(0.35, 0.9, 0.95, 1.0)

@export_group("Generation")
@export var size_tiles: Vector2i = Vector2i(7, 7)
@export_range(1, 5, 1) var minimum_instances: int = 1
@export_range(1, 5, 1) var maximum_instances: int = 1
@export_range(1, 200, 1) var generation_priority: int = 50
@export_range(1, 5000, 1) var placement_attempts: int = 1000
@export_range(2, 32, 1) var edge_margin_tiles: int = 8
@export_range(0, 32, 1) var spacing_tiles: int = 5
@export var allowed_biomes: Array[StringName] = []
@export var terrain_style: TerrainStyle = TerrainStyle.LAND

@export_group("Discovery and access")
@export var sensor_only: bool = false
@export_range(1, 12, 1) var reveal_distance_tiles: int = 2
@export var access_type: AccessType = AccessType.OPEN
@export var barrier_building_id: StringName = &"wall"
@export var boundary_building_id: StringName = &""

@export_group("Reward")
@export var loot: Dictionary = {}


func get_normalized_size() -> Vector2i:
	return Vector2i(maxi(size_tiles.x, 5), maxi(size_tiles.y, 5))


func get_instance_count(rng: RandomNumberGenerator) -> int:
	var minimum: int = mini(minimum_instances, maximum_instances)
	var maximum: int = maxi(minimum_instances, maximum_instances)
	return rng.randi_range(minimum, maximum)
