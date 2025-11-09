extends Node

var player: CharacterBody2D

var direction = Vector2.ZERO
var _pixels_moved: int = 0
var move_speed_factor = 3

func _ready():
	player = get_parent()

func is_moving() -> bool:
	return direction != Vector2.ZERO

func input():
	if is_moving(): return
	if Input.is_action_pressed("walkRight"):
		direction = Vector2(1, 0)
	elif Input.is_action_pressed("walkLeft"):
		direction = Vector2(-1, 0)
	elif Input.is_action_pressed("walkUp"):
		direction = Vector2(0, -1)
	elif Input.is_action_pressed("walkDown"):
		direction = Vector2(0, 1)

func tile_move():
	if not is_moving():
		return

	_pixels_moved += 1
	player.velocity = direction * move_speed_factor
	player.move_and_collide(player.velocity)

	if _pixels_moved >= Constants.TILE_SIZE/move_speed_factor:
		direction = Vector2.ZERO
		_pixels_moved = 0

		player.current_map_position = Multihelper.map.tile_map.local_to_map( player.position )
		snap_to_tiles_position()
		player.kiBrain.send_ki_obs()
		player.act = ""
	
	var player_animation = player.get_node("PlayerAnimation")
	if player_animation:
		player_animation.animate_player(direction)


func snap_to_tiles_position():
	var snap_position = Multihelper.map.tile_map.map_to_local( player.current_map_position )
	player.position = snap_position

var is_speed_boost_active := false

func apply_speed_boost(multiplier, duration):
	if is_speed_boost_active:
		return # Don't stack speed boosts

	is_speed_boost_active = true
	move_speed_factor = player.default_move_speed_factor * multiplier

	var timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(_on_speed_boost_timeout)
	add_child(timer)
	timer.start()

func _on_speed_boost_timeout():
	move_speed_factor = player.default_move_speed_factor
	is_speed_boost_active = false

# GODOT Server
var last_angle = 0.0 # für godot server nötig
func action(vel, angle, doingAction):
	if vel != Vector2.ZERO:
		last_angle = vel.angle()
	angle = last_angle
	moveProcess(vel, angle, doingAction)

	var inputData = {
		"vel": vel,
		"angle": angle,
		"doingAction": doingAction
	}
	player.sendInputstwo.rpc_id(1, inputData)
	player.sendPos.rpc(player.position)

func moveProcess(vel, angle, doingAction):
	player.velocity = vel
	if player.velocity != Vector2.ZERO:
		player.move_and_slide()
	player.get_node("MovingParts").rotation = angle
	var player_animation = player.get_node("PlayerAnimation")
	if player_animation:
		player_animation.handleAnims(vel,doingAction)

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