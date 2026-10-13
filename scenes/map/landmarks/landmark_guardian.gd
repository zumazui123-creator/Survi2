extends Enemy
class_name LandmarkGuardian

@export_range(2.0, 20.0, 0.5) var guard_radius_tiles: float = 7.0

var home_position: Vector2


func _ready() -> void:
	if home_position == Vector2.ZERO:
		home_position = global_position
	super()


func configure_guard(value: Vector2) -> void:
	home_position = value


func _update_target() -> void:
	var maximum_distance: float = guard_radius_tiles * float(Constants.TILE_SIZE)
	var maximum_distance_squared: float = maximum_distance * maximum_distance
	if is_instance_valid(target_player) \
			and home_position.distance_squared_to(target_player.global_position) \
			<= maximum_distance_squared:
		return
	target_player = null
	var players_root: Node2D = get_tree().get_first_node_in_group(
		"players_root"
	) as Node2D
	if players_root == null:
		return
	var nearest_distance_squared: float = INF
	for child: Node in players_root.get_children():
		var player: CharacterBody2D = child as CharacterBody2D
		if player == null:
			continue
		var distance_squared: float = home_position.distance_squared_to(
			player.global_position
		)
		if distance_squared <= maximum_distance_squared \
				and distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			target_player = player
			targetPlayerId = int(str(player.name))


func _should_despawn_while_idle() -> bool:
	return false
