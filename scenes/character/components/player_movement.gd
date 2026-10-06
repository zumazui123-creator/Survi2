extends Node
class_name PlayerMovement

signal speed_changed(value: float)
signal tile_step_finished(map_position: Vector2i)
signal tile_step_blocked(map_position: Vector2i, attempted_position: Vector2i)
signal tile_step_resolved(map_position: Vector2i, succeeded: bool)
signal control_mode_changed(mode: int)

enum ControlMode {
	MANUAL,
	CODE,
	AI,
}

@export_group("References")
@export var player: CharacterBody2D
@onready var world_map: Map = get_tree().get_first_node_in_group("world_map")

const default_move_speed_factor : float = 2.5
const MOVE_SPEED_SCALE := 60.0
const TARGET_EPSILON := 0.01

var move_speed_factor : float = default_move_speed_factor
var current_map_position : Vector2i
var direction := Vector2.ZERO
var is_speed_boost_active := false
var path_line : Line2D
var _base_move_speed_factor := default_move_speed_factor
var _speed_boost_multiplier := 1.0
var _code_speed_multiplier := 1.0
var control_mode := ControlMode.MANUAL
var _grid_position_initialized := false
var _step_start_global_position := Vector2.ZERO
var _step_target_global_position := Vector2.ZERO
var _step_target_map_position := Vector2i.ZERO


func _ready() -> void:
	synchronize_to_player_position()
	speed_changed.emit(move_speed_factor)
	if path_line:
		path_line.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])


func is_moving() -> bool:
	return direction != Vector2.ZERO


func input() -> void:
	if is_moving() or control_mode != ControlMode.MANUAL:
		return

	var input_direction := Vector2i.ZERO
	if Input.is_action_just_pressed("walkRight"):
		input_direction = Vector2i.RIGHT
	elif Input.is_action_just_pressed("walkLeft"):
		input_direction = Vector2i.LEFT
	elif Input.is_action_just_pressed("walkUp"):
		input_direction = Vector2i.UP
	elif Input.is_action_just_pressed("walkDown"):
		input_direction = Vector2i.DOWN

	if input_direction != Vector2i.ZERO:
		request_tile_step(input_direction, ControlMode.MANUAL)


func tile_move(delta: float) -> Vector2:
	if not is_moving():
		player.velocity = Vector2.ZERO
		return Vector2.ZERO

	var movement_direction := direction
	var target_delta := _step_target_global_position - player.global_position
	var remaining_distance := target_delta.length()
	if remaining_distance <= TARGET_EPSILON:
		_finish_tile_step(true)
		return movement_direction

	var pixels_per_second := move_speed_factor * MOVE_SPEED_SCALE
	var motion_distance := minf(pixels_per_second * delta, remaining_distance)
	player.velocity = movement_direction * pixels_per_second
	var collision := player.move_and_collide(target_delta.normalized() * motion_distance)
	if collision != null:
		_finish_tile_step(false)
		return Vector2.ZERO

	if player.global_position.distance_to(_step_target_global_position) <= TARGET_EPSILON:
		_finish_tile_step(true)
	else:
		player.animation.animate_player(movement_direction)
	return movement_direction


func synchronize_to_player_position(snap_to_center := false) -> bool:
	if not is_instance_valid(world_map):
		world_map = get_tree().get_first_node_in_group("world_map") as Map
	if not is_instance_valid(world_map):
		return false

	current_map_position = world_map.world_to_navigation_tile(player.global_position)
	_step_start_global_position = world_map.navigation_tile_to_world(current_map_position)
	_step_target_global_position = _step_start_global_position
	_step_target_map_position = current_map_position
	_grid_position_initialized = true
	direction = Vector2.ZERO
	player.velocity = Vector2.ZERO
	if snap_to_center:
		player.global_position = _step_start_global_position
	_clear_path_line()
	return true


func snap_to_tiles_position() -> void:
	synchronize_to_player_position(true)


func _start_tile_step(tile_direction: Vector2i) -> bool:
	if is_moving() or abs(tile_direction.x) + abs(tile_direction.y) != 1:
		return false
	if not _grid_position_initialized and not synchronize_to_player_position(true):
		return false

	var target_map_position := current_map_position + tile_direction
	if not world_map.is_navigation_tile_walkable(target_map_position):
		return false

	_step_start_global_position = world_map.navigation_tile_to_world(current_map_position)
	_step_target_global_position = world_map.navigation_tile_to_world(target_map_position)
	_step_target_map_position = target_map_position
	player.global_position = _step_start_global_position
	direction = Vector2(tile_direction)
	if path_line:
		path_line.points = PackedVector2Array([
			Vector2.ZERO,
			_step_target_global_position - player.global_position,
		])
	return true


func _finish_tile_step(succeeded: bool) -> void:
	var attempted_position := _step_target_map_position
	if succeeded:
		player.global_position = _step_target_global_position
		current_map_position = _step_target_map_position
	else:
		player.global_position = _step_start_global_position

	direction = Vector2.ZERO
	player.velocity = Vector2.ZERO
	player.act = ""
	player.animation.animate_player(Vector2.ZERO)
	_clear_path_line()
	call_deferred("_emit_tile_step_result", current_map_position, succeeded, attempted_position)


func _emit_tile_step_result(
		map_position: Vector2i,
		succeeded: bool,
		attempted_position: Vector2i
	) -> void:
	if succeeded:
		tile_step_finished.emit(map_position)
	else:
		tile_step_blocked.emit(map_position, attempted_position)
	tile_step_resolved.emit(map_position, succeeded)


func _clear_path_line() -> void:
	if path_line:
		path_line.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])

func apply_speed_boost(multiplier, duration):
	if is_speed_boost_active:
		return # Don't stack speed boosts

	is_speed_boost_active = true
	_speed_boost_multiplier = multiplier
	_update_move_speed()

	var timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(_on_speed_boost_timeout)
	timer.timeout.connect(timer.queue_free)
	add_child(timer)
	timer.start()

func _on_speed_boost_timeout():
	_speed_boost_multiplier = 1.0
	is_speed_boost_active = false
	_update_move_speed()

func apply_code_speed_bonus(bonus_multiplier: float):
	_code_speed_multiplier = bonus_multiplier
	_update_move_speed()
	print("Code Speed Bonus applied: ", move_speed_factor)

func reset_code_speed_bonus():
	_code_speed_multiplier = 1.0
	_update_move_speed()
	print("Code Speed Bonus reset: ", move_speed_factor)

func acquire_control(requested_mode: int) -> bool:
	if requested_mode == ControlMode.MANUAL:
		return control_mode == ControlMode.MANUAL
	if control_mode == requested_mode:
		return true
	if control_mode != ControlMode.MANUAL or is_moving():
		return false
	control_mode = requested_mode
	control_mode_changed.emit(control_mode)
	return true


func release_control(requested_mode: int) -> bool:
	if requested_mode == ControlMode.MANUAL or control_mode != requested_mode:
		return false
	control_mode = ControlMode.MANUAL
	control_mode_changed.emit(control_mode)
	return true


func set_code_input_active(value: bool) -> bool:
	if value:
		return acquire_control(ControlMode.CODE)
	if control_mode == ControlMode.CODE:
		return release_control(ControlMode.CODE)
	return true

func _update_move_speed() -> void:
	move_speed_factor = _base_move_speed_factor * _speed_boost_multiplier * _code_speed_multiplier
	speed_changed.emit(move_speed_factor)

# GODOT Server
#var last_angle = 0.0 # für godot server nötig
#func action(vel, angle, doingAction):
	#if vel != Vector2.ZERO:
		#last_angle = vel.angle()
	##angle = last_angle
	#moveProcess(vel, angle, doingAction)

	#var inputData = {
		#"vel": vel,
		#"angle": angle,
		#"doingAction": doingAction
	#}
	#player.sendInputstwo.rpc_id(1, inputData)
	#player.sendPos.rpc(player.position)

#func moveProcess(vel, angle, doingAction):
	#player.velocity = vel
	#if player.velocity != Vector2.ZERO:
		#player.move_and_slide()
	#player.get_node("MovingParts").rotation = angle
	#if player.animation:
		#player.animation.handleAnims(vel,doingAction)

func request_code_step(input_action: String) -> bool:
	if not Strings.direction_map.has(input_action):
		return false

	return request_tile_step(
		Vector2i(Strings.direction_map[input_action]),
		ControlMode.CODE
	)


func request_tile_step(tile_direction: Vector2i, requested_mode: int) -> bool:
	if requested_mode != control_mode:
		return false
	return _start_tile_step(tile_direction)

func set_speed( player_speed : float):
	_base_move_speed_factor = maxf(_base_move_speed_factor + player_speed, 0.1)
	_update_move_speed()

func _on_speed_plus_pressed() -> void:
	set_speed(0.2)

func _on_speed_minus_pressed() -> void:
	set_speed(-0.2)
