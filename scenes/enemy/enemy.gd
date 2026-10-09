extends Creature
class_name Enemy

enum AIState { IDLE, CHASE, ATTACK, BLOCKED, DEAD }

@export var ai_state: AIState = AIState.IDLE

@onready var navigation: EnemyNavigation = $EnemyNavigation

func _physics_process(delta: float) -> void:
	if not _is_server() or _is_dead:
		return
	if bool(get_meta(&"jump_pad_airborne", false)):
		velocity = Vector2.ZERO
		return
	_update_target()
	if not is_instance_valid(target_player):
		velocity = Vector2.ZERO
		ai_state = AIState.IDLE
		navigation.clear_target()
		if _should_despawn_while_idle() and not GameTime.is_night_time():
			die(false)
		return

	face_target()
	if global_position.distance_to(target_player.global_position) <= attackRange:
		if ai_state != AIState.ATTACK:
			navigation.stop_at_current_position()
		velocity = Vector2.ZERO
		ai_state = AIState.ATTACK
		tryAttack()
		return

	ai_state = AIState.CHASE
	navigation.set_target(target_player)
	var desired_range_tiles: int = maxi(1, floori(attackRange / Constants.TILE_SIZE))
	var next_position: Vector2 = navigation.update_navigation(delta, desired_range_tiles)
	if not next_position.is_finite():
		velocity = Vector2.ZERO
		ai_state = AIState.BLOCKED
		return
	move_towards_position(next_position)

func rotateToTarget() -> void:
	face_target()

func move_towards_position(next_position: Vector2) -> void:
	var movement_direction: Vector2 = (next_position - global_position).normalized()
	velocity = movement_direction * speed
	move_and_slide()


## Extension point for enemies with conditional hostility, such as village
## residents. Normal enemies keep targeting the nearest available player.
func _update_target() -> void:
	if not is_instance_valid(target_player):
		resolve_target_player(true)


func _should_despawn_while_idle() -> bool:
	return true

func _before_death() -> void:
	ai_state = AIState.DEAD
	navigation.shutdown()


func _release_spawn_slot() -> void:
	if is_instance_valid(spawner) and spawner.has_method("decreasePlayerEnemyCount"):
		spawner.call("decreasePlayerEnemyCount", targetPlayerId)


func _can_drop_loot() -> bool:
	return GameTime.is_night_time()
