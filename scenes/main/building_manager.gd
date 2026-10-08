extends Node2D
class_name BuildingManager

signal building_placed(tile: Vector2i, building: BuildingEntity)
signal building_removed(tile: Vector2i, building_id: StringName)

@export var world_map: Map
@export var building_definitions: Array[BuildingDefinition] = []

var _definitions_by_id: Dictionary[StringName, BuildingDefinition] = {}
var _placed_buildings: Dictionary[Vector2i, BuildingEntity] = {}
var _placement_validator: BuildingPlacementValidator = BuildingPlacementValidator.new()


func _ready() -> void:
	_rebuild_definition_index()


func has_definition(building_id: StringName) -> bool:
	return _definitions_by_id.has(building_id)


func get_definition(building_id: StringName) -> BuildingDefinition:
	return _definitions_by_id.get(building_id) as BuildingDefinition


func place_building(
		building_id: StringName,
		tile: Vector2i,
		builder_peer_id: int
	) -> BuildingPlacementValidator.Result:
	if not multiplayer.is_server():
		return BuildingPlacementValidator.Result.SPAWN_FAILED
	var definition: BuildingDefinition = get_definition(building_id)
	if definition == null:
		return BuildingPlacementValidator.Result.UNKNOWN_BUILDING
	var occupied_tiles: Array[Vector2i] = definition.get_occupied_tiles(tile)
	var placement_result: BuildingPlacementValidator.Result = _placement_validator.validate(
		world_map,
		occupied_tiles,
		is_tile_occupied
	)
	if placement_result != BuildingPlacementValidator.Result.OK:
		return placement_result
	if not _can_afford(builder_peer_id, definition.build_cost):
		return BuildingPlacementValidator.Result.NOT_AFFORDABLE
	if definition.scene == null:
		return BuildingPlacementValidator.Result.SPAWN_FAILED
	if not _consume_build_cost(builder_peer_id, definition.build_cost):
		return BuildingPlacementValidator.Result.NOT_AFFORDABLE
	var building: BuildingEntity = _spawn_building(
		definition,
		tile,
		builder_peer_id,
		occupied_tiles
	)
	if building == null:
		_refund_build_cost(builder_peer_id, definition.build_cost)
		return BuildingPlacementValidator.Result.SPAWN_FAILED
	building_placed.emit(tile, building)
	return BuildingPlacementValidator.Result.OK


## Places map-owned structures without charging a player's inventory. It uses
## the same validation, navigation and multiplayer path as player buildings.
func place_generated_building(
		building_id: StringName,
		tile: Vector2i,
		source_id: StringName
	) -> BuildingEntity:
	if not multiplayer.is_server():
		return null
	var definition: BuildingDefinition = get_definition(building_id)
	if definition == null or definition.scene == null:
		return null
	var occupied_tiles: Array[Vector2i] = definition.get_occupied_tiles(tile)
	var placement_result: BuildingPlacementValidator.Result = _placement_validator.validate(
		world_map,
		occupied_tiles,
		is_tile_occupied
	)
	if placement_result != BuildingPlacementValidator.Result.OK:
		return null
	var building: BuildingEntity = _spawn_building(definition, tile, 0, occupied_tiles)
	if building != null:
		building.set_meta(&"generated_source", source_id)
		building_placed.emit(tile, building)
	return building


func is_tile_occupied(tile: Vector2i) -> bool:
	return _placed_buildings.has(tile)


func get_building_at(tile: Vector2i) -> BuildingEntity:
	return _placed_buildings.get(tile) as BuildingEntity


func remove_building(building: BuildingEntity) -> void:
	if not is_instance_valid(building):
		return
	var removed_tile: Vector2i = Vector2i.ZERO
	var found_tile: bool = false
	for tile: Vector2i in building.navigation_tiles:
		if _placed_buildings.get(tile) == building:
			_placed_buildings.erase(tile)
			if not found_tile:
				removed_tile = tile
				found_tile = true
	if found_tile:
		building_removed.emit(removed_tile, building.building_id)


func remove_building_immediately(building: BuildingEntity) -> void:
	if not is_instance_valid(building):
		return
	var navigation_blocker: NavigationBlocker = building.get_node_or_null(
		"NavigationBlocker"
	) as NavigationBlocker
	if navigation_blocker != null:
		navigation_blocker.release()
	remove_building(building)
	var parent: Node = building.get_parent()
	if parent != null:
		parent.remove_child(building)
	building.queue_free()


func clear_buildings() -> void:
	for child: Node in get_children():
		if child is BuildingEntity:
			var navigation_blocker: NavigationBlocker = child.get_node_or_null(
				"NavigationBlocker"
			) as NavigationBlocker
			if navigation_blocker != null:
				navigation_blocker.release()
			remove_child(child)
			child.queue_free()
	_placed_buildings.clear()


func get_placement_message(result: BuildingPlacementValidator.Result) -> String:
	return BuildingPlacementValidator.get_message(result)


func _rebuild_definition_index() -> void:
	_definitions_by_id.clear()
	for definition: BuildingDefinition in building_definitions:
		if definition == null or definition.building_id.is_empty():
			continue
		_definitions_by_id[definition.building_id] = definition


func _on_building_tree_exiting(building: BuildingEntity) -> void:
	remove_building(building)


func _can_afford(builder_peer_id: int, build_cost: Dictionary) -> bool:
	var inventory_id: String = str(builder_peer_id)
	for item_value: Variant in build_cost.keys():
		var item_id: String = String(item_value)
		var amount: int = int(build_cost[item_value])
		if amount > 0 and not Inventory.checkHasItemAmount(inventory_id, item_id, amount):
			return false
	return true


func _consume_build_cost(builder_peer_id: int, build_cost: Dictionary) -> bool:
	var inventory_id: String = str(builder_peer_id)
	var removed_items: Dictionary[String, int] = {}
	for item_value: Variant in build_cost.keys():
		var item_id: String = String(item_value)
		var amount: int = int(build_cost[item_value])
		if amount <= 0:
			continue
		if not Inventory.removeItem(inventory_id, item_id, amount):
			for removed_item: String in removed_items:
				Inventory.addItem(inventory_id, removed_item, removed_items[removed_item])
			return false
		removed_items[item_id] = amount
	return true


func _refund_build_cost(builder_peer_id: int, build_cost: Dictionary) -> void:
	var inventory_id: String = str(builder_peer_id)
	for item_value: Variant in build_cost.keys():
		var item_id: String = String(item_value)
		var amount: int = int(build_cost[item_value])
		if amount > 0:
			Inventory.addItem(inventory_id, item_id, amount)


func _spawn_building(
		definition: BuildingDefinition,
		tile: Vector2i,
		builder_peer_id: int,
		occupied_tiles: Array[Vector2i]
	) -> BuildingEntity:
	var building: BuildingEntity = definition.scene.instantiate() as BuildingEntity
	if building == null:
		return null
	building.configure(definition, builder_peer_id)
	building.position = to_local(world_map.navigation_tile_to_world(tile))
	building.spawner = self
	add_child(building, true)
	building.register_navigation_blockers(occupied_tiles)
	for occupied_tile: Vector2i in occupied_tiles:
		_placed_buildings[occupied_tile] = building
	building.tree_exiting.connect(
		_on_building_tree_exiting.bind(building),
		CONNECT_ONE_SHOT
	)
	return building
