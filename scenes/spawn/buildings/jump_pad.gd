extends BuildingEntity
class_name JumpPadBuilding

const COOLDOWN_META: StringName = &"jump_pad_cooldown_until"
const AIRBORNE_META: StringName = &"jump_pad_airborne"

@export_range(1, 20, 1) var maximum_launch_tiles: int = 10
@export_range(0.1, 2.0, 0.05) var launch_duration: float = 0.45
@export_range(100, 5000, 50) var retrigger_cooldown_ms: int = 900

@onready var launch_area: Area2D = $LaunchArea
@onready var world_map: Map = get_tree().get_first_node_in_group("world_map") as Map


func _ready() -> void:
	super()
	if not launch_area.body_entered.is_connected(_on_launch_area_body_entered):
		launch_area.body_entered.connect(_on_launch_area_body_entered)


func _on_launch_area_body_entered(body: Node2D) -> void:
	if not multiplayer.is_server() or not _can_launch(body):
		return
	var direction: Vector2i = _get_launch_direction(body)
	if direction == Vector2i.ZERO:
		return
	var landing_result: Dictionary = _find_landing_tile(body, direction)
	if not bool(landing_result.get("found", false)):
		return
	var landing_tile: Vector2i = landing_result.get("tile", Vector2i.ZERO)
	body.set_meta(
		COOLDOWN_META,
		Time.get_ticks_msec() + retrigger_cooldown_ms
	)
	var landing_position: Vector2 = world_map.navigation_tile_to_world(landing_tile)
	if body.is_in_group(Strings.GROUP_PLAYER):
		body.rpc("launch_from_jump_pad", landing_position, launch_duration)
	else:
		_launch_enemy(body, landing_position)


func _can_launch(body: Node2D) -> bool:
	if not is_instance_valid(body) or not is_instance_valid(world_map):
		return false
	if not body.is_in_group(Strings.GROUP_PLAYER) \
			and not body.is_in_group(&"sensor_enemy"):
		return false
	return int(body.get_meta(COOLDOWN_META, 0)) <= Time.get_ticks_msec()


func _get_launch_direction(body: Node2D) -> Vector2i:
	var character_body: CharacterBody2D = body as CharacterBody2D
	var desired_direction: Vector2 = character_body.velocity \
		if character_body != null else Vector2.ZERO
	if body.is_in_group(Strings.GROUP_PLAYER):
		var movement: PlayerMovement = body.get("movement") as PlayerMovement
		if is_instance_valid(movement):
			desired_direction = movement.facing_direction
	elif desired_direction.length_squared() <= 0.01 and body is Creature:
		var creature: Creature = body as Creature
		if is_instance_valid(creature.target_player):
			desired_direction = (
				creature.target_player.global_position - creature.global_position
			)
	return _to_cardinal_direction(desired_direction)


func _to_cardinal_direction(direction: Vector2) -> Vector2i:
	if direction.length_squared() <= 0.01:
		return Vector2i.RIGHT
	if absf(direction.x) >= absf(direction.y):
		return Vector2i.RIGHT if direction.x >= 0.0 else Vector2i.LEFT
	return Vector2i.DOWN if direction.y >= 0.0 else Vector2i.UP


func _find_landing_tile(body: Node2D, direction: Vector2i) -> Dictionary:
	var origin_tile: Vector2i = world_map.world_to_navigation_tile(body.global_position)
	var actor_id: int = body.get_instance_id() if body is Creature else -1
	for distance: int in range(maximum_launch_tiles, 0, -1):
		var candidate: Vector2i = origin_tile + direction * distance
		if not world_map.is_navigation_tile_in_bounds(candidate):
			continue
		if not world_map.is_navigation_tile_walkable(candidate, true, actor_id):
			continue
		if _has_actor_at(candidate, body):
			continue
		return {"found": true, "tile": candidate}
	return {"found": false}


func _has_actor_at(tile: Vector2i, launched_body: Node2D) -> bool:
	var actor_groups: Array[StringName] = [
		StringName(Strings.GROUP_PLAYER),
		&"sensor_enemy",
		&"sensor_animal",
	]
	for group_name: StringName in actor_groups:
		for candidate: Node in get_tree().get_nodes_in_group(group_name):
			var actor: Node2D = candidate as Node2D
			if actor == null \
					or actor == launched_body \
					or actor.is_queued_for_deletion():
				continue
			if world_map.world_to_navigation_tile(actor.global_position) == tile:
				return true
	return false


func _launch_enemy(body: Node2D, landing_position: Vector2) -> void:
	body.set_meta(AIRBORNE_META, true)
	if body is CharacterBody2D:
		(body as CharacterBody2D).velocity = Vector2.ZERO
	var tween: Tween = body.create_tween()
	tween.tween_property(
		body,
		"global_position",
		landing_position,
		launch_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	if not is_instance_valid(body):
		return
	body.remove_meta(AIRBORNE_META)
	var navigation: EnemyNavigation = body.get_node_or_null(
		"EnemyNavigation"
	) as EnemyNavigation
	if navigation != null:
		navigation.synchronize_after_external_move()

