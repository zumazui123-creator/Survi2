extends Node2D
class_name TreeManager

signal tree_activated(tile: Vector2i, tree: TreeEntity)
signal tree_deactivated(tile: Vector2i)
signal tree_destroyed(tile: Vector2i)

const TREE_SCENE: PackedScene = preload("res://scenes/spawn/object/tree.tscn")
const DEFAULT_TREE_HP := 40.0

@onready var world_map: Map = get_parent() as Map

# The generated tile is the stable identity of a tree. TreeEntity nodes are
# only its current representation and may later be activated by distance or
# replaced by a passive renderer without losing gameplay state.
var tree_tiles: Dictionary[Vector2i, TreeState] = {}


func load_spawn_data(spawn_data: Array[TreeSpawnData]) -> void:
	if not tree_tiles.is_empty():
		clear_trees()

	for spawn: TreeSpawnData in spawn_data:
		if tree_tiles.has(spawn.tile):
			push_warning("Ignoring duplicate tree tile: %s" % spawn.tile)
			continue
		var state := TreeState.new(spawn, _get_max_hp(spawn.object_id))
		tree_tiles[spawn.tile] = state
		world_map.add_navigation_blocker(spawn.tile)

	# Preserve the current gameplay for now. A later streaming step can replace
	# this with distance-based activation while keeping the state dictionary.
	for tile: Vector2i in tree_tiles:
		activate_tree(tile)


func clear_trees(release_navigation := true) -> void:
	if release_navigation and is_instance_valid(world_map):
		for state: TreeState in tree_tiles.values():
			if not state.is_destroyed():
				world_map.remove_navigation_blocker(state.tile)

	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	tree_tiles.clear()


func activate_tree(tile: Vector2i) -> TreeEntity:
	var state := get_tree_state(tile)
	if state == null or state.is_destroyed():
		return null
	if is_instance_valid(state.active_node):
		return state.active_node

	var tree := TREE_SCENE.instantiate() as TreeEntity
	if tree == null:
		push_error("tree.tscn must use TreeEntity as its root script")
		return null

	add_child(tree, true)
	tree.configure_managed_tree(state.tile, state.object_id, state.current_hp)
	tree.global_position = world_map.navigation_tile_to_world(state.tile)
	tree.health_changed.connect(_on_tree_health_changed)
	tree.tree_destroyed.connect(_on_tree_destroyed)
	state.mark_active(tree)
	tree_activated.emit(tile, tree)
	return tree


func deactivate_tree(tile: Vector2i) -> void:
	var state := get_tree_state(tile)
	if state == null or state.is_destroyed() or not is_instance_valid(state.active_node):
		return
	var tree := state.active_node
	state.mark_passive()
	remove_child(tree)
	tree.queue_free()
	tree_deactivated.emit(tile)


func get_tree_state(tile: Vector2i) -> TreeState:
	return tree_tiles.get(tile) as TreeState


func get_tree_states_in_radius(
		center_tile: Vector2i,
		radius: int,
		include_destroyed := false
	) -> Array[TreeState]:
	var result: Array[TreeState] = []
	var safe_radius := maxi(radius, 0)
	for y in range(center_tile.y - safe_radius, center_tile.y + safe_radius + 1):
		for x in range(center_tile.x - safe_radius, center_tile.x + safe_radius + 1):
			var state := get_tree_state(Vector2i(x, y))
			if state == null or (state.is_destroyed() and not include_destroyed):
				continue
			result.append(state)
	return result


func _get_max_hp(object_id: String) -> float:
	var object_data: Dictionary = Items.objects.get(object_id, {})
	return float(object_data.get("hp", DEFAULT_TREE_HP))


func _on_tree_health_changed(tile: Vector2i, current_hp: float) -> void:
	var state := get_tree_state(tile)
	if state != null and not state.is_destroyed():
		state.current_hp = clampf(current_hp, 0.0, state.max_hp)


func _on_tree_destroyed(tile: Vector2i) -> void:
	var state := get_tree_state(tile)
	if state == null or state.is_destroyed():
		return
	state.mark_destroyed()
	world_map.remove_navigation_blocker(tile)
	tree_destroyed.emit(tile)
