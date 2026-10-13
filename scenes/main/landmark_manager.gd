extends Node2D
class_name LandmarkManager

signal landmarks_changed()
signal golem_awakened()

const LANDMARK_SCENE: PackedScene = preload(
	"res://scenes/map/landmarks/world_landmark.tscn"
)
const LANDMARK_GUARDIAN_SCENE: PackedScene = preload(
	"res://scenes/map/landmarks/landmark_guardian.tscn"
)
const STONE_GOLEM_SCENE: PackedScene = preload("res://scenes/boss/stone_golem.tscn")
const FOREST_COLOSSUS_SCENE: PackedScene = preload(
	"res://scenes/boss/forest_colossus.tscn"
)
const MERCHANT_SCENE: PackedScene = preload(
	"res://scenes/npc/wandering_merchant.tscn"
)

@export var world_map: Map
@export var building_manager: BuildingManager
@export var definitions: Array[LandmarkDefinition] = []
@export_range(1, 10, 1) var golem_sacrifice_stones: int = 3

var _definitions_by_id: Dictionary[StringName, LandmarkDefinition] = {}
var _plans: Array[LandmarkPlan] = []
var _landmark_nodes: Array[Node] = []
var _generated_buildings: Array[BuildingEntity] = []
var _spawned_actors: Array[Node] = []
var _golem: StoneGolem
var _golem_plan: LandmarkPlan
var _sacrifice_count: int = 0
var _accept_sacrifices: bool = false
var _last_graveyard_day: int = -1


func _ready() -> void:
	_rebuild_definition_index()
	var spawner: WorldEntitySpawner = WorldEntitySpawner.get_for(self)
	if is_instance_valid(spawner) \
			and not spawner.pickup_spawned.is_connected(_on_pickup_spawned):
		spawner.pickup_spawned.connect(_on_pickup_spawned)
	if GameTime.has_signal("time_tick") \
			and not GameTime.time_tick.is_connected(_on_time_tick):
		GameTime.time_tick.connect(_on_time_tick)


func load_landmarks(plans: Array[LandmarkPlan]) -> void:
	clear_landmarks()
	_plans.assign(plans)
	landmarks_changed.emit()
	if not multiplayer.is_server() or not is_instance_valid(world_map):
		return
	_accept_sacrifices = false
	for plan: LandmarkPlan in _plans:
		var definition: LandmarkDefinition = get_definition(plan.landmark_id)
		if definition == null:
			continue
		_spawn_landmark_visual(plan)
		_spawn_structure_pattern(plan, definition)
		_spawn_hazards(plan, definition)
		_spawn_loot(plan, definition)
		_spawn_enemies(plan, definition)
		if definition.spawn_merchant:
			_spawn_merchant(plan.center_tile)
		if definition.is_golem_temple:
			_golem_plan = plan
			_spawn_golem(plan.center_tile)
		if definition.is_forest_arena:
			_spawn_forest_colossus(plan.center_tile)
		if not definition.boss_actor_id.is_empty() \
				and not definition.is_golem_temple \
				and not definition.is_forest_arena:
			_spawn_configured_boss(definition.boss_actor_id, plan.center_tile)
	# Initial landmark loot must never count as an altar offering.
	call_deferred("_enable_sacrifices")


func clear_landmarks() -> void:
	_accept_sacrifices = false
	for actor: Node in _spawned_actors:
		_free_node(actor)
	for building: BuildingEntity in _generated_buildings:
		if is_instance_valid(building) and is_instance_valid(building_manager):
			building_manager.remove_building_immediately(building)
	for landmark_node: Node in _landmark_nodes:
		_free_node(landmark_node)
	_spawned_actors.clear()
	_generated_buildings.clear()
	_landmark_nodes.clear()
	_plans.clear()
	_golem = null
	_golem_plan = null
	_sacrifice_count = 0
	_last_graveyard_day = -1
	landmarks_changed.emit()


func get_plans() -> Array[LandmarkPlan]:
	var result: Array[LandmarkPlan] = []
	result.assign(_plans)
	return result


func get_definition(landmark_id: StringName) -> LandmarkDefinition:
	return _definitions_by_id.get(landmark_id) as LandmarkDefinition


func _rebuild_definition_index() -> void:
	_definitions_by_id.clear()
	for definition: LandmarkDefinition in definitions:
		if definition != null and not definition.landmark_id.is_empty():
			_definitions_by_id[definition.landmark_id] = definition


func _spawn_landmark_visual(plan: LandmarkPlan) -> void:
	var landmark: WorldLandmark = LANDMARK_SCENE.instantiate() as WorldLandmark
	if landmark == null:
		return
	landmark.configure(plan.landmark_id, plan.bounds.size)
	landmark.position = to_local(world_map.navigation_tile_to_world(plan.center_tile))
	add_child(landmark, true)
	_landmark_nodes.append(landmark)


func _spawn_structure_pattern(
		plan: LandmarkPlan,
		definition: LandmarkDefinition
	) -> void:
	if not is_instance_valid(building_manager):
		return
	var tiles: Array[Vector2i] = []
	var structure_building_id: StringName = &"wall"
	match definition.structure_style:
		&"temple", &"desert_temple":
			tiles = _get_perimeter_tiles(plan.bounds, 3)
			_append_corner_columns(tiles, plan.bounds)
		&"cave", &"mine":
			tiles = _get_perimeter_tiles(plan.bounds, 2)
		&"tower":
			tiles = _get_perimeter_tiles(plan.bounds, 1)
			_append_corner_columns(tiles, plan.bounds)
		&"camp":
			tiles = _get_perimeter_tiles(plan.bounds, 4)
		&"graveyard":
			tiles = _get_sparse_cross(plan.bounds)
		&"forest_heart", &"ancient_tree":
			tiles = _get_forest_ring_tiles(plan.bounds)
			structure_building_id = &"living_wall"
		&"ruins", &"destroyed_village":
			tiles = _get_ruin_tiles(plan.bounds)
		&"frost_arena":
			tiles = _get_perimeter_tiles(plan.bounds, 2)
			structure_building_id = &"golem_rock_wall"
		&"shipwreck", &"magical_crater":
			return
		_:
			return
	for tile: Vector2i in tiles:
		var building: BuildingEntity = building_manager.place_generated_building(
			structure_building_id, tile, plan.landmark_id
		)
		if building != null:
			_generated_buildings.append(building)


func _spawn_loot(plan: LandmarkPlan, definition: LandmarkDefinition) -> void:
	var spawner: WorldEntitySpawner = WorldEntitySpawner.get_for(self)
	if not is_instance_valid(spawner):
		return
	var offset_index: int = 0
	for item_value: Variant in definition.loot.keys():
		var item_id: String = String(item_value)
		var amount: int = int(definition.loot[item_value])
		if amount <= 0 or not Items.item_definitions.has(item_id):
			continue
		var offset: Vector2i = _loot_offset(offset_index)
		var loot_tile: Vector2i = plan.center_tile + offset
		spawner.spawn_pickups(
			item_id,
			world_map.navigation_tile_to_world(loot_tile),
			amount
		)
		offset_index += 1


func _spawn_hazards(
		plan: LandmarkPlan,
		definition: LandmarkDefinition
	) -> void:
	if not is_instance_valid(building_manager) \
			or definition.hazard_building_id.is_empty():
		return
	for offset: Vector2i in definition.hazard_offsets:
		var building: BuildingEntity = building_manager.place_generated_building(
			definition.hazard_building_id,
			plan.center_tile + offset,
			plan.landmark_id
		)
		if building != null:
			_generated_buildings.append(building)


func _spawn_enemies(plan: LandmarkPlan, definition: LandmarkDefinition) -> void:
	var index: int = 0
	for actor_value: Variant in definition.enemy_spawns.keys():
		var actor_id: StringName = StringName(String(actor_value))
		var amount: int = int(definition.enemy_spawns[actor_value])
		for count: int in range(maxi(amount, 0)):
			var offset: Vector2i = _ring_offset(index + count, 3)
			_spawn_enemy(actor_id, plan.center_tile + offset)
		index += amount


func _spawn_enemy(actor_id: StringName, tile: Vector2i) -> Enemy:
	var enemies_root: Node2D = get_tree().get_first_node_in_group("enemies_root") as Node2D
	if enemies_root == null or not Items.actor_definitions.has(String(actor_id)):
		return null
	var enemy: LandmarkGuardian = LANDMARK_GUARDIAN_SCENE.instantiate() as LandmarkGuardian
	if enemy == null:
		return null
	enemy.actor_id = actor_id
	enemy.global_position = world_map.navigation_tile_to_world(tile)
	enemy.configure_guard(enemy.global_position)
	enemy.spawner = self
	enemies_root.add_child(enemy, true)
	_spawned_actors.append(enemy)
	return enemy


func _spawn_merchant(tile: Vector2i) -> void:
	var animals_root: Node2D = get_tree().get_first_node_in_group("animals_root") as Node2D
	if animals_root == null:
		return
	var merchant: WanderingMerchant = MERCHANT_SCENE.instantiate() as WanderingMerchant
	if merchant == null:
		return
	merchant.global_position = world_map.navigation_tile_to_world(tile)
	animals_root.add_child(merchant, true)
	_spawned_actors.append(merchant)


func _spawn_golem(tile: Vector2i) -> void:
	var enemies_root: Node2D = get_tree().get_first_node_in_group("enemies_root") as Node2D
	if enemies_root == null:
		return
	_golem = STONE_GOLEM_SCENE.instantiate() as StoneGolem
	if _golem == null:
		return
	_golem.global_position = world_map.navigation_tile_to_world(tile)
	_golem.actor_id = &"stoneGolem"
	_golem.spawner = self
	enemies_root.add_child(_golem, true)
	_spawned_actors.append(_golem)


func _spawn_forest_colossus(tile: Vector2i) -> void:
	var enemies_root: Node2D = get_tree().get_first_node_in_group("enemies_root") as Node2D
	if enemies_root == null:
		return
	var boss: ForestColossus = FOREST_COLOSSUS_SCENE.instantiate() as ForestColossus
	if boss == null:
		return
	boss.global_position = world_map.navigation_tile_to_world(tile)
	boss.actor_id = &"forestColossus"
	boss.spawner = self
	enemies_root.add_child(boss, true)
	_spawned_actors.append(boss)


func _spawn_configured_boss(actor_id: StringName, tile: Vector2i) -> void:
	if actor_id == &"forestColossus":
		_spawn_forest_colossus(tile)
		return
	if actor_id == &"stoneGolem" or actor_id == &"frostGiant":
		_spawn_stone_based_boss(actor_id, tile)
		return
	_spawn_enemy(actor_id, tile)


func _spawn_stone_based_boss(actor_id: StringName, tile: Vector2i) -> void:
	var enemies_root: Node2D = get_tree().get_first_node_in_group(
		"enemies_root"
	) as Node2D
	if enemies_root == null:
		return
	var boss: StoneGolem = STONE_GOLEM_SCENE.instantiate() as StoneGolem
	if boss == null:
		return
	boss.global_position = world_map.navigation_tile_to_world(tile)
	boss.actor_id = actor_id
	boss.spawner = self
	if actor_id == &"frostGiant":
		boss.base_visual_color = Color(0.66, 0.9, 1.0, 1.0)
		boss.dormant_visual_color = Color(0.42, 0.62, 0.76, 0.9)
		boss.phase_two_visual_color = Color(0.48, 0.78, 1.0, 1.0)
		boss.phase_three_visual_color = Color(0.72, 0.52, 1.0, 1.0)
	enemies_root.add_child(boss, true)
	_spawned_actors.append(boss)


func _on_pickup_spawned(pickup: WorldPickup) -> void:
	if not multiplayer.is_server() or not _accept_sacrifices:
		return
	call_deferred("_try_accept_sacrifice", pickup)


func _try_accept_sacrifice(pickup: WorldPickup) -> void:
	if not is_instance_valid(pickup) \
			or not is_instance_valid(_golem) \
			or not _golem.dormant \
			or _golem_plan == null \
			or pickup.itemId != "magicStone" \
			or not pickup.is_available_for_structure():
		return
	var altar_position: Vector2 = world_map.navigation_tile_to_world(
		_golem_plan.center_tile
	)
	if pickup.global_position.distance_to(altar_position) > 1.5 * Constants.TILE_SIZE:
		return
	if pickup.consume_for_structure(1) <= 0:
		return
	_sacrifice_count += 1
	if _sacrifice_count >= golem_sacrifice_stones:
		_golem.awaken()
		golem_awakened.emit()


func _on_time_tick(day: int, hour: int, minute: int) -> void:
	if not multiplayer.is_server() or hour != 23 or minute != 0 \
			or day == _last_graveyard_day:
		return
	_last_graveyard_day = day
	for plan: LandmarkPlan in _plans:
		var definition: LandmarkDefinition = get_definition(plan.landmark_id)
		if definition == null or definition.nocturnal_enemy_count <= 0:
			continue
		for index: int in range(definition.nocturnal_enemy_count):
			_spawn_enemy(&"zombie", plan.center_tile + _ring_offset(index, 3))


func _enable_sacrifices() -> void:
	_accept_sacrifices = true


func _get_perimeter_tiles(bounds: Rect2i, gate_half_width: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var center_x: int = bounds.position.x + floori(float(bounds.size.x) * 0.5)
	for x: int in range(bounds.position.x, bounds.end.x):
		if absi(x - center_x) > gate_half_width:
			result.append(Vector2i(x, bounds.end.y - 1))
		result.append(Vector2i(x, bounds.position.y))
	for y: int in range(bounds.position.y + 1, bounds.end.y - 1):
		result.append(Vector2i(bounds.position.x, y))
		result.append(Vector2i(bounds.end.x - 1, y))
	return result


func _append_corner_columns(tiles: Array[Vector2i], bounds: Rect2i) -> void:
	var inset: int = 3
	for tile: Vector2i in [
		bounds.position + Vector2i(inset, inset),
		Vector2i(bounds.end.x - inset - 1, bounds.position.y + inset),
		Vector2i(bounds.position.x + inset, bounds.end.y - inset - 1),
		bounds.end - Vector2i(inset + 1, inset + 1),
	]:
		tiles.append(tile)


func _get_ruin_tiles(bounds: Rect2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x: int in range(bounds.position.x, bounds.end.x, 2):
		result.append(Vector2i(x, bounds.position.y))
		if x % 4 == 0:
			result.append(Vector2i(x, bounds.end.y - 1))
	for y: int in range(bounds.position.y + 2, bounds.end.y - 1, 3):
		result.append(Vector2i(bounds.position.x, y))
	return result


func _get_sparse_cross(bounds: Rect2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var center: Vector2i = bounds.position + Vector2i(
		floori(float(bounds.size.x) * 0.5),
		floori(float(bounds.size.y) * 0.5)
	)
	for offset: int in range(-3, 4, 2):
		result.append(center + Vector2i(offset, -2))
		result.append(center + Vector2i(offset, 2))
	return result


func _get_forest_ring_tiles(bounds: Rect2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var center: Vector2i = bounds.position + Vector2i(
		floori(float(bounds.size.x) * 0.5),
		floori(float(bounds.size.y) * 0.5)
	)
	var radius: int = 7
	for offset: int in range(-radius, radius + 1, 2):
		result.append(center + Vector2i(offset, -radius))
		result.append(center + Vector2i(offset, radius))
		if absi(offset) < radius - 1:
			result.append(center + Vector2i(-radius, offset))
			result.append(center + Vector2i(radius, offset))
	return result


func _loot_offset(index: int) -> Vector2i:
	var offsets: Array[Vector2i] = [
		Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT,
		Vector2i.UP, Vector2i.DOWN,
	]
	return offsets[index % offsets.size()]


func _ring_offset(index: int, radius: int) -> Vector2i:
	var offsets: Array[Vector2i] = [
		Vector2i(radius, 0), Vector2i(-radius, 0),
		Vector2i(0, radius), Vector2i(0, -radius),
		Vector2i(radius, radius), Vector2i(-radius, radius),
		Vector2i(radius, -radius), Vector2i(-radius, -radius),
	]
	return offsets[index % offsets.size()]


func _free_node(node: Node) -> void:
	if not is_instance_valid(node):
		return
	var parent: Node = node.get_parent()
	if parent != null:
		parent.remove_child(node)
	node.queue_free()
