extends Node2D
class_name VillageManager

signal village_loaded(village_id: int, bounds: Rect2i)
signal villages_changed()
signal intrusion_started(village_id: int, player: CharacterBody2D)
signal intrusion_ended(village_id: int, player: CharacterBody2D)

@export var world_map: Map
@export var building_manager: BuildingManager
@export var resident_scene: PackedScene
@export var pig_scene: PackedScene
@export var merchant_scene: PackedScene
@export var hostile_scene: PackedScene
@export_range(0.05, 2.0, 0.05) var intrusion_scan_interval: float = 0.25

var _plans: Dictionary[int, VillagePlan] = {}
var _intruders: Dictionary[int, Array] = {}
var _generated_buildings: Array[BuildingEntity] = []
var _residents: Array[VillageResident] = []
var _pigs: Array[VillagePig] = []
var _merchants: Array[WanderingMerchant] = []
var _hostiles: Array[LandmarkGuardian] = []
var _definition: VillageDefinition
var _scan_remaining: float = 0.0


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or _plans.is_empty():
		return
	_scan_remaining -= delta
	if _scan_remaining > 0.0:
		return
	_scan_remaining = intrusion_scan_interval
	_update_intruders()


func load_villages(
		plans: Array[VillagePlan],
		definition: VillageDefinition
	) -> void:
	clear_villages()
	_definition = definition
	for plan: VillagePlan in plans:
		_plans[plan.village_id] = plan
		_intruders[plan.village_id] = []
	villages_changed.emit()
	if not multiplayer.is_server() or definition == null:
		return

	for plan: VillagePlan in plans:
		var role: VillageRoleDefinition = get_role_for_plan(plan)
		var wall_id: StringName = role.wall_building_id \
			if role != null else definition.wall_building_id
		_spawn_walls(plan, wall_id)
		_spawn_feature_buildings(plan, role)
		_spawn_residents(plan)
		_spawn_pigs(plan)
		_spawn_merchants(plan)
		_spawn_hostiles(plan)
		_spawn_loot(plan, role, definition)
		village_loaded.emit(plan.village_id, plan.bounds)
	_update_intruders()


func clear_villages() -> void:
	if multiplayer.is_server():
		for resident: VillageResident in _residents:
			_free_actor(resident)
		for pig: VillagePig in _pigs:
			_free_actor(pig)
		for merchant: WanderingMerchant in _merchants:
			_free_actor(merchant)
		for hostile: LandmarkGuardian in _hostiles:
			_free_actor(hostile)
		for building: BuildingEntity in _generated_buildings:
			if is_instance_valid(building) and is_instance_valid(building_manager):
				building_manager.remove_building_immediately(building)
	_plans.clear()
	_intruders.clear()
	_generated_buildings.clear()
	_residents.clear()
	_pigs.clear()
	_merchants.clear()
	_hostiles.clear()
	_definition = null
	villages_changed.emit()


func get_plan(village_id: int) -> VillagePlan:
	return _plans.get(village_id) as VillagePlan


func get_role_definition(role_id: StringName) -> VillageRoleDefinition:
	if _definition == null:
		return null
	return _definition.get_role(role_id)


func get_role_for_plan(plan: VillagePlan) -> VillageRoleDefinition:
	if plan == null:
		return null
	return get_role_definition(plan.role_id)


func get_plans() -> Array[VillagePlan]:
	var result: Array[VillagePlan] = []
	for plan: VillagePlan in _plans.values():
		result.append(plan)
	result.sort_custom(func(a: VillagePlan, b: VillagePlan) -> bool:
		return a.village_id < b.village_id
	)
	return result


func get_nearest_resident(
		village_id: int,
		from_position: Vector2
	) -> VillageResident:
	var nearest_resident: VillageResident
	var nearest_distance_squared: float = INF
	for resident: VillageResident in _residents:
		if not is_instance_valid(resident) or resident.village_id != village_id:
			continue
		var distance_squared: float = from_position.distance_squared_to(
			resident.global_position
		)
		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_resident = resident
	return nearest_resident


func get_nearest_intruder(village_id: int, from_position: Vector2) -> CharacterBody2D:
	var nearest_player: CharacterBody2D
	var nearest_distance_squared: float = INF
	var intruders: Array = _intruders.get(village_id, [])
	for value: Variant in intruders:
		var player: CharacterBody2D = value as CharacterBody2D
		if not is_instance_valid(player):
			continue
		var distance_squared: float = from_position.distance_squared_to(player.global_position)
		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_player = player
	return nearest_player


func is_player_inside(village_id: int, player: CharacterBody2D) -> bool:
	if not is_instance_valid(player):
		return false
	var plan: VillagePlan = get_plan(village_id)
	if plan == null or not is_instance_valid(world_map):
		return false
	var player_tile: Vector2i = world_map.world_to_navigation_tile(player.global_position)
	return plan.contains_interior_tile(player_tile)


func is_tile_in_any_village(tile: Vector2i) -> bool:
	for plan: VillagePlan in _plans.values():
		if plan.contains_tile(tile):
			return true
	return false


func notify_resident_removed(resident: VillageResident) -> void:
	_residents.erase(resident)


func notify_pig_removed(pig: VillagePig) -> void:
	_pigs.erase(pig)


func _spawn_walls(plan: VillagePlan, wall_id: StringName) -> void:
	if not is_instance_valid(building_manager):
		push_warning("VillageManager: BuildingManager is missing; village walls were skipped")
		return
	for tile: Vector2i in plan.wall_tiles:
		var wall: BuildingEntity = building_manager.place_generated_building(
			wall_id,
			tile,
			&"village"
		)
		if wall != null:
			_generated_buildings.append(wall)


func _spawn_feature_buildings(
		plan: VillagePlan,
		role: VillageRoleDefinition
	) -> void:
	if role == null or role.feature_building_id == &"":
		return
	if not is_instance_valid(building_manager):
		push_warning("VillageManager: BuildingManager is missing; village features were skipped")
		return
	for tile: Vector2i in plan.feature_building_tiles:
		var building: BuildingEntity = building_manager.place_generated_building(
			role.feature_building_id,
			tile,
			&"village"
		)
		if building != null:
			_generated_buildings.append(building)


func _spawn_residents(plan: VillagePlan) -> void:
	if resident_scene == null:
		push_warning("VillageManager: resident scene is missing")
		return
	var enemies_root: Node2D = get_tree().get_first_node_in_group("enemies_root") as Node2D
	if enemies_root == null:
		push_warning("VillageManager: enemies root is missing; residents were skipped")
		return
	for index: int in range(plan.resident_spawn_tiles.size()):
		var resident: VillageResident = resident_scene.instantiate() as VillageResident
		if resident == null:
			continue
		resident.name = "Village%dResident%d" % [plan.village_id, index]
		resident.global_position = world_map.navigation_tile_to_world(
			plan.resident_spawn_tiles[index]
		)
		resident.actor_id = plan.resident_actor_id
		resident.configure_village(plan.village_id, self)
		enemies_root.add_child(resident, true)
		_residents.append(resident)


func _spawn_pigs(plan: VillagePlan) -> void:
	if pig_scene == null:
		push_warning("VillageManager: pig scene is missing")
		return
	var animals_root: Node2D = get_tree().get_first_node_in_group("animals_root") as Node2D
	if animals_root == null:
		push_warning("VillageManager: animals root is missing; village pigs were skipped")
		return
	for index: int in range(plan.pig_spawn_tiles.size()):
		var pig: VillagePig = pig_scene.instantiate() as VillagePig
		if pig == null:
			continue
		pig.name = "Village%dPig%d" % [plan.village_id, index]
		pig.global_position = world_map.navigation_tile_to_world(plan.pig_spawn_tiles[index])
		pig.actor_id = &"pig"
		pig.configure_village(plan.village_id, plan.interior_bounds, self, world_map)
		animals_root.add_child(pig, true)
		_pigs.append(pig)


func _spawn_merchants(plan: VillagePlan) -> void:
	if plan.merchant_spawn_tiles.is_empty():
		return
	if merchant_scene == null:
		push_warning("VillageManager: merchant scene is missing")
		return
	var animals_root: Node2D = get_tree().get_first_node_in_group("animals_root") as Node2D
	if animals_root == null:
		push_warning("VillageManager: animals root is missing; merchants were skipped")
		return
	for index: int in range(plan.merchant_spawn_tiles.size()):
		var merchant: WanderingMerchant = merchant_scene.instantiate() as WanderingMerchant
		if merchant == null:
			continue
		merchant.name = "Village%dMerchant%d" % [plan.village_id, index]
		merchant.global_position = world_map.navigation_tile_to_world(
			plan.merchant_spawn_tiles[index]
		)
		merchant.wander_radius_tiles = 3
		merchant.invulnerable = true
		animals_root.add_child(merchant, true)
		_merchants.append(merchant)


func _spawn_hostiles(plan: VillagePlan) -> void:
	if plan.hostile_spawn_tiles.is_empty():
		return
	if hostile_scene == null:
		push_warning("VillageManager: hostile scene is missing")
		return
	var enemies_root: Node2D = get_tree().get_first_node_in_group("enemies_root") as Node2D
	if enemies_root == null:
		push_warning("VillageManager: enemies root is missing; occupiers were skipped")
		return
	for index: int in range(plan.hostile_spawn_tiles.size()):
		var hostile: LandmarkGuardian = hostile_scene.instantiate() as LandmarkGuardian
		if hostile == null:
			continue
		hostile.name = "Village%dOccupier%d" % [plan.village_id, index]
		hostile.global_position = world_map.navigation_tile_to_world(
			plan.hostile_spawn_tiles[index]
		)
		if index < plan.hostile_actor_ids.size():
			hostile.actor_id = plan.hostile_actor_ids[index]
		hostile.configure_guard(hostile.global_position)
		hostile.spawner = self
		enemies_root.add_child(hostile, true)
		_hostiles.append(hostile)


func _spawn_loot(
		plan: VillagePlan,
		role: VillageRoleDefinition,
		definition: VillageDefinition
	) -> void:
	if plan.loot_spawn_tiles.is_empty():
		return
	var loot: Dictionary = role.loot if role != null else {}
	if loot.is_empty() and plan.is_large:
		loot = definition.large_village_loot
	if loot.is_empty():
		return
	var spawner: WorldEntitySpawner = WorldEntitySpawner.get_for(self)
	if not is_instance_valid(spawner) or not is_instance_valid(world_map):
		push_warning("VillageManager: world entity spawner is missing; village loot was skipped")
		return

	var item_ids: Array[String] = []
	for value: Variant in loot.keys():
		item_ids.append(String(value))
	item_ids.sort()
	var loot_tile_index: int = 0
	for item_id: String in item_ids:
		var amount: int = int(loot.get(item_id, 0))
		if amount <= 0:
			continue
		if not Items.item_definitions.has(item_id):
			push_warning("VillageManager: unknown village loot item '%s'" % item_id)
			continue
		var loot_tile: Vector2i = plan.loot_spawn_tiles[
			loot_tile_index % plan.loot_spawn_tiles.size()
		]
		spawner.spawn_pickups(
			item_id,
			world_map.navigation_tile_to_world(loot_tile),
			amount
		)
		loot_tile_index += 1


func _update_intruders() -> void:
	var players_root: Node2D = get_tree().get_first_node_in_group("players_root") as Node2D
	for village_id: int in _plans:
		var previous: Array = _intruders.get(village_id, [])
		var current: Array = []
		if players_root != null:
			for child: Node in players_root.get_children():
				var player: CharacterBody2D = child as CharacterBody2D
				if player != null and is_player_inside(village_id, player):
					current.append(player)
		for value: Variant in current:
			var entering_player: CharacterBody2D = value as CharacterBody2D
			if entering_player not in previous:
				intrusion_started.emit(village_id, entering_player)
		for value: Variant in previous:
			var leaving_player: CharacterBody2D = value as CharacterBody2D
			if is_instance_valid(leaving_player) and leaving_player not in current:
				intrusion_ended.emit(village_id, leaving_player)
		_intruders[village_id] = current


func _free_actor(actor: Node) -> void:
	if not is_instance_valid(actor):
		return
	var parent: Node = actor.get_parent()
	if parent != null:
		parent.remove_child(actor)
	actor.queue_free()
