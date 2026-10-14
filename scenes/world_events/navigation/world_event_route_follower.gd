extends Node
class_name WorldEventRouteFollower

signal route_started(path: Array[Vector2i])
signal route_finished(destination_tile: Vector2i)
signal route_blocked(destination_tile: Vector2i)

@export_range(10.0, 300.0, 1.0) var movement_speed: float = 55.0
@export_range(0.5, 16.0, 0.5) var tile_reached_distance: float = 2.0
@export_range(0.1, 5.0, 0.1) var replan_interval: float = 0.75

var current_path: Array[Vector2i] = []
var destination_tile: Vector2i = Vector2i.ZERO

var _actor: CharacterBody2D
var _world_map: Map
var _navigation_graph: WorldEventNavigationGraph
var _actor_id: int = -1
var _occupied_tile: Vector2i = Vector2i.ZERO
var _path_index: int = 0
var _start_delay_remaining: float = 0.0
var _replan_remaining: float = 0.0
var _blocked_time: float = 0.0
var _stuck_time: float = 0.0
var _last_actor_position: Vector2 = Vector2.INF
var _has_occupancy: bool = false
var _has_reservation: bool = false
var _active: bool = false


func configure_route(
		actor: CharacterBody2D,
		world_map: Map,
		navigation_graph: WorldEventNavigationGraph,
		new_destination_tile: Vector2i,
		start_delay: float = 0.0
	) -> void:
	shutdown()
	_actor = actor
	_world_map = world_map
	_navigation_graph = navigation_graph
	destination_tile = new_destination_tile
	_actor_id = actor.get_instance_id() if is_instance_valid(actor) else -1
	_start_delay_remaining = maxf(start_delay, 0.0)
	_replan_remaining = 0.0
	_active = is_instance_valid(_actor) \
			and is_instance_valid(_world_map) \
			and _navigation_graph != null
	set_physics_process(_active)


func shutdown() -> void:
	if is_instance_valid(_actor):
		_actor.velocity = Vector2.ZERO
	if is_instance_valid(_world_map) and _actor_id >= 0:
		_world_map.release_navigation_actor(_actor_id)
	current_path.clear()
	_path_index = 0
	_has_occupancy = false
	_has_reservation = false
	_blocked_time = 0.0
	_stuck_time = 0.0
	_active = false
	set_physics_process(false)


func _ready() -> void:
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or not _active:
		return
	if not is_instance_valid(_actor) or not is_instance_valid(_world_map):
		shutdown()
		return
	if not _ensure_occupancy():
		return
	if _start_delay_remaining > 0.0:
		_start_delay_remaining = maxf(_start_delay_remaining - delta, 0.0)
		return

	_replan_remaining = maxf(_replan_remaining - delta, 0.0)
	if current_path.is_empty() or _path_index >= current_path.size():
		if _replan_remaining <= 0.0 and not _request_path():
			_replan_remaining = replan_interval
			route_blocked.emit(destination_tile)
		return

	var next_tile: Vector2i = current_path[_path_index]
	if not _world_map.is_navigation_tile_walkable(next_tile):
		_cancel_reserved_step()
		current_path.clear()
		return
	var next_position: Vector2 = _world_map.navigation_tile_to_world(next_tile)
	if _actor.global_position.distance_to(next_position) <= tile_reached_distance:
		_reach_tile(next_tile, next_position)
		if _path_index >= current_path.size():
			_finish_route()
		return

	if not _has_reservation:
		if not _world_map.try_reserve_navigation_step(
				_occupied_tile,
				next_tile,
				_actor_id
			):
			_blocked_time += delta
			if _blocked_time >= replan_interval:
				current_path.clear()
				_blocked_time = 0.0
			return
		_has_reservation = true
		_blocked_time = 0.0

	var direction: Vector2 = _actor.global_position.direction_to(next_position)
	_actor.velocity = direction * movement_speed
	var position_before_move: Vector2 = _actor.global_position
	_actor.move_and_slide()
	_update_stuck_state(delta, position_before_move)


func _request_path() -> bool:
	_cancel_reserved_step()
	if not _world_map.try_claim_navigation_destination(destination_tile, _actor_id):
		return false
	current_path = _navigation_graph.find_path(_occupied_tile, destination_tile)
	_path_index = 0
	if current_path.is_empty():
		_world_map.release_navigation_destination(_actor_id)
		return false
	if current_path[0] == _occupied_tile:
		_path_index = 1
	if _path_index >= current_path.size():
		_finish_route()
		return true
	route_started.emit(current_path)
	return true


func _ensure_occupancy() -> bool:
	if _has_occupancy:
		return true
	_occupied_tile = _world_map.world_to_navigation_tile(_actor.global_position)
	_has_occupancy = _world_map.register_navigation_actor(_actor_id, _occupied_tile)
	return _has_occupancy


func _reach_tile(tile: Vector2i, world_position: Vector2) -> void:
	_actor.global_position = world_position
	_actor.velocity = Vector2.ZERO
	if _has_reservation:
		_world_map.commit_navigation_step(_actor_id, tile)
	else:
		_world_map.register_navigation_actor(_actor_id, tile)
	_occupied_tile = tile
	_has_reservation = false
	_path_index += 1
	_stuck_time = 0.0
	_last_actor_position = _actor.global_position


func _finish_route() -> void:
	var reached_destination: Vector2i = destination_tile
	shutdown()
	route_finished.emit(reached_destination)


func _cancel_reserved_step() -> void:
	if is_instance_valid(_world_map) and _actor_id >= 0:
		_world_map.cancel_navigation_step(_actor_id)
	_has_reservation = false
	if is_instance_valid(_actor):
		_actor.velocity = Vector2.ZERO


func _update_stuck_state(delta: float, position_before_move: Vector2) -> void:
	if _actor.global_position.distance_squared_to(position_before_move) <= 0.01:
		_stuck_time += delta
	else:
		_stuck_time = 0.0
	_last_actor_position = _actor.global_position
	if _stuck_time < maxf(replan_interval * 2.0, 1.0):
		return
	_cancel_reserved_step()
	current_path.clear()
	_stuck_time = 0.0


func _exit_tree() -> void:
	shutdown()
