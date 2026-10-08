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
@export_range(0.05, 2.0, 0.05) var intrusion_scan_interval: float = 0.25

var _plans: Dictionary[int, VillagePlan] = {}
var _intruders: Dictionary[int, Array] = {}
var _walls: Array[BuildingEntity] = []
var _residents: Array[VillageResident] = []
var _pigs: Array[VillagePig] = []
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
	for plan: VillagePlan in plans:
		_plans[plan.village_id] = plan
		_intruders[plan.village_id] = []
	villages_changed.emit()
	if not multiplayer.is_server() or definition == null:
		return

	for plan: VillagePlan in plans:
		_spawn_walls(plan, definition.wall_building_id)
		_spawn_residents(plan)
		_spawn_pigs(plan)
		village_loaded.emit(plan.village_id, plan.bounds)
	_update_intruders()


func clear_villages() -> void:
	if multiplayer.is_server():
		for resident: VillageResident in _residents:
			_free_actor(resident)
		for pig: VillagePig in _pigs:
			_free_actor(pig)
		for wall: BuildingEntity in _walls:
			if is_instance_valid(wall) and is_instance_valid(building_manager):
				building_manager.remove_building_immediately(wall)
	_plans.clear()
	_intruders.clear()
	_walls.clear()
	_residents.clear()
	_pigs.clear()
	villages_changed.emit()


func get_plan(village_id: int) -> VillagePlan:
	return _plans.get(village_id) as VillagePlan


func get_plans() -> Array[VillagePlan]:
	var result: Array[VillagePlan] = []
	for plan: VillagePlan in _plans.values():
		result.append(plan)
	result.sort_custom(func(a: VillagePlan, b: VillagePlan) -> bool:
		return a.village_id < b.village_id
	)
	return result


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
			_walls.append(wall)


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
		resident.actor_id = &"villager"
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
