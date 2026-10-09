extends Node2D
class_name EnemyNavigation

signal path_changed(path: Array[Vector2i])
signal path_failed()
signal destination_reached()

@export_range(0.05, 2.0, 0.05) var repath_interval := 0.25
@export_range(0.5, 16.0, 0.5) var tile_reached_distance := 2.0
@export_range(0.05, 2.0, 0.05) var reservation_retry_interval := 0.35

var current_path: Array[Vector2i] = []
var path_index := 0
var target: Node2D
var target_tile := Vector2i.ZERO
var last_target_tile := Vector2i.ZERO
var has_target_tile := false
var destination_tile := Vector2i.ZERO
var has_destination := false
var repath_timer := 0.0
var last_navigation_revision := -1
var path_active := false

var _enemy: CharacterBody2D
var _world_map: Map
var _actor_id := -1
var _occupied_tile := Vector2i.ZERO
var _has_occupancy := false
var _reserved_tile := Vector2i.ZERO
var _has_reservation := false
var _blocked_time := 0.0
var _desired_range_tiles := 1
var _force_repath := true
var _repath_jitter := 0.0
var _last_world_position := Vector2.INF
var _stuck_time := 0.0


func _ready() -> void:
	_enemy = get_parent() as CharacterBody2D
	_actor_id = _enemy.get_instance_id() if _enemy else get_instance_id()
	_repath_jitter = randf_range(0.0, repath_interval * 0.35)
	_resolve_map()
	set_process(true)


func _process(_delta: float) -> void:
	if is_instance_valid(_world_map) and _world_map.debug_navigation:
		queue_redraw()


func set_target(value: Node2D) -> void:
	if target == value:
		return
	target = value
	has_target_tile = false
	_force_repath = true


func clear_target() -> void:
	target = null
	has_target_tile = false
	cancel_path()


func update_navigation(delta: float, desired_range_tiles := 1) -> Vector2:
	if not multiplayer.is_server() or not is_instance_valid(target):
		return Vector2.INF
	if not _resolve_map() or not _world_map.astar_ready:
		return Vector2.INF
	if not _ensure_occupancy():
		return Vector2.INF
	_update_stuck_state(delta)

	repath_timer = maxf(repath_timer - delta, 0.0)
	var new_target_tile := _world_map.world_to_navigation_tile(target.global_position)
	if not has_target_tile or new_target_tile != target_tile:
		last_target_tile = target_tile
		target_tile = new_target_tile
		has_target_tile = true
		_force_repath = true
	if _desired_range_tiles != desired_range_tiles:
		_desired_range_tiles = maxi(desired_range_tiles, 1)
		_force_repath = true

	if needs_repath():
		request_path(_force_repath)
	if not path_active:
		return Vector2.INF

	return _advance_path(delta)


func needs_repath() -> bool:
	if _force_repath:
		return true
	if last_navigation_revision != _world_map.navigation_revision:
		return true
	if current_path.is_empty() or path_index >= current_path.size():
		return repath_timer <= 0.0
	var next_tile := current_path[path_index]
	return not _world_map.is_navigation_tile_walkable(next_tile)


func request_path(force := false) -> bool:
	if not _resolve_map() or not _world_map.astar_ready or not _ensure_occupancy():
		return false
	if not force and repath_timer > 0.0:
		return path_active

	_world_map.cancel_navigation_step(_actor_id)
	_world_map.release_navigation_destination(_actor_id)
	_has_reservation = false
	current_path.clear()
	path_index = 0
	path_active = false
	has_destination = false
	_force_repath = false
	repath_timer = repath_interval + _repath_jitter
	last_navigation_revision = _world_map.navigation_revision

	destination_tile = _world_map.get_attack_destination(
		_occupied_tile,
		target_tile,
		_actor_id,
		_desired_range_tiles
	)
	if not _world_map.is_navigation_tile_walkable(destination_tile):
		path_failed.emit()
		return false
	if not _world_map.try_claim_navigation_destination(destination_tile, _actor_id):
		path_failed.emit()
		return false
	has_destination = true
	current_path = _world_map.get_navigation_path_avoiding_actors(
		_occupied_tile,
		destination_tile,
		_actor_id
	)
	if current_path.is_empty():
		_world_map.release_navigation_destination(_actor_id)
		has_destination = false
		path_failed.emit()
		return false

	path_index = 1 if current_path[0] == _occupied_tile else 0
	path_active = path_index < current_path.size()
	path_changed.emit(current_path)
	if not path_active:
		destination_reached.emit()
	return true


func get_next_tile() -> Vector2i:
	if not path_active or path_index >= current_path.size():
		return _occupied_tile
	return current_path[path_index]


func get_next_world_position() -> Vector2:
	if not path_active or not is_instance_valid(_world_map):
		return Vector2.INF
	return _world_map.navigation_tile_to_world(get_next_tile())


func notify_tile_reached(tile: Vector2i) -> void:
	if _has_reservation:
		_world_map.commit_navigation_step(_actor_id, tile)
	else:
		_world_map.register_navigation_actor(_actor_id, tile)
	_has_reservation = false
	_occupied_tile = tile
	_has_occupancy = true
	path_index += 1
	_blocked_time = 0.0
	if path_index >= current_path.size():
		path_active = false
		destination_reached.emit()


func cancel_path() -> void:
	if is_instance_valid(_world_map):
		_world_map.cancel_navigation_step(_actor_id)
		_world_map.release_navigation_destination(_actor_id)
	_has_reservation = false
	current_path.clear()
	path_index = 0
	path_active = false
	has_destination = false
	_blocked_time = 0.0
	_stuck_time = 0.0


func stop_at_current_position() -> void:
	cancel_path()
	if not _resolve_map() or not is_instance_valid(_enemy):
		return
	_world_map.release_navigation_actor(_actor_id)
	_occupied_tile = _world_map.world_to_navigation_tile(_enemy.global_position)
	_has_occupancy = _world_map.register_navigation_actor(_actor_id, _occupied_tile)


func synchronize_after_external_move() -> void:
	if not _resolve_map() or not is_instance_valid(_enemy):
		return
	_world_map.release_navigation_actor(_actor_id)
	_has_occupancy = false
	_has_reservation = false
	current_path.clear()
	path_index = 0
	path_active = false
	has_destination = false
	_occupied_tile = _world_map.world_to_navigation_tile(_enemy.global_position)
	_has_occupancy = _world_map.register_navigation_actor(_actor_id, _occupied_tile)
	_force_repath = true
	repath_timer = 0.0
	_last_world_position = _enemy.global_position
	_stuck_time = 0.0


func shutdown() -> void:
	if is_instance_valid(_world_map):
		_world_map.release_navigation_actor(_actor_id)
	_has_occupancy = false
	_has_reservation = false
	cancel_path()


func get_debug_path_world() -> PackedVector2Array:
	var points := PackedVector2Array()
	if not is_instance_valid(_world_map):
		return points
	for tile in current_path:
		points.append(_world_map.navigation_tile_to_world(tile))
	return points


func _draw() -> void:
	if not is_instance_valid(_world_map) or not _world_map.debug_navigation:
		return
	var local_points := PackedVector2Array()
	for world_point in get_debug_path_world():
		local_points.append(to_local(world_point))
	if local_points.size() >= 2:
		draw_polyline(local_points, Color(1.0, 0.65, 0.1, 0.9), 2.0)
	if has_destination:
		draw_circle(to_local(_world_map.navigation_tile_to_world(destination_tile)), 4.0, Color.RED)


func _advance_path(delta: float) -> Vector2:
	var next_tile := get_next_tile()
	var next_position := _world_map.navigation_tile_to_world(next_tile)
	if _enemy.global_position.distance_to(next_position) <= tile_reached_distance:
		_enemy.global_position = next_position
		notify_tile_reached(next_tile)
		if not path_active:
			return Vector2.INF
		next_tile = get_next_tile()
		next_position = _world_map.navigation_tile_to_world(next_tile)

	if not _has_reservation:
		if not _world_map.try_reserve_navigation_step(
				_occupied_tile, next_tile, _actor_id):
			_blocked_time += delta
			if _blocked_time >= reservation_retry_interval:
				_force_repath = true
				repath_timer = 0.0
				_blocked_time = 0.0
			return Vector2.INF
		_reserved_tile = next_tile
		_has_reservation = true
		_blocked_time = 0.0
	return next_position


func _ensure_occupancy() -> bool:
	if _has_occupancy:
		return true
	_occupied_tile = _world_map.world_to_navigation_tile(_enemy.global_position)
	_has_occupancy = _world_map.register_navigation_actor(_actor_id, _occupied_tile)
	return _has_occupancy


func _update_stuck_state(delta: float) -> void:
	if not path_active:
		_last_world_position = _enemy.global_position
		_stuck_time = 0.0
		return
	if _last_world_position.is_finite() \
			and _enemy.global_position.distance_squared_to(_last_world_position) < 0.0625:
		_stuck_time += delta
	else:
		_stuck_time = 0.0
	_last_world_position = _enemy.global_position
	if _stuck_time >= maxf(reservation_retry_interval * 2.0, 0.75):
		_world_map.cancel_navigation_step(_actor_id)
		_has_reservation = false
		_force_repath = true
		repath_timer = 0.0
		_stuck_time = 0.0


func _resolve_map() -> bool:
	if is_instance_valid(_world_map):
		return true
	_world_map = get_tree().get_first_node_in_group("world_map") as Map
	return _world_map != null


func _exit_tree() -> void:
	shutdown()
