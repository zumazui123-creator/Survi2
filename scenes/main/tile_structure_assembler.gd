extends Node
class_name TileStructureAssembler

signal structure_assembled(
	tile: Vector2i,
	recipe_id: StringName,
	building: BuildingEntity
)

@export var world_map: Map
@export var building_manager: BuildingManager
@export var recipes: Array[StructureRecipe] = []

var _sorted_recipes: Array[StructureRecipe] = []
var _pending_tiles: Dictionary[Vector2i, bool] = {}
var _world_spawner: WorldEntitySpawner


func _ready() -> void:
	_rebuild_recipe_order()
	if is_instance_valid(building_manager):
		building_manager.building_placed.connect(_on_building_placed)
	call_deferred("_connect_world_spawner")


func can_accept_item(tile: Vector2i, item_id: StringName) -> bool:
	if not is_instance_valid(building_manager):
		return false
	var building: BuildingEntity = building_manager.get_building_at(tile)
	if building == null:
		return false
	if building.has_method("can_accept_processing_item") \
			and bool(building.call("can_accept_processing_item", item_id)):
		return true
	for recipe: StructureRecipe in _sorted_recipes:
		if recipe != null \
				and recipe.accepts_base(building.building_id) \
				and recipe.requires_item(item_id):
			return true
	return false


func clear_pending_assemblies() -> void:
	_pending_tiles.clear()


func _connect_world_spawner() -> void:
	_world_spawner = WorldEntitySpawner.get_for(self)
	if not is_instance_valid(_world_spawner):
		push_warning("TileStructureAssembler: WorldEntitySpawner was not found")
		return
	if not _world_spawner.pickup_spawned.is_connected(_on_pickup_spawned):
		_world_spawner.pickup_spawned.connect(_on_pickup_spawned)
	for child: Node in _world_spawner.pickups_root.get_children():
		var pickup: WorldPickup = child as WorldPickup
		if pickup != null:
			_schedule_world_position(pickup.global_position)


func _on_pickup_spawned(pickup: WorldPickup) -> void:
	if pickup == null:
		return
	_schedule_world_position(pickup.global_position)


func _on_building_placed(tile: Vector2i, _building: BuildingEntity) -> void:
	_schedule_tile(tile)


func _schedule_world_position(world_position: Vector2) -> void:
	if not is_instance_valid(world_map):
		return
	_schedule_tile(world_map.world_to_navigation_tile(world_position))


func _schedule_tile(tile: Vector2i) -> void:
	if not multiplayer.is_server() or _pending_tiles.has(tile):
		return
	_pending_tiles[tile] = true
	call_deferred("_evaluate_tile", tile)


func _evaluate_tile(tile: Vector2i) -> void:
	_pending_tiles.erase(tile)
	if not multiplayer.is_server() \
			or not is_instance_valid(building_manager) \
			or not is_instance_valid(_world_spawner):
		return
	var building: BuildingEntity = building_manager.get_building_at(tile)
	if building == null:
		return
	var pickups: Array[WorldPickup] = _get_pickups_at(tile)
	var available_items: Dictionary[StringName, int] = _count_items(pickups)
	var recipe: StructureRecipe = _find_matching_recipe(
		building.building_id,
		available_items
	)
	if recipe == null:
		return
	var replacement: BuildingEntity = building_manager.replace_building(
		building,
		recipe.result_building_id
	)
	if replacement == null:
		return
	_consume_ingredients(pickups, recipe.ingredients)
	structure_assembled.emit(tile, recipe.recipe_id, replacement)
	_schedule_tile(tile)


func _get_pickups_at(tile: Vector2i) -> Array[WorldPickup]:
	var result: Array[WorldPickup] = []
	if not is_instance_valid(_world_spawner.pickups_root):
		return result
	for child: Node in _world_spawner.pickups_root.get_children():
		var pickup: WorldPickup = child as WorldPickup
		if pickup == null or not pickup.is_available_for_structure():
			continue
		if world_map.world_to_navigation_tile(pickup.global_position) == tile:
			result.append(pickup)
	return result


func _count_items(pickups: Array[WorldPickup]) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	for pickup: WorldPickup in pickups:
		var item_id: StringName = StringName(pickup.itemId)
		result[item_id] = int(result.get(item_id, 0)) + pickup.stackCount
	return result


func _find_matching_recipe(
		base_building_id: StringName,
		available_items: Dictionary[StringName, int]
	) -> StructureRecipe:
	for recipe: StructureRecipe in _sorted_recipes:
		if recipe != null \
				and recipe.accepts_base(base_building_id) \
				and recipe.matches(available_items):
			return recipe
	return null


func _consume_ingredients(
		pickups: Array[WorldPickup],
		ingredients: Dictionary
	) -> void:
	for item_value: Variant in ingredients.keys():
		var item_id: String = String(item_value)
		var remaining: int = int(ingredients[item_value])
		for pickup: WorldPickup in pickups:
			if remaining <= 0:
				break
			if pickup.itemId != item_id or not pickup.is_available_for_structure():
				continue
			var consumed: int = mini(remaining, pickup.stackCount)
			pickup.consume_for_structure(consumed)
			remaining -= consumed


func _rebuild_recipe_order() -> void:
	_sorted_recipes.clear()
	for recipe: StructureRecipe in recipes:
		if recipe != null:
			_sorted_recipes.append(recipe)
	_sorted_recipes.sort_custom(_has_higher_priority)


func _has_higher_priority(left: StructureRecipe, right: StructureRecipe) -> bool:
	return left.priority > right.priority

