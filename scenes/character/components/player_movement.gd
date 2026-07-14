extends Node

@export_group("References")
@export var player: CharacterBody2D

@onready var speedLabel = $"../CodeLayer/Code/TabContainer/KI Playground/VBoxContainer/GameSetContainer/HBoxContainer2/Speed"

const default_move_speed_factor : float = 2.5
var move_speed_factor : float = default_move_speed_factor
var current_map_position : Vector2i
var direction = Vector2.ZERO
var _pixels_moved: int = 0
var is_speed_boost_active := false
var path_line : Line2D

func _ready():
	
	speedLabel.text = str(move_speed_factor)
	if path_line:
		path_line.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])

func is_moving() -> bool:
	return direction != Vector2.ZERO

func input():
	if is_moving(): return
	if Multihelper.is_stopped: return
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

		current_map_position = Multihelper.map.tile_map.local_to_map( player.position )
		snap_to_tiles_position()
		player.act = ""

	player.animation.animate_player(direction)
	return direction

func snap_to_tiles_position():
	var snap_position = Multihelper.map.tile_map.map_to_local( current_map_position )
	player.position = snap_position

func apply_speed_boost(multiplier, duration):
	if is_speed_boost_active:
		return # Don't stack speed boosts

	is_speed_boost_active = true
	move_speed_factor = default_move_speed_factor * multiplier

	var timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(_on_speed_boost_timeout)
	add_child(timer)
	timer.start()

func _on_speed_boost_timeout():
	move_speed_factor = default_move_speed_factor
	is_speed_boost_active = false

func apply_code_speed_bonus(bonus_multiplier: float):
	move_speed_factor = default_move_speed_factor * bonus_multiplier
	print("Code Speed Bonus applied: ", move_speed_factor)

func reset_code_speed_bonus():
	move_speed_factor = default_move_speed_factor
	print("Code Speed Bonus reset: ", move_speed_factor)

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

func press_action(inp_action : String):
	if "walk" in inp_action:
		if inp_action == "walkRight":
			direction = Vector2(1, 0)
		elif inp_action == "walkLeft":
			direction = Vector2(-1, 0)
		elif inp_action == "walkUp":
			direction = Vector2(0, -1)
		elif inp_action == "walkDown":
			direction = Vector2(0, 1)

func set_speed( player_speed : float):
	move_speed_factor += player_speed
	speedLabel.text = str(player.move_speed_factor)

func _on_speed_plus_pressed() -> void:
	set_speed(0.2)

func _on_speed_minus_pressed() -> void:
	set_speed(-0.2)
