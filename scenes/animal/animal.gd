extends Creature
class_name Animal

const DIRECTIONS: Array[Vector2] = [Vector2.DOWN, Vector2.RIGHT, Vector2.UP, Vector2.LEFT]


func _process(_delta: float) -> void:
	if not _is_server() or _is_dead:
		return
	if not is_instance_valid(target_player):
		resolve_target_player(true)
	if not is_instance_valid(target_player):
		return
	if global_position.distance_to(target_player.global_position) < attackRange:
		face_target()
		tryAttack()


func randomWalk() -> void:
	velocity = DIRECTIONS.pick_random() * speed
	var moving_parts := get_node_or_null("MovingParts") as Node2D
	if moving_parts != null:
		moving_parts.look_at(velocity)
	move_and_slide()


func _release_spawn_slot() -> void:
	if is_instance_valid(spawner) and spawner.has_method("decreasePlayerAnimalCount"):
		spawner.call("decreasePlayerAnimalCount", targetPlayerId)
