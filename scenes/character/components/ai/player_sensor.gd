extends Node
class_name PlayerSensor

signal scan_completed(snapshot: Dictionary)

const GROUP_OBJECT := &"sensor_object"
const GROUP_ITEM := &"sensor_item"
const GROUP_ANIMAL := &"sensor_animal"
const GROUP_ENEMY := &"sensor_enemy"

@export_group("References")
@export var player: CharacterBody2D
@export var movement: PlayerMovement

@export_group("Sensor")
@export_range(1, 64, 1) var scan_radius_tiles := 10

@onready var world_map: Map = get_tree().get_first_node_in_group("world_map")

var last_snapshot: Dictionary = {}


## Returns a deterministic snapshot in tile coordinates. Entity entries contain
## category, id, tile, relative_tile, Manhattan distance, occupied tiles and
## instance_id. Water entries contain the same positional fields without a node.
func scan() -> Dictionary:
	var origin_tile := get_origin_tile()
	var snapshot := _create_empty_snapshot(origin_tile)
	if not is_ready_to_scan():
		last_snapshot = snapshot
		scan_completed.emit(snapshot)
		return snapshot

	snapshot.objects = _scan_entity_group(
		GROUP_OBJECT,
		&"objectId",
		&"object",
		origin_tile,
		true,
		[&"hp"]
	)
	snapshot.items = _scan_entity_group(
		GROUP_ITEM,
		&"itemId",
		&"item",
		origin_tile,
		false,
		[&"stackCount"]
	)
	snapshot.animals = _scan_entity_group(
		GROUP_ANIMAL,
		&"actor_id",
		&"animal",
		origin_tile,
		false,
		[&"hp", &"maxhp"]
	)
	snapshot.enemies = _scan_entity_group(
		GROUP_ENEMY,
		&"actor_id",
		&"enemy",
		origin_tile,
		false,
		[&"hp", &"maxhp"]
	)
	snapshot.water = _scan_water_tiles(origin_tile)

	last_snapshot = snapshot
	scan_completed.emit(snapshot)
	return snapshot


func get_origin_tile() -> Vector2i:
	if is_instance_valid(movement):
		return movement.current_map_position
	if is_instance_valid(world_map) and is_instance_valid(player):
		return world_map.world_to_navigation_tile(player.global_position)
	return Vector2i.ZERO


func is_ready_to_scan() -> bool:
	return is_instance_valid(player) \
		and is_instance_valid(world_map) \
		and is_instance_valid(world_map.tile_map)


func _create_empty_snapshot(origin_tile: Vector2i) -> Dictionary:
	return {
		"origin": origin_tile,
		"radius": scan_radius_tiles,
		"objects": [],
		"items": [],
		"animals": [],
		"enemies": [],
		"water": [],
	}


func _scan_entity_group(
		group: StringName,
		id_property: StringName,
		category: StringName,
		origin_tile: Vector2i,
		include_footprint: bool,
		extra_properties: Array[StringName]
	) -> Array[Dictionary]:
	var detections: Array[Dictionary] = []
	for candidate in get_tree().get_nodes_in_group(group):
		var entity := candidate as Node2D
		if not is_instance_valid(entity) or entity == player or entity.is_queued_for_deletion():
			continue

		var anchor_tile := world_map.world_to_navigation_tile(entity.global_position)
		var entity_tiles: Array[Vector2i] = [anchor_tile]
		if include_footprint and entity.has_method("get_navigation_tiles"):
			entity_tiles = _to_tile_array(entity.call("get_navigation_tiles", anchor_tile))

		var visible_tiles := _filter_tiles_in_radius(entity_tiles, origin_tile)
		if visible_tiles.is_empty():
			continue

		var distance := _minimum_tile_distance(visible_tiles, origin_tile)
		var detection := {
			"category": category,
			"id": StringName(str(entity.get(id_property))),
			"tile": anchor_tile,
			"relative_tile": anchor_tile - origin_tile,
			"distance": distance,
			"tiles": visible_tiles,
			"instance_id": entity.get_instance_id(),
		}
		for property_name in extra_properties:
			detection[String(property_name).to_snake_case()] = entity.get(property_name)
		detections.append(detection)

	detections.sort_custom(_sort_detections)
	return detections


func _scan_water_tiles(origin_tile: Vector2i) -> Array[Dictionary]:
	var water_tiles: Array[Dictionary] = []
	for y_offset in range(-scan_radius_tiles, scan_radius_tiles + 1):
		for x_offset in range(-scan_radius_tiles, scan_radius_tiles + 1):
			var relative_tile := Vector2i(x_offset, y_offset)
			var distance := _tile_distance(Vector2i.ZERO, relative_tile)
			if distance > scan_radius_tiles:
				continue

			var tile := origin_tile + relative_tile
			if world_map.tile_map.get_cell_source_id(tile) < 0:
				continue
			var atlas_coordinates := world_map.tile_map.get_cell_atlas_coords(tile)
			if atlas_coordinates not in world_map.waterCoors:
				continue
			water_tiles.append({
				"category": &"water",
				"id": &"water",
				"tile": tile,
				"relative_tile": relative_tile,
				"distance": distance,
			})

	water_tiles.sort_custom(_sort_detections)
	return water_tiles


func _filter_tiles_in_radius(
		tiles: Array[Vector2i],
		origin_tile: Vector2i
	) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for tile in tiles:
		if _tile_distance(origin_tile, tile) <= scan_radius_tiles:
			result.append(tile)
	return result


func _minimum_tile_distance(tiles: Array[Vector2i], origin_tile: Vector2i) -> int:
	var minimum_distance := scan_radius_tiles + 1
	for tile in tiles:
		minimum_distance = mini(minimum_distance, _tile_distance(origin_tile, tile))
	return minimum_distance


func _tile_distance(from_tile: Vector2i, to_tile: Vector2i) -> int:
	var difference := to_tile - from_tile
	return absi(difference.x) + absi(difference.y)


func _to_tile_array(value: Variant) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if value is Array:
		for tile in value:
			if tile is Vector2i:
				result.append(tile)
	return result


func _sort_detections(left: Dictionary, right: Dictionary) -> bool:
	var left_distance := int(left.distance)
	var right_distance := int(right.distance)
	if left_distance != right_distance:
		return left_distance < right_distance
	var left_tile: Vector2i = left.tile
	var right_tile: Vector2i = right.tile
	if left_tile.y != right_tile.y:
		return left_tile.y < right_tile.y
	if left_tile.x != right_tile.x:
		return left_tile.x < right_tile.x
	return String(left.get("id", "")) < String(right.get("id", ""))
