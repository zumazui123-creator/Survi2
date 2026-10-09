extends Node2D
class_name ObjectManager

@export var tree_manager: TreeManager
@export var breakable_manager: BreakableManager
@export var building_manager: BuildingManager
@export var tile_structure_assembler: TileStructureAssembler
@export var village_manager: VillageManager
@export var teleport_network: TeleportNetwork


func load_tree_spawn_data(spawn_data: Array[TreeSpawnData]) -> void:
	if is_instance_valid(tree_manager):
		tree_manager.load_spawn_data(spawn_data)


func clear_trees(release_navigation: bool = true) -> void:
	if is_instance_valid(tree_manager):
		tree_manager.clear_trees(release_navigation)


func get_trees_in_radius(
		center_tile: Vector2i,
		radius: int,
		include_destroyed: bool = false
	) -> Array[TreeState]:
	if not is_instance_valid(tree_manager):
		var empty_result: Array[TreeState] = []
		return empty_result
	return tree_manager.get_trees_in_radius(center_tile, radius, include_destroyed)


func spawn_initial_breakables() -> int:
	if not is_instance_valid(breakable_manager):
		return 0
	return breakable_manager.spawn_objects(breakable_manager.initial_spawn_objects)


func try_spawn_breakable_wave() -> int:
	if not is_instance_valid(breakable_manager):
		return 0
	return breakable_manager.try_spawn_wave()


func configure_breakables(initial_amount: int, maximum_amount: int) -> void:
	if is_instance_valid(breakable_manager):
		breakable_manager.configure_limits(initial_amount, maximum_amount)


func clear_breakables() -> void:
	if is_instance_valid(breakable_manager):
		breakable_manager.clear_breakables()


func clear_buildings() -> void:
	if is_instance_valid(tile_structure_assembler):
		tile_structure_assembler.clear_pending_assemblies()
	if is_instance_valid(teleport_network):
		teleport_network.clear()
	if is_instance_valid(building_manager):
		building_manager.clear_buildings()


func load_villages(
		plans: Array[VillagePlan],
		definition: VillageDefinition
	) -> void:
	if is_instance_valid(village_manager):
		village_manager.load_villages(plans, definition)


func clear_villages() -> void:
	if is_instance_valid(village_manager):
		village_manager.clear_villages()


func is_tile_in_village(tile: Vector2i) -> bool:
	return is_instance_valid(village_manager) \
		and village_manager.is_tile_in_any_village(tile)


func clear_all(release_tree_navigation: bool = true) -> void:
	clear_villages()
	clear_trees(release_tree_navigation)
	clear_breakables()
	clear_buildings()
