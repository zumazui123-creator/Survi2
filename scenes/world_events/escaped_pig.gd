extends Animal
class_name EscapedPig

@export_range(0.5, 6.0, 0.1) var minimum_direction_time: float = 1.0
@export_range(0.5, 6.0, 0.1) var maximum_direction_time: float = 2.5

@onready var world_map: Map = get_tree().get_first_node_in_group("world_map") as Map
var _wander_direction: Vector2 = Vector2.ZERO
var _direction_remaining: float = 0.0


func _process(delta: float) -> void:
	if not _is_server() or _is_dead or not is_instance_valid(world_map):
		return
	_direction_remaining -= delta
	if _direction_remaining <= 0.0:
		_choose_direction()
	var next_position: Vector2 = global_position + _wander_direction * speed * delta
	var next_tile: Vector2i = world_map.world_to_navigation_tile(next_position)
	if not world_map.is_navigation_tile_walkable(next_tile, true, get_instance_id()):
		_wander_direction = Vector2.ZERO
		_direction_remaining = 0.0
		velocity = Vector2.ZERO
		return
	velocity = _wander_direction * speed
	var moving_parts: Node2D = get_node_or_null("MovingParts") as Node2D
	if moving_parts != null and not velocity.is_zero_approx():
		moving_parts.look_at(velocity)
	move_and_slide()


func _choose_direction() -> void:
	var directions: Array[Vector2] = [
		Vector2.ZERO,
		Vector2.DOWN,
		Vector2.RIGHT,
		Vector2.UP,
		Vector2.LEFT,
	]
	_wander_direction = directions.pick_random()
	_direction_remaining = randf_range(
		minf(minimum_direction_time, maximum_direction_time),
		maxf(minimum_direction_time, maximum_direction_time)
	)


func _release_spawn_slot() -> void:
	pass
