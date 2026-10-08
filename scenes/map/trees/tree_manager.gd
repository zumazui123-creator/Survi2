extends Node2D
class_name TreeManager

signal tree_activated(tile: Vector2i, tree: TreeEntity)
signal tree_deactivated(tile: Vector2i)
signal tree_destroyed(tile: Vector2i)
signal tree_regrown(tile: Vector2i)

const TREE_SCENE: PackedScene = preload("res://scenes/spawn/object/tree.tscn")
const DEFAULT_TREE_OBJECT_ID: String = "tree0"
const DEFAULT_TREE_HP: float = 40.0
const PASSIVE_COLOR: Color = Color.WHITE
const PASSIVE_HIGHLIGHT_COLOR: Color = Color(1.0, 0.72, 0.12, 1.0)
const HIDDEN_COLOR: Color = Color(1.0, 1.0, 1.0, 0.0)

@export_group("Activation")
@export_range(1, 64, 1) var activation_radius_tiles: int = 14
@export_range(0, 32, 1) var deactivation_margin_tiles: int = 4
@export_range(0.05, 5.0, 0.05) var activation_check_interval: float = 0.5
@export_range(25, 200, 1) var active_tree_batch_size: int = 50
@export_range(0.1, 30.0, 0.1) var active_tree_batch_interval: float = 5.0

@export_group("Storage")
@export_range(4, 64, 1) var chunk_size_tiles: int = 16
@export_range(0.0, 3600.0, 1.0) var tree_spawn_delay: float = 60.0

@onready var world_map: Map = get_parent().get_parent() as Map
@onready var passive_trees: MultiMeshInstance2D = $PassiveTrees

# Tiles are the stable identity. Full TreeEntity scenes are temporary active
# representations; HP, destruction and navigation live in TreeState.
var tree_tiles: Dictionary[Vector2i, TreeState] = {}

var _tree_chunks: Dictionary = {}
var _active_tiles: Dictionary[Vector2i, bool] = {}
var _activation_queue: Array[Vector2i] = []
var _queued_tiles: Dictionary[Vector2i, bool] = {}
var _respawn_remaining: Dictionary[Vector2i, float] = {}
var _highlighted_tiles: Dictionary[Vector2i, bool] = {}
var _activation_elapsed: float = 0.0
var _batch_elapsed: float = 0.0


func _ready() -> void:
	_batch_elapsed = active_tree_batch_interval


func _process(delta: float) -> void:
	_update_regrowth(delta)
	_update_passive_highlight_pulse()

	_activation_elapsed += delta
	if _activation_elapsed >= activation_check_interval:
		_activation_elapsed = 0.0
		_refresh_activation_targets()

	_batch_elapsed = minf(_batch_elapsed + delta, active_tree_batch_interval)
	if not _activation_queue.is_empty() and _batch_elapsed >= active_tree_batch_interval:
		_activate_queued_batch()
		_batch_elapsed = 0.0


func load_spawn_data(spawn_data: Array[TreeSpawnData]) -> void:
	if not tree_tiles.is_empty():
		clear_trees()

	for spawn: TreeSpawnData in spawn_data:
		if tree_tiles.has(spawn.tile):
			push_warning("Ignoring duplicate tree tile: %s" % spawn.tile)
			continue
		var state: TreeState = TreeState.new(spawn, _get_max_hp(spawn.object_id))
		tree_tiles[spawn.tile] = state
		_add_to_chunk(state.tile)
		world_map.add_navigation_blocker(spawn.tile)

	_rebuild_passive_representation()
	_batch_elapsed = active_tree_batch_interval
	_refresh_activation_targets()


func clear_trees(release_navigation: bool = true) -> void:
	if release_navigation and is_instance_valid(world_map):
		for state: TreeState in tree_tiles.values():
			if not state.is_destroyed():
				world_map.remove_navigation_blocker(state.tile)

	for child: Node in get_children():
		if child is TreeEntity:
			remove_child(child)
			child.queue_free()

	passive_trees.multimesh = null
	passive_trees.texture = null
	tree_tiles.clear()
	_tree_chunks.clear()
	_active_tiles.clear()
	_activation_queue.clear()
	_queued_tiles.clear()
	_respawn_remaining.clear()
	_highlighted_tiles.clear()


func activate_tree(tile: Vector2i) -> TreeEntity:
	var state: TreeState = get_tree_state(tile)
	_queued_tiles.erase(tile)
	if state == null or state.is_destroyed():
		return null
	if is_instance_valid(state.active_node):
		return state.active_node

	var tree: TreeEntity = TREE_SCENE.instantiate() as TreeEntity
	if tree == null:
		push_error("tree.tscn must use TreeEntity as its root script")
		return null

	add_child(tree, true)
	tree.configure_managed_tree(state.tile, state.object_id, state.current_hp)
	tree.global_position = world_map.navigation_tile_to_world(state.tile)
	tree.health_changed.connect(_on_tree_health_changed)
	tree.tree_destroyed.connect(_on_tree_destroyed)
	state.mark_active(tree)
	_active_tiles[tile] = true
	_update_passive_instance(state)
	tree_activated.emit(tile, tree)
	return tree


func deactivate_tree(tile: Vector2i) -> void:
	var state: TreeState = get_tree_state(tile)
	if state == null or state.is_destroyed() or state.current_hp <= 0.0:
		return
	if not is_instance_valid(state.active_node):
		state.mark_passive()
		_active_tiles.erase(tile)
		_update_passive_instance(state)
		return

	var tree: TreeEntity = state.active_node
	state.mark_passive()
	_active_tiles.erase(tile)
	remove_child(tree)
	tree.queue_free()
	_update_passive_instance(state)
	tree_deactivated.emit(tile)


func get_tree_state(tile: Vector2i) -> TreeState:
	return tree_tiles.get(tile) as TreeState


func get_trees_in_radius(
		center_tile: Vector2i,
		radius: int,
		include_destroyed: bool = false
	) -> Array[TreeState]:
	var result: Array[TreeState] = []
	var safe_radius: int = maxi(radius, 0)
	var chunk_radius: int = ceili(float(safe_radius) / float(maxi(chunk_size_tiles, 1)))
	var center_chunk: Vector2i = _get_chunk(center_tile)

	for chunk_y in range(center_chunk.y - chunk_radius, center_chunk.y + chunk_radius + 1):
		for chunk_x in range(center_chunk.x - chunk_radius, center_chunk.x + chunk_radius + 1):
			var chunk_tiles: Array = _tree_chunks.get(Vector2i(chunk_x, chunk_y), [])
			for tile_value: Variant in chunk_tiles:
				var tile: Vector2i = tile_value
				if absi(tile.x - center_tile.x) + absi(tile.y - center_tile.y) > safe_radius:
					continue
				var state: TreeState = get_tree_state(tile)
				if state == null or (state.is_destroyed() and not include_destroyed):
					continue
				result.append(state)
	return result


func get_tree_states_in_radius(
		center_tile: Vector2i,
		radius: int,
		include_destroyed: bool = false
	) -> Array[TreeState]:
	return get_trees_in_radius(center_tile, radius, include_destroyed)


func set_tree_highlighted(tile: Vector2i, highlighted: bool) -> void:
	var state: TreeState = get_tree_state(tile)
	if state == null:
		return
	state.highlighted = highlighted
	if highlighted:
		_highlighted_tiles[tile] = true
	else:
		_highlighted_tiles.erase(tile)
	_update_passive_instance(state)


func _refresh_activation_targets() -> void:
	var player_tiles: Array[Vector2i] = _get_player_tiles()
	var desired_tiles: Dictionary[Vector2i, bool] = {}
	for player_tile: Vector2i in player_tiles:
		for state: TreeState in get_trees_in_radius(player_tile, activation_radius_tiles):
			desired_tiles[state.tile] = true

	for tile: Vector2i in _active_tiles.keys():
		var state: TreeState = get_tree_state(tile)
		if state == null:
			_active_tiles.erase(tile)
			continue
		if not is_instance_valid(state.active_node):
			state.mark_passive()
			_active_tiles.erase(tile)
			_update_passive_instance(state)
			continue
		if not _is_near_any_player(
				tile,
				player_tiles,
				activation_radius_tiles + deactivation_margin_tiles
			):
			deactivate_tree(tile)

	_activation_queue.clear()
	_queued_tiles.clear()
	var candidates: Array[Vector2i] = []
	for tile: Vector2i in desired_tiles:
		var state: TreeState = get_tree_state(tile)
		if state == null or state.is_destroyed() or is_instance_valid(state.active_node):
			continue
		candidates.append(tile)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _distance_to_nearest_player(a, player_tiles) < _distance_to_nearest_player(b, player_tiles)
	)
	for tile: Vector2i in candidates:
		_activation_queue.append(tile)
		_queued_tiles[tile] = true


func _activate_queued_batch() -> void:
	var activated: int = 0
	while activated < active_tree_batch_size and not _activation_queue.is_empty():
		var tile: Vector2i = _activation_queue.pop_front()
		_queued_tiles.erase(tile)
		if activate_tree(tile) != null:
			activated += 1


func _get_player_tiles() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for candidate: Node in get_tree().get_nodes_in_group("player"):
		var player: CharacterBody2D = candidate as CharacterBody2D
		if not is_instance_valid(player) or player.is_queued_for_deletion():
			continue
		result.append(world_map.world_to_navigation_tile(player.global_position))
	return result


func _is_near_any_player(
		tile: Vector2i,
		player_tiles: Array[Vector2i],
		radius: int
	) -> bool:
	for player_tile: Vector2i in player_tiles:
		if absi(tile.x - player_tile.x) + absi(tile.y - player_tile.y) <= radius:
			return true
	return false


func _distance_to_nearest_player(tile: Vector2i, player_tiles: Array[Vector2i]) -> int:
	var result: int = 2147483647
	for player_tile: Vector2i in player_tiles:
		var distance: int = absi(tile.x - player_tile.x) + absi(tile.y - player_tile.y)
		result = mini(result, distance)
	return result


func _add_to_chunk(tile: Vector2i) -> void:
	var chunk: Vector2i = _get_chunk(tile)
	var chunk_tiles: Array = _tree_chunks.get(chunk, [])
	chunk_tiles.append(tile)
	_tree_chunks[chunk] = chunk_tiles


func _get_chunk(tile: Vector2i) -> Vector2i:
	var safe_chunk_size: int = maxi(chunk_size_tiles, 1)
	return Vector2i(
		floori(float(tile.x) / float(safe_chunk_size)),
		floori(float(tile.y) / float(safe_chunk_size))
	)


func _rebuild_passive_representation() -> void:
	var texture: Texture2D = Items.get_object_texture(DEFAULT_TREE_OBJECT_ID)
	if texture == null or tree_tiles.is_empty():
		passive_trees.multimesh = null
		passive_trees.texture = null
		return

	var quad: QuadMesh = QuadMesh.new()
	quad.size = texture.get_size()
	var tree_multimesh: MultiMesh = MultiMesh.new()
	tree_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	tree_multimesh.use_colors = true
	tree_multimesh.mesh = quad
	tree_multimesh.instance_count = tree_tiles.size()
	passive_trees.texture = texture
	passive_trees.multimesh = tree_multimesh

	var instance_index: int = 0
	for state: TreeState in tree_tiles.values():
		state.passive_instance_index = instance_index
		var local_position: Vector2 = to_local(world_map.navigation_tile_to_world(state.tile))
		tree_multimesh.set_instance_transform_2d(
			instance_index,
			Transform2D(0.0, local_position)
		)
		_update_passive_instance(state)
		instance_index += 1


func _update_passive_instance(state: TreeState, pulse: float = 1.0) -> void:
	if passive_trees.multimesh == null or state.passive_instance_index < 0:
		return
	var color: Color = PASSIVE_COLOR
	if state.is_destroyed() or state.representation == TreeState.Representation.ACTIVE:
		color = HIDDEN_COLOR
	elif state.highlighted:
		color = PASSIVE_COLOR.lerp(PASSIVE_HIGHLIGHT_COLOR, pulse)
	passive_trees.multimesh.set_instance_color(state.passive_instance_index, color)


func _update_passive_highlight_pulse() -> void:
	if _highlighted_tiles.is_empty():
		return
	var pulse: float = 0.55 + sin(Time.get_ticks_msec() * 0.008) * 0.35
	for tile: Vector2i in _highlighted_tiles.keys():
		var state: TreeState = get_tree_state(tile)
		if state != null:
			_update_passive_instance(state, pulse)


func _update_regrowth(delta: float) -> void:
	var tree_regrew: bool = false
	for tile: Vector2i in _respawn_remaining.keys():
		var remaining: float = float(_respawn_remaining[tile]) - delta
		if remaining > 0.0:
			_respawn_remaining[tile] = remaining
			continue
		_respawn_remaining.erase(tile)
		var state: TreeState = get_tree_state(tile)
		if state == null or not state.is_destroyed():
			continue
		state.restore()
		world_map.add_navigation_blocker(tile)
		_update_passive_instance(state)
		tree_regrown.emit(tile)
		tree_regrew = true
	if tree_regrew:
		_refresh_activation_targets()


func _get_max_hp(object_id: String) -> float:
	var object_data: Dictionary = Items.objects.get(object_id, {})
	return float(object_data.get("hp", DEFAULT_TREE_HP))


func _on_tree_health_changed(tile: Vector2i, current_hp: float) -> void:
	var state: TreeState = get_tree_state(tile)
	if state != null and not state.is_destroyed():
		state.current_hp = clampf(current_hp, 0.0, state.max_hp)


func _on_tree_destroyed(tile: Vector2i) -> void:
	var state: TreeState = get_tree_state(tile)
	if state == null or state.is_destroyed():
		return
	state.mark_destroyed()
	_active_tiles.erase(tile)
	_queued_tiles.erase(tile)
	world_map.remove_navigation_blocker(tile)
	_update_passive_instance(state)
	if tree_spawn_delay > 0.0:
		_respawn_remaining[tile] = tree_spawn_delay
	tree_destroyed.emit(tile)
