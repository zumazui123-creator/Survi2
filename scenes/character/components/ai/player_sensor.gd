extends Node
class_name PlayerSensor

signal scan_completed(observation: Dictionary)

const CHANNEL_VISIBLE := 0
const CHANNEL_WALKABLE := 1
const CHANNEL_WATER := 2
const CHANNEL_OBJECT := 3
const CHANNEL_ITEM := 4
const CHANNEL_ANIMAL := 5
const CHANNEL_ENEMY := 6
const CHANNEL_GOAL := 7
const CHANNEL_COUNT := 8
const STAT_COUNT := 3

const GROUP_OBJECT := &"sensor_object"
const GROUP_ITEM := &"sensor_item"
const GROUP_ANIMAL := &"sensor_animal"
const GROUP_ENEMY := &"sensor_enemy"

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

@export_group("Sensor")
@export_range(1, 64, 1) var scan_radius_tiles := 10

@onready var world_map: Map = get_tree().get_first_node_in_group("world_map")

var last_observation: Dictionary = {}


## Returns the fixed-size observation consumed directly by the AI environment.
## local_map is a flattened CHANNEL_COUNT x side x side byte tensor.
func scan() -> Dictionary:
	var observation := _create_empty_observation()
	if is_ready_to_scan():
		var origin_tile := get_origin_tile()
		var local_map: PackedByteArray = observation["local_map"]
		_fill_terrain_layers(local_map, origin_tile)
		_mark_entity_group(local_map, GROUP_OBJECT, CHANNEL_OBJECT, origin_tile, true)
		_mark_entity_group(local_map, GROUP_ITEM, CHANNEL_ITEM, origin_tile, false)
		_mark_entity_group(local_map, GROUP_ANIMAL, CHANNEL_ANIMAL, origin_tile, false)
		_mark_entity_group(local_map, GROUP_ENEMY, CHANNEL_ENEMY, origin_tile, false)
		observation["local_map"] = local_map
		observation["stats"] = _scan_stats()
		observation["goal_delta"] = _scan_goal_delta(origin_tile)
		observation["action_mask"] = _scan_action_mask(origin_tile)

	last_observation = observation
	scan_completed.emit(observation)
	return observation


func get_origin_tile() -> Vector2i:
	if is_instance_valid(movement):
		return movement.current_map_position
	if is_instance_valid(world_map) and is_instance_valid(player):
		return world_map.world_to_navigation_tile(player.global_position)
	return Vector2i.ZERO


func get_map_side_length() -> int:
	return scan_radius_tiles * 2 + 1


func get_observation_shape() -> PackedInt32Array:
	var side := get_map_side_length()
	return PackedInt32Array([CHANNEL_COUNT, side, side])


func get_local_map_value_count() -> int:
	var side := get_map_side_length()
	return CHANNEL_COUNT * side * side


func is_ready_to_scan() -> bool:
	return is_instance_valid(player) \
		and is_instance_valid(movement) \
		and is_instance_valid(world_map) \
		and is_instance_valid(world_map.tile_map)


func _create_empty_observation() -> Dictionary:
	var local_map := PackedByteArray()
	local_map.resize(get_local_map_value_count())
	var stat_values := PackedFloat32Array()
	stat_values.resize(STAT_COUNT)
	var goal_delta := PackedFloat32Array()
	goal_delta.resize(2)
	var action_mask := PackedByteArray()
	action_mask.resize(ACTION_DIRECTIONS.size())
	return {
		"local_map": local_map,
		"stats": stat_values,
		"goal_delta": goal_delta,
		"action_mask": action_mask,
	}


func _fill_terrain_layers(local_map: PackedByteArray, origin_tile: Vector2i) -> void:
	for y_offset in range(-scan_radius_tiles, scan_radius_tiles + 1):
		for x_offset in range(-scan_radius_tiles, scan_radius_tiles + 1):
			var relative_tile := Vector2i(x_offset, y_offset)
			if not _is_visible_offset(relative_tile):
				continue

			var tile := origin_tile + relative_tile
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
		var entity := candidate as Node2D
		if not is_instance_valid(entity) or entity == player or entity.is_queued_for_deletion():
			continue

		var anchor_tile := world_map.world_to_navigation_tile(entity.global_position)
		var occupied_tiles: Array[Vector2i] = [anchor_tile]
		if include_footprint and entity.has_method("get_navigation_tiles"):
			occupied_tiles = _to_tile_array(entity.call("get_navigation_tiles", anchor_tile))
		for tile in occupied_tiles:
			_set_channel(local_map, channel, tile - origin_tile)


func _scan_stats() -> PackedFloat32Array:
	var result := PackedFloat32Array([0.0, 0.0, 0.0])
	if not is_instance_valid(stats):
		return result
	result[0] = clampf(stats.hp / maxf(stats.max_hp, 1.0), 0.0, 1.0)
	result[1] = clampf(stats.hydration / 100.0, 0.0, 1.0)
	result[2] = clampf(stats.food / 100.0, 0.0, 1.0)
	return result


func _scan_goal_delta(origin_tile: Vector2i) -> PackedFloat32Array:
	var result := PackedFloat32Array([0.0, 0.0])
	if not _has_navigation_goal():
		return result
	var delta := world_map.endPosition - origin_tile
	result[0] = float(delta.x)
	result[1] = float(delta.y)
	return result


func _scan_action_mask(origin_tile: Vector2i) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(ACTION_DIRECTIONS.size())
	for action in range(ACTION_DIRECTIONS.size()):
		var target_tile := origin_tile + ACTION_DIRECTIONS[action]
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
	var side := get_map_side_length()
	var local_x := relative_tile.x + scan_radius_tiles
	var local_y := relative_tile.y + scan_radius_tiles
	var index := channel * side * side + local_y * side + local_x
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
