extends Node2D
class_name WorldEventManager

signal events_changed()
signal event_activated(plan: WorldEventPlan)
signal event_deactivated(plan: WorldEventPlan)

const MARKER_SCENE: PackedScene = preload(
	"res://scenes/world_events/world_event_marker.tscn"
)
const ATTACKER_SCENE: PackedScene = preload(
	"res://scenes/world_events/world_event_attacker.tscn"
)
const ESCAPED_PIG_SCENE: PackedScene = preload(
	"res://scenes/world_events/escaped_pig.tscn"
)
const MERCHANT_SCENE: PackedScene = preload(
	"res://scenes/npc/wandering_merchant.tscn"
)
const CARAVAN_MERCHANT_SCENE: PackedScene = preload(
	"res://scenes/world_events/caravan_merchant.tscn"
)
const INVALID_TILE: Vector2i = Vector2i(-1, -1)

@export var world_map: Map
@export var village_manager: VillageManager
@export var definitions: Array[WorldEventDefinition] = []

var _definitions_by_id: Dictionary[StringName, WorldEventDefinition] = {}
var _plans: Array[WorldEventPlan] = []
var _nodes_by_plan_key: Dictionary[String, Array] = {}
var _active_plan_keys: Dictionary[String, bool] = {}
var _completed_deliveries: Dictionary[String, bool] = {}
var _markers_by_plan_key: Dictionary[String, WorldEventMarker] = {}
var _navigation_leaders_by_plan_key: Dictionary[String, CaravanMerchant] = {}
var _navigation_graph: WorldEventNavigationGraph = WorldEventNavigationGraph.new()
var _night_active: bool = false


func _ready() -> void:
	_rebuild_definition_index()
	_navigation_graph.configure(world_map)
	_night_active = GameTime.is_night_time()
	if GameTime.has_signal("time_tick") \
			and not GameTime.time_tick.is_connected(_on_time_tick):
		GameTime.time_tick.connect(_on_time_tick)


func _process(_delta: float) -> void:
	if not multiplayer.is_server():
		return
	for plan_key: String in _navigation_leaders_by_plan_key:
		var leader: CaravanMerchant = _navigation_leaders_by_plan_key[plan_key]
		var marker: WorldEventMarker = _markers_by_plan_key.get(plan_key)
		if is_instance_valid(leader) and is_instance_valid(marker):
			marker.global_position = leader.global_position


func load_events(plans: Array[WorldEventPlan]) -> void:
	clear_events()
	_navigation_graph.configure(world_map)
	_plans.assign(plans)
	_night_active = GameTime.is_night_time()
	if multiplayer.is_server():
		for plan: WorldEventPlan in _plans:
			var definition: WorldEventDefinition = get_definition(plan.event_id)
			if definition == null:
				continue
			if definition.activation == WorldEventDefinition.Activation.MAP_START \
					or _night_active:
				_activate_plan(plan, definition)
	events_changed.emit()


func clear_events() -> void:
	if multiplayer.is_server():
		for nodes_value: Variant in _nodes_by_plan_key.values():
			var nodes: Array = nodes_value
			for node_value: Variant in nodes:
				var node: Node = node_value as Node
				_free_node(node)
	_nodes_by_plan_key.clear()
	_active_plan_keys.clear()
	_completed_deliveries.clear()
	_markers_by_plan_key.clear()
	_navigation_leaders_by_plan_key.clear()
	_navigation_graph.invalidate()
	_plans.clear()
	events_changed.emit()


func get_plans() -> Array[WorldEventPlan]:
	var result: Array[WorldEventPlan] = []
	result.assign(_plans)
	return result


func get_active_plans() -> Array[WorldEventPlan]:
	var result: Array[WorldEventPlan] = []
	for plan: WorldEventPlan in _plans:
		var definition: WorldEventDefinition = get_definition(plan.event_id)
		if definition == null:
			continue
		if definition.activation == WorldEventDefinition.Activation.MAP_START \
				or _night_active:
			result.append(plan)
	return result


func get_definition(event_id: StringName) -> WorldEventDefinition:
	return _definitions_by_id.get(event_id) as WorldEventDefinition


func _rebuild_definition_index() -> void:
	_definitions_by_id.clear()
	for definition: WorldEventDefinition in definitions:
		if definition != null and not definition.event_id.is_empty():
			_definitions_by_id[definition.event_id] = definition


func _activate_plan(
		plan: WorldEventPlan,
		definition: WorldEventDefinition
	) -> void:
	var plan_key: String = plan.get_key()
	if _active_plan_keys.has(plan_key):
		return
	_active_plan_keys[plan_key] = true
	var event_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	event_rng.seed = Multihelper.mapSeed \
		^ plan.center_tile.x * 73856093 \
		^ plan.center_tile.y * 19349663 \
		^ hash(String(plan.event_id))

	_spawn_marker(plan, definition)
	var friendly_nodes: Array[CharacterBody2D] = _spawn_friendlies(plan, definition)
	var protected_target: CharacterBody2D = _resolve_protected_target(
		plan,
		definition,
		friendly_nodes
	)
	_spawn_hostiles(plan, definition, protected_target, event_rng)
	if not definition.deliver_loot_at_destination:
		_spawn_loot(plan, definition, plan.center_tile)
	event_activated.emit(plan)
	events_changed.emit()


func _deactivate_plan(plan: WorldEventPlan) -> void:
	var plan_key: String = plan.get_key()
	if not _active_plan_keys.has(plan_key):
		return
	_active_plan_keys.erase(plan_key)
	var nodes: Array = _nodes_by_plan_key.get(plan_key, [])
	for node_value: Variant in nodes:
		var node: Node = node_value as Node
		_free_node(node)
	_nodes_by_plan_key.erase(plan_key)
	_completed_deliveries.erase(plan_key)
	_markers_by_plan_key.erase(plan_key)
	_navigation_leaders_by_plan_key.erase(plan_key)
	event_deactivated.emit(plan)
	events_changed.emit()


func _spawn_marker(plan: WorldEventPlan, definition: WorldEventDefinition) -> void:
	if definition.marker_style.is_empty() or not is_instance_valid(world_map):
		return
	var marker: WorldEventMarker = MARKER_SCENE.instantiate() as WorldEventMarker
	if marker == null:
		return
	marker.configure(
		definition.marker_style,
		definition.marker_color,
		definition.glowing
	)
	marker.position = to_local(world_map.navigation_tile_to_world(plan.center_tile))
	add_child(marker, true)
	_register_node(plan, marker)
	_markers_by_plan_key[plan.get_key()] = marker


func _spawn_friendlies(
		plan: WorldEventPlan,
		definition: WorldEventDefinition
	) -> Array[CharacterBody2D]:
	var result: Array[CharacterBody2D] = []
	match definition.friendly_role:
		WorldEventDefinition.FriendlyRole.MERCHANT:
			var merchant: WanderingMerchant = _spawn_merchant(
				plan,
				plan.center_tile,
				definition.target_role == WorldEventDefinition.TargetRole.SPAWNED_FRIENDLY
			)
			if merchant != null:
				result.append(merchant)
		WorldEventDefinition.FriendlyRole.ESCAPED_PIG:
			var pig: EscapedPig = _spawn_escaped_pig(plan)
			if pig != null:
				result.append(pig)
		WorldEventDefinition.FriendlyRole.CARAVAN:
			if definition.navigation_required:
				result.append_array(_spawn_caravan(plan, definition))
			else:
				for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT]:
					var caravan_merchant: WanderingMerchant = _spawn_merchant(
						plan,
						plan.center_tile + offset,
						false
					)
					if caravan_merchant != null:
						result.append(caravan_merchant)
	return result


func _spawn_caravan(
		plan: WorldEventPlan,
		definition: WorldEventDefinition
	) -> Array[CharacterBody2D]:
	var result: Array[CharacterBody2D] = []
	var destination: Vector2i = _find_caravan_destination(plan)
	if destination == INVALID_TILE:
		push_warning("WorldEventManager: caravan has no reachable destination")
		_completed_deliveries[plan.get_key()] = true
		_spawn_loot(plan, definition, plan.center_tile)
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT]:
			var stationary_merchant: WanderingMerchant = _spawn_merchant(
				plan,
				plan.center_tile + offset,
				false
			)
			if stationary_merchant != null:
				result.append(stationary_merchant)
		return result

	var start_offsets: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT]
	var destination_tiles: Array[Vector2i] = [
		destination,
		_find_distinct_walkable_tile(destination + Vector2i.RIGHT, destination),
	]
	for index: int in range(start_offsets.size()):
		var start_tile: Vector2i = _find_nearby_walkable_tile(
			plan.center_tile + start_offsets[index],
			plan.center_tile
		)
		if start_tile == INVALID_TILE:
			continue
		var member_destination: Vector2i = destination_tiles[index]
		if member_destination == INVALID_TILE:
			member_destination = destination
		var merchant: CaravanMerchant = _spawn_caravan_merchant(plan, start_tile)
		if merchant == null:
			continue
		merchant.travel_to(
			world_map,
			_navigation_graph,
			member_destination,
			float(index) * 1.25
		)
		result.append(merchant)
		if index == 0:
			_navigation_leaders_by_plan_key[plan.get_key()] = merchant
			merchant.caravan_route_finished.connect(
				_on_caravan_route_finished.bind(plan, definition),
				CONNECT_ONE_SHOT
			)
	return result


func _spawn_caravan_merchant(
		plan: WorldEventPlan,
		tile: Vector2i
	) -> CaravanMerchant:
	var animals_root: Node2D = get_tree().get_first_node_in_group(
		"animals_root"
	) as Node2D
	if animals_root == null or not is_instance_valid(world_map):
		return null
	var merchant: CaravanMerchant = CARAVAN_MERCHANT_SCENE.instantiate() \
		as CaravanMerchant
	if merchant == null:
		return null
	merchant.invulnerable = true
	merchant.global_position = world_map.navigation_tile_to_world(tile)
	animals_root.add_child(merchant, true)
	_register_node(plan, merchant)
	return merchant


func _spawn_merchant(
		plan: WorldEventPlan,
		tile: Vector2i,
		vulnerable: bool
	) -> WanderingMerchant:
	var animals_root: Node2D = get_tree().get_first_node_in_group(
		"animals_root"
	) as Node2D
	if animals_root == null or not is_instance_valid(world_map):
		return null
	var merchant: WanderingMerchant = MERCHANT_SCENE.instantiate() as WanderingMerchant
	if merchant == null:
		return null
	merchant.invulnerable = not vulnerable
	merchant.global_position = world_map.navigation_tile_to_world(tile)
	animals_root.add_child(merchant, true)
	_register_node(plan, merchant)
	return merchant


func _spawn_escaped_pig(plan: WorldEventPlan) -> EscapedPig:
	var animals_root: Node2D = get_tree().get_first_node_in_group(
		"animals_root"
	) as Node2D
	if animals_root == null or not is_instance_valid(world_map):
		return null
	var pig: EscapedPig = ESCAPED_PIG_SCENE.instantiate() as EscapedPig
	if pig == null:
		return null
	pig.global_position = world_map.navigation_tile_to_world(plan.center_tile)
	pig.spawner = self
	animals_root.add_child(pig, true)
	_register_node(plan, pig)
	return pig


func _resolve_protected_target(
		plan: WorldEventPlan,
		definition: WorldEventDefinition,
		friendly_nodes: Array[CharacterBody2D]
	) -> CharacterBody2D:
	match definition.target_role:
		WorldEventDefinition.TargetRole.VILLAGE_RESIDENT:
			if is_instance_valid(village_manager):
				return village_manager.get_nearest_resident(
					plan.village_id,
					world_map.navigation_tile_to_world(plan.center_tile)
				)
		WorldEventDefinition.TargetRole.SPAWNED_FRIENDLY:
			return friendly_nodes[0] if not friendly_nodes.is_empty() else null
	return null


func _spawn_hostiles(
		plan: WorldEventPlan,
		definition: WorldEventDefinition,
		protected_target: CharacterBody2D,
		rng: RandomNumberGenerator
	) -> void:
	if definition.hostile_actor_id.is_empty() \
			or not Items.actor_definitions.has(String(definition.hostile_actor_id)):
		return
	var amount: int = definition.get_hostile_count(rng)
	var retarget_village_id: int = -1
	if definition.retarget_village_residents:
		retarget_village_id = plan.village_id
	for index: int in range(amount):
		_spawn_hostile(
			plan,
			definition.hostile_actor_id,
			plan.center_tile + _ring_offset(index, 2),
			protected_target,
			retarget_village_id
		)


func _spawn_hostile(
		plan: WorldEventPlan,
		actor_id: StringName,
		tile: Vector2i,
		protected_target: CharacterBody2D,
		retarget_village_id: int
	) -> WorldEventAttacker:
	var enemies_root: Node2D = get_tree().get_first_node_in_group(
		"enemies_root"
	) as Node2D
	if enemies_root == null or not is_instance_valid(world_map):
		return null
	var attacker: WorldEventAttacker = ATTACKER_SCENE.instantiate() as WorldEventAttacker
	if attacker == null:
		return null
	var spawn_tile: Vector2i = _find_nearby_walkable_tile(tile, plan.center_tile)
	if spawn_tile == Vector2i(-1, -1):
		return null
	attacker.actor_id = actor_id
	attacker.global_position = world_map.navigation_tile_to_world(spawn_tile)
	attacker.spawner = self
	attacker.configure_event_guard(
		world_map.navigation_tile_to_world(plan.center_tile),
		protected_target,
		retarget_village_id
	)
	enemies_root.add_child(attacker, true)
	_register_node(plan, attacker)
	return attacker


func _spawn_loot(
		plan: WorldEventPlan,
		definition: WorldEventDefinition,
		center_tile: Vector2i
	) -> void:
	if definition.loot.is_empty() or not is_instance_valid(world_map):
		return
	var spawner: WorldEntitySpawner = WorldEntitySpawner.get_for(self)
	if not is_instance_valid(spawner):
		return
	var loot_index: int = 0
	for item_value: Variant in definition.loot.keys():
		var item_id: String = String(item_value)
		var amount: int = int(definition.loot[item_value])
		if amount <= 0 or not Items.item_definitions.has(item_id):
			continue
		var offset: Vector2i = _ring_offset(loot_index, 1)
		spawner.spawn_pickups(
			item_id,
			world_map.navigation_tile_to_world(center_tile + offset),
			amount
		)
		loot_index += 1


func _on_caravan_route_finished(
		_caravan: CaravanMerchant,
		destination_tile: Vector2i,
		plan: WorldEventPlan,
		definition: WorldEventDefinition
	) -> void:
	var plan_key: String = plan.get_key()
	if _completed_deliveries.has(plan_key):
		return
	_completed_deliveries[plan_key] = true
	_spawn_loot(plan, definition, destination_tile)
	events_changed.emit()


func _find_caravan_destination(plan: WorldEventPlan) -> Vector2i:
	if not is_instance_valid(world_map) or not is_instance_valid(village_manager):
		return INVALID_TILE
	var best_tile: Vector2i = INVALID_TILE
	var best_path_length: int = 0
	for village: VillagePlan in village_manager.get_plans():
		if village.village_id == plan.village_id:
			continue
		var candidates: Array[Vector2i] = []
		candidates.assign(village.approach_tiles)
		if candidates.is_empty():
			candidates.assign(village.gate_tiles)
		for candidate: Vector2i in candidates:
			if not world_map.is_navigation_tile_walkable(candidate):
				continue
			var route: Array[Vector2i] = _navigation_graph.find_path(
				plan.center_tile,
				candidate
			)
			if route.size() > best_path_length:
				best_path_length = route.size()
				best_tile = candidate
	if best_tile != INVALID_TILE:
		return best_tile
	return _find_distant_reachable_tile(plan.center_tile)


func _find_distant_reachable_tile(from_tile: Vector2i) -> Vector2i:
	var candidates: Array[Vector2i] = []
	candidates.assign(world_map.spawnable_tiles)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return from_tile.distance_squared_to(a) > from_tile.distance_squared_to(b)
	)
	var checks: int = mini(candidates.size(), 32)
	for index: int in range(checks):
		var candidate: Vector2i = candidates[index]
		var route: Array[Vector2i] = _navigation_graph.find_path(from_tile, candidate)
		if route.size() > 1:
			return candidate
	return INVALID_TILE


func _find_distinct_walkable_tile(
		preferred_tile: Vector2i,
		excluded_tile: Vector2i
	) -> Vector2i:
	var candidates: Array[Vector2i] = [
		preferred_tile,
		excluded_tile + Vector2i.LEFT,
		excluded_tile + Vector2i.DOWN,
		excluded_tile + Vector2i.UP,
	]
	for candidate: Vector2i in candidates:
		if candidate != excluded_tile \
				and world_map.is_navigation_tile_walkable(candidate):
			return candidate
	return INVALID_TILE


func _register_node(plan: WorldEventPlan, node: Node) -> void:
	var plan_key: String = plan.get_key()
	if not _nodes_by_plan_key.has(plan_key):
		_nodes_by_plan_key[plan_key] = []
	var nodes: Array = _nodes_by_plan_key[plan_key]
	nodes.append(node)


func _ring_offset(index: int, radius: int) -> Vector2i:
	var offsets: Array[Vector2i] = [
		Vector2i(radius, 0),
		Vector2i(0, radius),
		Vector2i(-radius, 0),
		Vector2i(0, -radius),
		Vector2i(radius, radius),
		Vector2i(-radius, radius),
		Vector2i(-radius, -radius),
		Vector2i(radius, -radius),
	]
	return offsets[index % offsets.size()]


func _find_nearby_walkable_tile(
		preferred_tile: Vector2i,
		center_tile: Vector2i
	) -> Vector2i:
	if world_map.is_navigation_tile_walkable(preferred_tile, true):
		return preferred_tile
	for radius: int in range(1, 5):
		for y_offset: int in range(-radius, radius + 1):
			for x_offset: int in range(-radius, radius + 1):
				if absi(x_offset) != radius and absi(y_offset) != radius:
					continue
				var candidate: Vector2i = center_tile + Vector2i(x_offset, y_offset)
				if world_map.is_navigation_tile_walkable(candidate, true):
					return candidate
	return Vector2i(-1, -1)


func _on_time_tick(_day: int, hour: int, _minute: int) -> void:
	var is_night: bool = hour >= 23 or hour < 1
	if is_night == _night_active:
		return
	_night_active = is_night
	if multiplayer.is_server():
		for plan: WorldEventPlan in _plans:
			var definition: WorldEventDefinition = get_definition(plan.event_id)
			if definition == null \
					or definition.activation != WorldEventDefinition.Activation.NIGHT:
				continue
			if _night_active:
				_activate_plan(plan, definition)
			else:
				_deactivate_plan(plan)
	events_changed.emit()


func _free_node(node: Node) -> void:
	if not is_instance_valid(node):
		return
	var parent: Node = node.get_parent()
	if parent != null:
		parent.remove_child(node)
	node.queue_free()
