extends Node
class_name PlayerSensor

signal scan_completed(observation: Dictionary)
signal radius_changed(radius: int)
signal visualization_changed(enabled: bool)

const CHANNEL_VISIBLE: int = 0
const CHANNEL_WALKABLE: int = 1
const CHANNEL_WATER: int = 2
const CHANNEL_OBJECT: int = 3
const CHANNEL_ITEM: int = 4
const CHANNEL_ANIMAL: int = 5
const CHANNEL_ENEMY: int = 6
const CHANNEL_GOAL: int = 7
const CHANNEL_COUNT: int = 8
## Observation stats are normalized to [0, 1] in this stable order.
const STAT_HP: int = 0
const STAT_HYDRATION: int = 1
const STAT_FOOD: int = 2
const STAT_MANA: int = 3
const STAT_COUNT: int = 4
const MAX_INVENTORY_ITEM_COUNT: float = 999.0

const GROUP_OBJECT: StringName = &"sensor_object"
const GROUP_ITEM: StringName = &"sensor_item"
const GROUP_ANIMAL: StringName = &"sensor_animal"
const GROUP_ENEMY: StringName = &"sensor_enemy"

const ACTION_DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.RIGHT,
]

@export_group("References")
@export var player: CharacterBody2D
@export var movement: PlayerMovement
@export var stats: PlayerStats
@export var debug_view: SensorDebugView

@export_group("Sensor")
@export_range(1, 64, 1) var scan_radius_tiles: int = 10:
	set(value):
		var new_radius: int = clampi(value, 1, 64)
		if scan_radius_tiles == new_radius:
			return
		scan_radius_tiles = new_radius
		if is_instance_valid(debug_view):
			debug_view.set_radius(scan_radius_tiles)
		radius_changed.emit(scan_radius_tiles)
@export_range(0.05, 2.0, 0.05) var visualization_scan_interval: float = 0.25

@onready var world_map: Map = get_tree().get_first_node_in_group("world_map")
@onready var tree_manager: TreeManager = get_tree().get_first_node_in_group("tree_manager")

var last_observation: Dictionary = {}
var visualization_enabled: bool = false
var _visualization_elapsed: float = 0.0
var _detected_entities: Dictionary = {}
var _highlighted_entities: Dictionary = {}
var _detected_tree_tiles: Dictionary[Vector2i, bool] = {}
var _highlighted_tree_tiles: Dictionary[Vector2i, bool] = {}


func _ready() -> void:
	if is_instance_valid(debug_view):
		debug_view.set_radius(scan_radius_tiles)
		debug_view.set_visualization_enabled(false)
	set_process(false)


func _process(delta: float) -> void:
	if not visualization_enabled or not is_instance_valid(player) \
			or not player.is_multiplayer_authority():
		return
	_visualization_elapsed += delta
	if _visualization_elapsed >= visualization_scan_interval:
		_visualization_elapsed = 0.0
		scan()
	_apply_highlight_pulse()


## Returns the fixed-size observation consumed directly by the AI environment.
## local_map is a flattened CHANNEL_COUNT x side x side byte tensor.
func scan() -> Dictionary:
	if visualization_enabled:
		_detected_entities.clear()
		_detected_tree_tiles.clear()
	var observation: Dictionary = _create_empty_observation()
	if is_ready_to_scan():
		var origin_tile: Vector2i = get_origin_tile()
		var local_map: PackedByteArray = observation["local_map"]
		_fill_terrain_layers(local_map, origin_tile)
		_mark_tree_data(local_map, origin_tile)
		_mark_entity_group(local_map, GROUP_OBJECT, CHANNEL_OBJECT, origin_tile, true)
		_mark_entity_group(local_map, GROUP_ITEM, CHANNEL_ITEM, origin_tile, false)
		_mark_entity_group(local_map, GROUP_ANIMAL, CHANNEL_ANIMAL, origin_tile, false)
		_mark_entity_group(local_map, GROUP_ENEMY, CHANNEL_ENEMY, origin_tile, false)
		observation["local_map"] = local_map
		observation["stats"] = _scan_stats()
		observation["inventory"] = _scan_inventory()
		observation["equipped_item"] = _scan_equipped_item()
		observation["goal_delta"] = _scan_goal_delta(origin_tile)
		observation["action_mask"] = _scan_action_mask(origin_tile)

	last_observation = observation
	if visualization_enabled:
		_sync_highlights()
	scan_completed.emit(observation)
	return observation


func set_scan_radius(value: int) -> void:
	scan_radius_tiles = value


func set_visualization_enabled(value: bool) -> void:
	if visualization_enabled == value:
		return
	visualization_enabled = value
	_visualization_elapsed = visualization_scan_interval
	if is_instance_valid(debug_view):
		debug_view.set_radius(scan_radius_tiles)
		debug_view.set_visualization_enabled(value)
	set_process(value)
	if value:
		scan()
	else:
		_clear_highlights()
	visualization_changed.emit(value)


func is_visualization_enabled() -> bool:
	return visualization_enabled


func get_origin_tile() -> Vector2i:
	if is_instance_valid(movement):
		return movement.current_map_position
	if is_instance_valid(world_map) and is_instance_valid(player):
		return world_map.world_to_navigation_tile(player.global_position)
	return Vector2i.ZERO


func get_map_side_length() -> int:
	return scan_radius_tiles * 2 + 1


func get_observation_shape() -> PackedInt32Array:
	var side: int = get_map_side_length()
	return PackedInt32Array([CHANNEL_COUNT, side, side])


func get_local_map_value_count() -> int:
	var side: int = get_map_side_length()
	return CHANNEL_COUNT * side * side


func get_inventory_observation_shape() -> PackedInt32Array:
	return PackedInt32Array([Items.ITEM_DEFINITIONS.size()])


func is_ready_to_scan() -> bool:
	return is_instance_valid(player) \
		and is_instance_valid(movement) \
		and is_instance_valid(world_map) \
		and is_instance_valid(world_map.tile_map)


## Evaluates one adjacent code-editor condition through the same TileMap-based data
## that is exported in scan().
func matches_code_condition(subject: StringName, direction_action: StringName) -> bool:
	if not is_ready_to_scan() or not Strings.direction_map.has(String(direction_action)):
		return false

	var direction: Vector2i = Strings.direction_map[String(direction_action)]
	var target_tile: Vector2i = get_origin_tile() + direction
	if subject == Strings.CONDITION_FREE:
		return world_map.is_navigation_tile_walkable(target_tile, true, player.get_instance_id())

	var channel: int = _get_code_condition_channel(subject)
	if channel < 0:
		return false

	var observation: Dictionary = scan()
	var local_map: PackedByteArray = observation["local_map"]
	return _has_channel_at_offset(local_map, channel, direction)


## Compares the Manhattan distance to the nearest visible matching TileMap cell.
## A missing target is unknown rather than infinitely far away, so every comparison
## returns false when the sensor cannot currently see a matching cell.
func matches_code_distance_condition(
		subject: StringName,
		comparison_operator: StringName,
		distance_tiles: int
	) -> bool:
	if not is_ready_to_scan() or distance_tiles < 0:
		return false

	var nearest_distance: int = get_nearest_code_condition_distance(subject)
	if nearest_distance < 0:
		return false

	match comparison_operator:
		Strings.CONDITION_COMPARISON_LESS:
			return nearest_distance < distance_tiles
		Strings.CONDITION_COMPARISON_GREATER:
			return nearest_distance > distance_tiles
		Strings.CONDITION_COMPARISON_EQUAL:
			return nearest_distance == distance_tiles
	return false


func get_nearest_code_condition_distance(subject: StringName) -> int:
	var channel: int = CHANNEL_WALKABLE if subject == Strings.CONDITION_FREE \
		else _get_code_condition_channel(subject)
	if channel < 0:
		return -1

	var observation: Dictionary = scan()
	var local_map: PackedByteArray = observation["local_map"]
	var nearest_distance: int = -1
	for relative_y: int in range(-scan_radius_tiles, scan_radius_tiles + 1):
		for relative_x: int in range(-scan_radius_tiles, scan_radius_tiles + 1):
			var relative_tile: Vector2i = Vector2i(relative_x, relative_y)
			var tile_distance: int = absi(relative_x) + absi(relative_y)
			if tile_distance > scan_radius_tiles:
				continue
			if subject == Strings.CONDITION_FREE and tile_distance == 0:
				continue
			if not _has_channel_at_offset(local_map, channel, relative_tile):
				continue
			if nearest_distance < 0 or tile_distance < nearest_distance:
				nearest_distance = tile_distance
	return nearest_distance


## Checks the actual TileMap cell under a world-space point. Player interactions
## use this instead of depending on rendered water nodes.
func is_water_at_world_position(world_position: Vector2) -> bool:
	if not is_ready_to_scan():
		return false
	var tile: Vector2i = world_map.world_to_navigation_tile(world_position)
	return _is_water_tile(tile)


func _get_code_condition_channel(subject: StringName) -> int:
	match subject:
		Strings.CONDITION_OBJECT:
			return CHANNEL_OBJECT
		Strings.CONDITION_ITEM:
			return CHANNEL_ITEM
		Strings.CONDITION_ANIMAL:
			return CHANNEL_ANIMAL
		Strings.CONDITION_ENEMY:
			return CHANNEL_ENEMY
		Strings.CONDITION_WATER:
			return CHANNEL_WATER
		Strings.CONDITION_GOAL:
			return CHANNEL_GOAL
	return -1


func _has_channel_at_offset(
		local_map: PackedByteArray,
		channel: int,
		relative_tile: Vector2i
	) -> bool:
	if channel < 0 or channel >= CHANNEL_COUNT or not _is_visible_offset(relative_tile):
		return false
	var side: int = get_map_side_length()
	var local_x: int = relative_tile.x + scan_radius_tiles
	var local_y: int = relative_tile.y + scan_radius_tiles
	var index: int = channel * side * side + local_y * side + local_x
	return index >= 0 and index < local_map.size() and local_map[index] != 0


func _create_empty_observation() -> Dictionary:
	var local_map: PackedByteArray = PackedByteArray()
	local_map.resize(get_local_map_value_count())
	var stat_values: PackedFloat32Array = PackedFloat32Array()
	stat_values.resize(STAT_COUNT)
	var inventory: PackedFloat32Array = PackedFloat32Array()
	inventory.resize(Items.ITEM_DEFINITIONS.size())
	var equipped_item: PackedByteArray = PackedByteArray()
	equipped_item.resize(Items.ITEM_DEFINITIONS.size())
	var goal_delta: PackedFloat32Array = PackedFloat32Array()
	goal_delta.resize(2)
	var action_mask: PackedByteArray = PackedByteArray()
	action_mask.resize(ACTION_DIRECTIONS.size())
	return {
		"local_map": local_map,
		"stats": stat_values,
		"inventory": inventory,
		"equipped_item": equipped_item,
		"goal_delta": goal_delta,
		"action_mask": action_mask,
	}


func _fill_terrain_layers(local_map: PackedByteArray, origin_tile: Vector2i) -> void:
	for y_offset in range(-scan_radius_tiles, scan_radius_tiles + 1):
		for x_offset in range(-scan_radius_tiles, scan_radius_tiles + 1):
			var relative_tile: Vector2i = Vector2i(x_offset, y_offset)
			if not _is_visible_offset(relative_tile):
				continue

			var tile: Vector2i = origin_tile + relative_tile
			_set_channel(local_map, CHANNEL_VISIBLE, relative_tile)
			if world_map.is_navigation_tile_walkable(tile):
				_set_channel(local_map, CHANNEL_WALKABLE, relative_tile)
			if _is_water_tile(tile):
				_set_channel(local_map, CHANNEL_WATER, relative_tile)
			if _has_navigation_goal() and tile == world_map.endPosition:
				_set_channel(local_map, CHANNEL_GOAL, relative_tile)


func _mark_entity_group(
		local_map: PackedByteArray,
		group: StringName,
		channel: int,
		origin_tile: Vector2i,
		include_footprint: bool
	) -> void:
	for candidate in get_tree().get_nodes_in_group(group):
		var entity: Node2D = candidate as Node2D
		if not is_instance_valid(entity) or entity == player or entity.is_queued_for_deletion():
			continue
		if entity is TreeEntity:
			continue

		var anchor_tile: Vector2i = world_map.world_to_navigation_tile(entity.global_position)
		var occupied_tiles: Array[Vector2i] = [anchor_tile]
		if include_footprint and entity.has_method("get_navigation_tiles"):
			occupied_tiles = _to_tile_array(entity.call("get_navigation_tiles", anchor_tile))
		var detected: bool = false
		for tile in occupied_tiles:
			var relative_tile: Vector2i = tile - origin_tile
			_set_channel(local_map, channel, relative_tile)
			detected = detected or _is_visible_offset(relative_tile)
		if detected and visualization_enabled:
			_detected_entities[entity] = true


func _mark_tree_data(local_map: PackedByteArray, origin_tile: Vector2i) -> void:
	if not is_instance_valid(tree_manager):
		tree_manager = get_tree().get_first_node_in_group("tree_manager") as TreeManager
	if not is_instance_valid(tree_manager):
		return
	for state: TreeState in tree_manager.get_trees_in_radius(origin_tile, scan_radius_tiles):
		var relative_tile: Vector2i = state.tile - origin_tile
		_set_channel(local_map, CHANNEL_OBJECT, relative_tile)
		if not visualization_enabled:
			continue
		_detected_tree_tiles[state.tile] = true
		if is_instance_valid(state.active_node):
			_detected_entities[state.active_node] = true


func _scan_stats() -> PackedFloat32Array:
	var result: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	if not is_instance_valid(stats):
		return result
	result[STAT_HP] = clampf(stats.hp / maxf(stats.max_hp, 1.0), 0.0, 1.0)
	result[STAT_HYDRATION] = clampf(stats.hydration / 100.0, 0.0, 1.0)
	result[STAT_FOOD] = clampf(stats.food / 100.0, 0.0, 1.0)
	result[STAT_MANA] = clampf(stats.mana / maxf(stats.max_mana, 1.0), 0.0, 1.0)
	return result


## Inventory indexes match Items.ITEM_DEFINITIONS. Counts are clamped only to
## keep the observation space bounded; the inventory data itself is unchanged.
func _scan_inventory() -> PackedFloat32Array:
	var result: PackedFloat32Array = PackedFloat32Array()
	result.resize(Items.ITEM_DEFINITIONS.size())
	if not is_instance_valid(player):
		return result

	var inventory: Dictionary = Inventory.getItems(str(player.name))
	for item_index: int in range(Items.ITEM_DEFINITIONS.size()):
		var definition: ItemDefinition = Items.ITEM_DEFINITIONS[item_index]
		var item_id: String = String(definition.item_id)
		result[item_index] = clampf(float(inventory.get(item_id, 0)), 0.0, MAX_INVENTORY_ITEM_COUNT)
	return result


func _scan_equipped_item() -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray()
	result.resize(Items.ITEM_DEFINITIONS.size())
	if not is_instance_valid(player) or not is_instance_valid(player.items):
		return result

	var equipped_item_id: String = player.items.equippedItem
	if equipped_item_id.is_empty():
		return result
	for item_index: int in range(Items.ITEM_DEFINITIONS.size()):
		var definition: ItemDefinition = Items.ITEM_DEFINITIONS[item_index]
		if String(definition.item_id) == equipped_item_id:
			result[item_index] = 1
			break
	return result


func _scan_goal_delta(origin_tile: Vector2i) -> PackedFloat32Array:
	var result: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])
	if not _has_navigation_goal():
		return result
	var delta: Vector2i = world_map.endPosition - origin_tile
	result[0] = float(delta.x)
	result[1] = float(delta.y)
	return result


func _scan_action_mask(origin_tile: Vector2i) -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray()
	result.resize(ACTION_DIRECTIONS.size())
	for action in range(ACTION_DIRECTIONS.size()):
		var target_tile: Vector2i = origin_tile + ACTION_DIRECTIONS[action]
		result[action] = 1 if world_map.is_navigation_tile_walkable(target_tile) else 0
	return result


func _is_water_tile(tile: Vector2i) -> bool:
	if world_map.tile_map.get_cell_source_id(tile) < 0:
		return false
	return world_map.tile_map.get_cell_atlas_coords(tile) in world_map.waterCoors


func _has_navigation_goal() -> bool:
	return is_instance_valid(world_map) \
		and world_map.is_navigation_tile_in_bounds(world_map.endPosition)


func _set_channel(
		local_map: PackedByteArray,
		channel: int,
		relative_tile: Vector2i
	) -> void:
	if channel < 0 or channel >= CHANNEL_COUNT or not _is_visible_offset(relative_tile):
		return
	var side: int = get_map_side_length()
	var local_x: int = relative_tile.x + scan_radius_tiles
	var local_y: int = relative_tile.y + scan_radius_tiles
	var index: int = channel * side * side + local_y * side + local_x
	local_map[index] = 1


func _is_visible_offset(relative_tile: Vector2i) -> bool:
	return absi(relative_tile.x) + absi(relative_tile.y) <= scan_radius_tiles


func _to_tile_array(value: Variant) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if value is Array:
		for tile in value:
			if tile is Vector2i:
				result.append(tile)
	return result


func _sync_highlights() -> void:
	for entity_value: Variant in _highlighted_entities.keys():
		var entity: CanvasItem = entity_value as CanvasItem
		if _detected_entities.has(entity_value):
			continue
		if is_instance_valid(entity):
			var original_color: Color = _highlighted_entities[entity_value]
			entity.modulate = original_color
		_highlighted_entities.erase(entity_value)

	for entity_value: Variant in _detected_entities.keys():
		var entity: CanvasItem = entity_value as CanvasItem
		if not is_instance_valid(entity) or _highlighted_entities.has(entity_value):
			continue
		_highlighted_entities[entity_value] = entity.modulate

	if is_instance_valid(tree_manager):
		for tile: Vector2i in _highlighted_tree_tiles.keys():
			if not _detected_tree_tiles.has(tile):
				tree_manager.set_tree_highlighted(tile, false)
		for tile: Vector2i in _detected_tree_tiles:
			tree_manager.set_tree_highlighted(tile, true)
	_highlighted_tree_tiles.clear()
	for tile: Vector2i in _detected_tree_tiles:
		_highlighted_tree_tiles[tile] = true
	_apply_highlight_pulse()


func _apply_highlight_pulse() -> void:
	var pulse: float = 0.5 + sin(Time.get_ticks_msec() * 0.008) * 0.25
	var highlight_color: Color = Color(1.0, 0.72, 0.12, 1.0)
	for entity_value: Variant in _highlighted_entities.keys():
		var entity: CanvasItem = entity_value as CanvasItem
		if not is_instance_valid(entity):
			_highlighted_entities.erase(entity_value)
			continue
		var original_color: Color = _highlighted_entities[entity_value]
		entity.modulate = original_color.lerp(highlight_color, pulse)


func _clear_highlights() -> void:
	for entity_value: Variant in _highlighted_entities.keys():
		var entity: CanvasItem = entity_value as CanvasItem
		if is_instance_valid(entity):
			var original_color: Color = _highlighted_entities[entity_value]
			entity.modulate = original_color
	_highlighted_entities.clear()
	_detected_entities.clear()

	if is_instance_valid(tree_manager):
		for tile: Vector2i in _highlighted_tree_tiles:
			tree_manager.set_tree_highlighted(tile, false)
	_highlighted_tree_tiles.clear()
	_detected_tree_tiles.clear()


func _exit_tree() -> void:
	_clear_highlights()
