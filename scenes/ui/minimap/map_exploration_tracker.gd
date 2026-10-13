extends Node
class_name MapExplorationTracker

signal exploration_changed
signal exploration_reset
signal location_discovered(location_name: String, description: String)

@export_range(1, 32, 1) var reveal_radius_tiles: int = 8
@export_range(0, 12, 1) var discovery_distance_tiles: int = 2

var explored_tiles: Dictionary[Vector2i, bool] = {}
var _explored_tile_list: Array[Vector2i] = []
var _discovered_locations: Dictionary[String, bool] = {}
var _world_map: Map
var _village_manager: VillageManager
var _landmark_manager: LandmarkManager
var _local_player: Survi2Player
var _last_player_tile: Vector2i = Vector2i.ZERO
var _has_last_player_tile: bool = false


func _ready() -> void:
	_resolve_world_dependencies()
	_connect_world_signals()


func _process(_delta: float) -> void:
	if not is_instance_valid(_world_map) or not is_instance_valid(_world_map.tile_map):
		_resolve_world_dependencies()
		_connect_world_signals()
		return
	if not is_instance_valid(_local_player):
		_local_player = _find_local_player()
	if not is_instance_valid(_local_player):
		return

	var player_tile: Vector2i = _world_map.world_to_navigation_tile(
		_local_player.global_position
	)
	if _has_last_player_tile and player_tile == _last_player_tile:
		return
	_last_player_tile = player_tile
	_has_last_player_tile = true
	_reveal_around(player_tile)
	_check_location_discoveries(player_tile)


func is_tile_explored(tile: Vector2i) -> bool:
	return explored_tiles.has(tile)


func get_explored_tiles() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.assign(_explored_tile_list)
	return result


func is_landmark_discovered(plan: LandmarkPlan) -> bool:
	return plan != null and _discovered_locations.has(_get_landmark_key(plan))


func is_village_discovered(plan: VillagePlan) -> bool:
	return plan != null and _discovered_locations.has(_get_village_key(plan))


func reset_exploration() -> void:
	explored_tiles.clear()
	_explored_tile_list.clear()
	_discovered_locations.clear()
	_local_player = null
	_has_last_player_tile = false
	exploration_changed.emit()
	exploration_reset.emit()


func _resolve_world_dependencies() -> void:
	if not is_instance_valid(_world_map):
		_world_map = get_tree().get_first_node_in_group("world_map") as Map
	if not is_instance_valid(_village_manager):
		_village_manager = get_tree().get_first_node_in_group(
			"village_manager"
		) as VillageManager
	if not is_instance_valid(_landmark_manager):
		_landmark_manager = get_tree().get_first_node_in_group(
			"landmark_manager"
		) as LandmarkManager


func _connect_world_signals() -> void:
	if is_instance_valid(_world_map) \
			and not _world_map.generation_started.is_connected(_on_generation_started):
		_world_map.generation_started.connect(_on_generation_started)
	if is_instance_valid(_village_manager) \
			and not _village_manager.villages_changed.is_connected(_on_locations_changed):
		_village_manager.villages_changed.connect(_on_locations_changed)
	if is_instance_valid(_landmark_manager) \
			and not _landmark_manager.landmarks_changed.is_connected(_on_locations_changed):
		_landmark_manager.landmarks_changed.connect(_on_locations_changed)


func _find_local_player() -> Survi2Player:
	var players_root: Node = get_tree().get_first_node_in_group("players_root")
	if not is_instance_valid(players_root):
		return null
	for child: Node in players_root.get_children():
		var candidate: Survi2Player = child as Survi2Player
		if is_instance_valid(candidate) and candidate.is_multiplayer_authority():
			return candidate
	return null


func _reveal_around(center_tile: Vector2i) -> void:
	var used_rect: Rect2i = _world_map.tile_map.get_used_rect()
	if used_rect.size == Vector2i.ZERO:
		return
	var changed: bool = false
	var radius_squared: int = reveal_radius_tiles * reveal_radius_tiles
	for offset_x: int in range(-reveal_radius_tiles, reveal_radius_tiles + 1):
		for offset_y: int in range(-reveal_radius_tiles, reveal_radius_tiles + 1):
			if offset_x * offset_x + offset_y * offset_y > radius_squared:
				continue
			var tile: Vector2i = center_tile + Vector2i(offset_x, offset_y)
			if not used_rect.has_point(tile) or explored_tiles.has(tile):
				continue
			explored_tiles[tile] = true
			_explored_tile_list.append(tile)
			changed = true
	if changed:
		exploration_changed.emit()


func _check_location_discoveries(player_tile: Vector2i) -> void:
	_check_biome_discovery(player_tile)

	if is_instance_valid(_landmark_manager):
		for plan: LandmarkPlan in _landmark_manager.get_plans():
			var landmark_key: String = _get_landmark_key(plan)
			if _discovered_locations.has(landmark_key) \
					or not _is_near_bounds(player_tile, plan.bounds):
				continue
			var definition: LandmarkDefinition = _landmark_manager.get_definition(
				plan.landmark_id
			)
			var display_name: String = String(plan.landmark_id).capitalize()
			var description: String = ""
			if definition != null:
				display_name = definition.display_name
				description = definition.description
				if not definition.danger_description.is_empty():
					description += "\nGefahr: %s" % definition.danger_description
				if not definition.reward_description.is_empty():
					description += "\nBelohnung: %s" % definition.reward_description
			_discover_location(landmark_key, display_name, description)

	if is_instance_valid(_village_manager):
		for plan: VillagePlan in _village_manager.get_plans():
			var village_key: String = _get_village_key(plan)
			if _discovered_locations.has(village_key) \
					or not _is_near_bounds(player_tile, plan.bounds):
				continue
			var display_name: String = "Großes Dorf" if plan.is_large else "Dorf"
			var description: String = "Eine befestigte Siedlung mit Bewohnern und Tieren."
			_discover_location(village_key, display_name, description)


func _check_biome_discovery(player_tile: Vector2i) -> void:
	if not is_instance_valid(_world_map):
		return
	var definition: BiomeDefinition = _world_map.get_biome_definition_at(player_tile)
	if definition == null or definition.biome_id.is_empty():
		return
	var biome_key: String = "biome:%s" % String(definition.biome_id)
	if _discovered_locations.has(biome_key):
		return
	var description: String = definition.description
	if not definition.hazard_description.is_empty():
		description += "\nGefahr: %s" % definition.hazard_description
	_discover_location(
		biome_key,
		definition.display_name,
		description
	)


func _discover_location(key: String, display_name: String, description: String) -> void:
	_discovered_locations[key] = true
	exploration_changed.emit()
	location_discovered.emit(display_name, description)


func _is_near_bounds(tile: Vector2i, bounds: Rect2i) -> bool:
	if bounds.size == Vector2i.ZERO:
		return false
	var closest_tile: Vector2i = Vector2i(
		clampi(tile.x, bounds.position.x, bounds.end.x - 1),
		clampi(tile.y, bounds.position.y, bounds.end.y - 1)
	)
	var offset: Vector2i = tile - closest_tile
	return offset.length_squared() \
		<= discovery_distance_tiles * discovery_distance_tiles


func _get_landmark_key(plan: LandmarkPlan) -> String:
	return "landmark:%s:%d:%d" % [
		String(plan.landmark_id),
		plan.center_tile.x,
		plan.center_tile.y,
	]


func _get_village_key(plan: VillagePlan) -> String:
	return "village:%d:%d:%d" % [
		plan.village_id,
		plan.bounds.position.x,
		plan.bounds.position.y,
	]


func _on_generation_started() -> void:
	reset_exploration()


func _on_locations_changed() -> void:
	if _has_last_player_tile:
		_check_location_discoveries(_last_player_tile)
