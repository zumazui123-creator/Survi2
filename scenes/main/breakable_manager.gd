extends Node2D
class_name BreakableManager

const BREAKABLE_SCENE: PackedScene = preload("res://scenes/spawn/object/breakable.tscn")
const BLOCKING_ENTITY_GROUPS: Array[StringName] = [
	&"damageable",
	&"sensor_item",
]

@export_group("References")
@export var world_map: Map

@export_group("Spawning")
@export var breakable_object_ids: PackedStringArray = PackedStringArray([
	"rock1",
	"rock2",
	"bush1",
	"magicPlant1",
	"crystal1",
	"magicRock1",
])

var initial_spawn_objects: int = Constants.INITAL_OBJECTS
var max_objects: int = Constants.MAX_OBJECTS
var object_wave_count: int = 10
var spawned_objects: int = 0


func _ready() -> void:
	_configure_for_current_level()


func spawn_objects(amount: int) -> int:
	if not multiplayer.is_server() or amount <= 0 or not is_instance_valid(world_map):
		return 0
	var available_object_ids: PackedStringArray = _get_available_object_ids()
	if available_object_ids.is_empty():
		push_warning("BreakableManager: no valid breakable object definitions")
		return 0

	var candidates: Array[Vector2i] = []
	for tile: Vector2i in world_map.spawnable_tiles:
		if world_map.is_navigation_tile_walkable(tile, true):
			candidates.append(tile)
	var spawn_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	spawn_rng.seed = Multihelper.mapSeed ^ 0x5245534F ^ spawned_objects
	_shuffle_tiles(candidates, spawn_rng)
	var blocking_entity_tiles: Dictionary[Vector2i, bool] = _collect_blocking_entity_tiles()

	var spawned_this_wave: int = 0
	for spawn_tile: Vector2i in candidates:
		if spawned_this_wave >= amount or spawned_objects >= max_objects:
			break
		var object_id: String = _pick_object_id_for_tile(
			spawn_tile,
			available_object_ids,
			spawn_rng
		)
		var breakable: NavigationBreakable = BREAKABLE_SCENE.instantiate() as NavigationBreakable
		if breakable == null:
			push_warning("BreakableManager: breakable.tscn must use NavigationBreakable")
			return spawned_this_wave
		breakable.objectId = object_id
		var occupied_tiles: Array[Vector2i] = breakable.get_navigation_tiles(spawn_tile)
		if not _can_spawn_on(occupied_tiles, blocking_entity_tiles):
			breakable.free()
			continue

		breakable.position = to_local(world_map.navigation_tile_to_world(spawn_tile))
		breakable.spawner = self
		add_child(breakable, true)
		breakable.register_navigation_blockers(occupied_tiles)
		for occupied_tile: Vector2i in occupied_tiles:
			blocking_entity_tiles[occupied_tile] = true
		spawned_objects += 1
		spawned_this_wave += 1
	return spawned_this_wave


func try_spawn_wave() -> int:
	var remaining_capacity: int = maxi(max_objects - spawned_objects, 0)
	return spawn_objects(mini(object_wave_count, remaining_capacity))


func configure_limits(initial_amount: int, maximum_amount: int) -> void:
	initial_spawn_objects = maxi(initial_amount, 0)
	max_objects = maxi(maximum_amount, 0)
	spawned_objects = mini(spawned_objects, max_objects)


func clear_breakables() -> void:
	for child: Node in get_children():
		if child is NavigationBreakable:
			remove_child(child)
			child.queue_free()
	spawned_objects = 0


func notify_breakable_removed() -> void:
	spawned_objects = maxi(spawned_objects - 1, 0)


func _can_spawn_on(
		occupied_tiles: Array[Vector2i],
		blocking_entity_tiles: Dictionary[Vector2i, bool]
	) -> bool:
	for occupied_tile: Vector2i in occupied_tiles:
		if blocking_entity_tiles.has(occupied_tile):
			return false
		if not world_map.is_navigation_tile_walkable(occupied_tile, true):
			return false
	return true


func _collect_blocking_entity_tiles() -> Dictionary[Vector2i, bool]:
	var result: Dictionary[Vector2i, bool] = {}
	for group_name: StringName in BLOCKING_ENTITY_GROUPS:
		for candidate: Node in get_tree().get_nodes_in_group(group_name):
			var entity: Node2D = candidate as Node2D
			if entity == null or entity.is_queued_for_deletion():
				continue
			result[world_map.world_to_navigation_tile(entity.global_position)] = true
	return result


func _get_available_object_ids() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for object_id: String in breakable_object_ids:
		if Items.get_object_definition(object_id) != null:
			result.append(object_id)
		else:
			push_warning("BreakableManager: unknown object definition '%s'" % object_id)
	return result


func _pick_object_id_for_tile(
		tile: Vector2i,
		fallback_ids: PackedStringArray,
		rng: RandomNumberGenerator
	) -> String:
	var definition: BiomeDefinition = world_map.get_biome_definition_at(tile)
	if definition != null and not definition.resource_object_weights.is_empty():
		var valid_weights: Dictionary[String, float] = {}
		var total_weight: float = 0.0
		for object_id_value: Variant in definition.resource_object_weights:
			var object_id: String = String(object_id_value)
			var weight: float = maxf(
				float(definition.resource_object_weights[object_id_value]),
				0.0
			)
			if weight <= 0.0 or Items.get_object_definition(object_id) == null:
				continue
			valid_weights[object_id] = weight
			total_weight += weight
		if total_weight > 0.0:
			var selection: float = rng.randf() * total_weight
			for object_id: String in valid_weights:
				selection -= valid_weights[object_id]
				if selection <= 0.0:
					return object_id

	var fallback_index: int = rng.randi_range(0, fallback_ids.size() - 1)
	return fallback_ids[fallback_index]


func _shuffle_tiles(
		tiles: Array[Vector2i],
		rng: RandomNumberGenerator
	) -> void:
	for index: int in range(tiles.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var previous_tile: Vector2i = tiles[index]
		tiles[index] = tiles[swap_index]
		tiles[swap_index] = previous_tile


func _configure_for_current_level() -> void:
	if not Multihelper.level or not "size" in Multihelper.level:
		return
	var map_size: Vector2i = Multihelper.level["size"]
	var default_area: float = float(Constants.MAP_SIZE.x * Constants.MAP_SIZE.y)
	var level_area: float = float(map_size.x * map_size.y)
	var scale_factor: float = sqrt(level_area) / sqrt(default_area)
	max_objects = int(float(Constants.MAX_OBJECTS) * scale_factor)
	object_wave_count = maxi(1, int(float(object_wave_count) * scale_factor))
