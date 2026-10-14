extends Node2D
class_name SecretLocationManager

signal secrets_changed()
signal secret_revealed(plan: SecretLocationPlan, definition: SecretLocationDefinition)
signal secret_opened(plan: SecretLocationPlan, definition: SecretLocationDefinition)

@export var world_map: Map
@export var building_manager: BuildingManager
@export var tree_manager: TreeManager
@export var marker_scene: PackedScene
@export var definitions: Array[SecretLocationDefinition] = []
@export_range(0.1, 2.0, 0.1) var proximity_scan_interval: float = 0.4

var _definitions_by_id: Dictionary[StringName, SecretLocationDefinition] = {}
var _plans: Dictionary[int, SecretLocationPlan] = {}
var _markers: Dictionary[int, SecretLocation] = {}
var _revealed: Dictionary[int, bool] = {}
var _opened: Dictionary[int, bool] = {}
var _loot_spawned: Dictionary[int, bool] = {}
var _generated_buildings: Array[BuildingEntity] = []
var _scan_remaining: float = 0.0


func _ready() -> void:
	_rebuild_definition_index()
	if is_instance_valid(tree_manager) \
			and not tree_manager.tree_destroyed.is_connected(_on_tree_destroyed):
		tree_manager.tree_destroyed.connect(_on_tree_destroyed)
	if is_instance_valid(building_manager):
		if not building_manager.building_removed.is_connected(_on_building_removed):
			building_manager.building_removed.connect(_on_building_removed)
		if not building_manager.building_placed.is_connected(_on_building_placed):
			building_manager.building_placed.connect(_on_building_placed)


func _process(delta: float) -> void:
	_scan_remaining -= delta
	if _scan_remaining > 0.0 or _plans.is_empty():
		return
	_scan_remaining = proximity_scan_interval
	_reveal_near_players()


func load_secrets(plans: Array[SecretLocationPlan]) -> void:
	clear_secrets()
	_rebuild_definition_index()
	for plan: SecretLocationPlan in plans:
		_plans[plan.plan_id] = plan
		_create_marker(plan)
		var definition: SecretLocationDefinition = get_definition(plan.secret_id)
		if definition == null:
			continue
		if definition.access_type in [
			SecretLocationDefinition.AccessType.OPEN,
			SecretLocationDefinition.AccessType.TELEPORT,
		]:
			_opened[plan.plan_id] = true
	if multiplayer.is_server():
		for plan: SecretLocationPlan in plans:
			_spawn_access_objects(plan)
	secrets_changed.emit()


func clear_secrets() -> void:
	for marker: SecretLocation in _markers.values():
		if is_instance_valid(marker):
			marker.queue_free()
	# Clear plans before buildings so their removal signals cannot open a secret
	# or spawn rewards while the world is being regenerated.
	_plans.clear()
	if multiplayer.is_server() and is_instance_valid(building_manager):
		for building: BuildingEntity in _generated_buildings:
			if is_instance_valid(building):
				building_manager.remove_building_immediately(building)
	_markers.clear()
	_revealed.clear()
	_opened.clear()
	_loot_spawned.clear()
	_generated_buildings.clear()
	secrets_changed.emit()


func get_plans() -> Array[SecretLocationPlan]:
	var result: Array[SecretLocationPlan] = []
	for plan: SecretLocationPlan in _plans.values():
		result.append(plan)
	result.sort_custom(func(a: SecretLocationPlan, b: SecretLocationPlan) -> bool:
		return a.plan_id < b.plan_id
	)
	return result


func get_definition(secret_id: StringName) -> SecretLocationDefinition:
	return _definitions_by_id.get(secret_id) as SecretLocationDefinition


func is_revealed(plan_id: int) -> bool:
	return _revealed.has(plan_id)


func is_opened(plan_id: int) -> bool:
	return _opened.has(plan_id)


func scan_secret_tiles(center_tile: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for plan: SecretLocationPlan in _plans.values():
		if _tile_distance(center_tile, plan.center_tile) > radius:
			continue
		result.append(plan.center_tile)
		_reveal_secret(plan.plan_id, true)
	return result


func _create_marker(plan: SecretLocationPlan) -> void:
	var definition: SecretLocationDefinition = get_definition(plan.secret_id)
	if definition == null or marker_scene == null or not is_instance_valid(world_map):
		return
	var marker: SecretLocation = marker_scene.instantiate() as SecretLocation
	if marker == null:
		return
	marker.name = "Secret%d_%s" % [plan.plan_id, String(plan.secret_id)]
	marker.position = to_local(world_map.navigation_tile_to_world(plan.center_tile))
	marker.configure(plan, definition)
	add_child(marker)
	_markers[plan.plan_id] = marker


func _spawn_access_objects(plan: SecretLocationPlan) -> void:
	var definition: SecretLocationDefinition = get_definition(plan.secret_id)
	if definition == null or not is_instance_valid(building_manager):
		return
	if definition.access_type == SecretLocationDefinition.AccessType.DESTRUCTIBLE_WALL \
			or definition.terrain_style == SecretLocationDefinition.TerrainStyle.PASSAGE:
		for tile: Vector2i in plan.barrier_tiles:
			_spawn_generated_building(definition.barrier_building_id, tile, plan.plan_id)
	if definition.access_type == SecretLocationDefinition.AccessType.TELEPORT:
		for tile: Vector2i in plan.access_building_tiles:
			_spawn_generated_building(&"teleport_pad", tile, -1000 - plan.plan_id)


func _spawn_generated_building(
		building_id: StringName,
		tile: Vector2i,
		owner_id: int
	) -> void:
	var building: BuildingEntity = building_manager.place_generated_building(
		building_id,
		tile,
		&"secret",
		owner_id
	)
	if building != null:
		building.set_meta(&"secret_plan_id", owner_id if owner_id >= 0 else -owner_id - 1000)
		_generated_buildings.append(building)


func _reveal_near_players() -> void:
	if not is_instance_valid(world_map):
		return
	var players_root: Node2D = get_tree().get_first_node_in_group("players_root") as Node2D
	if players_root == null:
		return
	for child: Node in players_root.get_children():
		var player: Node2D = child as Node2D
		if player == null:
			continue
		var player_tile: Vector2i = world_map.world_to_navigation_tile(player.global_position)
		for plan: SecretLocationPlan in _plans.values():
			var definition: SecretLocationDefinition = get_definition(plan.secret_id)
			if definition == null or definition.sensor_only:
				continue
			if _tile_distance(player_tile, plan.center_tile) <= definition.reveal_distance_tiles:
				_reveal_secret(plan.plan_id, false)


func _reveal_secret(plan_id: int, via_sensor: bool) -> void:
	if _revealed.has(plan_id):
		return
	var plan: SecretLocationPlan = _plans.get(plan_id) as SecretLocationPlan
	if plan == null:
		return
	var definition: SecretLocationDefinition = get_definition(plan.secret_id)
	if definition == null or definition.sensor_only and not via_sensor:
		return
	_revealed[plan_id] = true
	var marker: SecretLocation = _markers.get(plan_id) as SecretLocation
	if is_instance_valid(marker):
		marker.reveal()
	secret_revealed.emit(plan, definition)
	secrets_changed.emit()
	if multiplayer.is_server():
		_try_spawn_loot(plan_id)
		_client_reveal_secret.rpc(plan_id)
	else:
		_server_reveal_secret.rpc_id(1, plan_id, via_sensor)


@rpc("any_peer", "call_remote", "reliable")
func _server_reveal_secret(plan_id: int, via_sensor: bool) -> void:
	if multiplayer.is_server():
		_reveal_secret(plan_id, via_sensor)


@rpc("authority", "call_remote", "reliable")
func _client_reveal_secret(plan_id: int) -> void:
	if _revealed.has(plan_id):
		return
	var plan: SecretLocationPlan = _plans.get(plan_id) as SecretLocationPlan
	if plan == null:
		return
	var definition: SecretLocationDefinition = get_definition(plan.secret_id)
	if definition == null:
		return
	_revealed[plan_id] = true
	var marker: SecretLocation = _markers.get(plan_id) as SecretLocation
	if is_instance_valid(marker):
		marker.reveal()
	secret_revealed.emit(plan, definition)
	secrets_changed.emit()


func _open_secret(plan_id: int) -> void:
	if _opened.has(plan_id):
		return
	var plan: SecretLocationPlan = _plans.get(plan_id) as SecretLocationPlan
	var definition: SecretLocationDefinition = get_definition(plan.secret_id) if plan != null else null
	if plan == null or definition == null:
		return
	_opened[plan_id] = true
	secret_opened.emit(plan, definition)
	_try_spawn_loot(plan_id)


func _try_spawn_loot(plan_id: int) -> void:
	if not multiplayer.is_server() or _loot_spawned.has(plan_id) \
			or not _opened.has(plan_id) or not _revealed.has(plan_id):
		return
	var plan: SecretLocationPlan = _plans.get(plan_id) as SecretLocationPlan
	var definition: SecretLocationDefinition = get_definition(plan.secret_id) if plan != null else null
	if plan == null or definition == null or definition.loot.is_empty():
		return
	var spawner: WorldEntitySpawner = WorldEntitySpawner.get_for(self)
	if not is_instance_valid(spawner):
		return
	_loot_spawned[plan_id] = true
	var tile_index: int = 0
	for item_value: Variant in definition.loot:
		var item_id: String = String(item_value)
		var amount: int = int(definition.loot[item_value])
		if amount <= 0 or not Items.item_definitions.has(item_id):
			continue
		var tile: Vector2i = plan.loot_tiles[tile_index % plan.loot_tiles.size()]
		spawner.spawn_pickups(item_id, world_map.navigation_tile_to_world(tile), amount)
		tile_index += 1


func _on_tree_destroyed(tile: Vector2i) -> void:
	for plan: SecretLocationPlan in _plans.values():
		if tile not in plan.cover_tree_tiles:
			continue
		var all_destroyed: bool = true
		for cover_tile: Vector2i in plan.cover_tree_tiles:
			var state: TreeState = tree_manager.get_tree_state(cover_tile)
			if state != null and not state.is_destroyed():
				all_destroyed = false
				break
		if all_destroyed:
			_open_secret(plan.plan_id)


func _on_building_removed(tile: Vector2i, _building_id: StringName) -> void:
	for plan: SecretLocationPlan in _plans.values():
		if tile in plan.barrier_tiles:
			_open_secret(plan.plan_id)


func _on_building_placed(tile: Vector2i, building: BuildingEntity) -> void:
	if building == null or building.building_id != &"jump_pad":
		return
	for plan: SecretLocationPlan in _plans.values():
		var definition: SecretLocationDefinition = get_definition(plan.secret_id)
		if definition != null \
				and definition.access_type == SecretLocationDefinition.AccessType.JUMP \
				and _tile_distance(tile, plan.entrance_tile) <= 1:
			_open_secret(plan.plan_id)


func _rebuild_definition_index() -> void:
	_definitions_by_id.clear()
	for definition: SecretLocationDefinition in definitions:
		if definition != null and not definition.secret_id.is_empty():
			_definitions_by_id[definition.secret_id] = definition


func _tile_distance(left: Vector2i, right: Vector2i) -> int:
	return absi(left.x - right.x) + absi(left.y - right.y)
