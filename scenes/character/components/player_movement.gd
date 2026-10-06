extends Node

signal speed_changed(value: float)
signal tile_step_finished(map_position: Vector2i)

@export_group("References")
@export var player: CharacterBody2D
@onready var world_map: Map = get_tree().get_first_node_in_group("world_map")

const default_move_speed_factor : float = 2.5
var move_speed_factor : float = default_move_speed_factor
var current_map_position : Vector2i
var direction = Vector2.ZERO
var _pixels_moved: int = 0
var is_speed_boost_active := false
var path_line : Line2D
var _base_move_speed_factor := default_move_speed_factor
var _speed_boost_multiplier := 1.0
var _code_speed_multiplier := 1.0
var _code_input_active := false

func _ready():
	speed_changed.emit(move_speed_factor)
	if path_line:
		path_line.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])

func is_moving() -> bool:
	return direction != Vector2.ZERO

func input():
	if is_moving(): return
	if _code_input_active: return
	if Input.is_action_pressed("walkRight"):
		direction = Vector2(1, 0)
	elif Input.is_action_pressed("walkLeft"):
		direction = Vector2(-1, 0)
	elif Input.is_action_pressed("walkUp"):
		direction = Vector2(0, -1)
	elif Input.is_action_pressed("walkDown"):
		direction = Vector2(0, 1)

	if direction != Vector2.ZERO and path_line:
		path_line.points = PackedVector2Array([Vector2.ZERO, direction * Constants.TILE_SIZE])

func tile_move() -> Vector2:
	if not is_moving():
		return Vector2.ZERO

	_pixels_moved += 1
	player.velocity = direction * move_speed_factor
	player.move_and_collide(player.velocity)

	if _pixels_moved >= Constants.TILE_SIZE/move_speed_factor:
		direction = Vector2.ZERO
		_pixels_moved = 0
		if path_line:
			path_line.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])

		current_map_position = world_map.tile_map.local_to_map(player.position)
		snap_to_tiles_position()
		player.act = ""
		call_deferred("_emit_tile_step_finished", current_map_position)

	player.animation.animate_player(direction)
	return direction

func _emit_tile_step_finished(map_position: Vector2i) -> void:
	tile_step_finished.emit(map_position)

func snap_to_tiles_position():
	var snap_position = world_map.tile_map.map_to_local(current_map_position)
	player.position = snap_position

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

func set_code_input_active(value: bool) -> void:
	_code_input_active = value

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
	if is_moving() or not Strings.direction_map.has(input_action):
		return false

	direction = Vector2(Strings.direction_map[input_action])
	if path_line:
		path_line.points = PackedVector2Array([Vector2.ZERO, direction * Constants.TILE_SIZE])
	return true

func set_speed( player_speed : float):
	_base_move_speed_factor = maxf(_base_move_speed_factor + player_speed, 0.1)
	_update_move_speed()

func _on_speed_plus_pressed() -> void:
	set_speed(0.2)

func _on_speed_minus_pressed() -> void:
	set_speed(-0.2)
