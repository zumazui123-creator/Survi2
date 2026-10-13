extends BossCreature
class_name StoneGolem

const ATTACK_EFFECT_SCENE: PackedScene = preload(
	"res://scenes/boss/golem_attack_effect.tscn"
)

@export_range(2.0, 20.0, 0.5) var activation_radius_tiles: float = 6.0
@export_range(1, 3, 1) var footprint_radius_tiles: int = 1
@export_range(0.5, 8.0, 0.25) var earthquake_radius_tiles: float = 3.5
@export_range(0.1, 5.0, 0.1) var stonefall_warning_seconds: float = 0.8
@export_range(0.1, 10.0, 0.1) var base_attack_interval: float = 2.2
@export_group("Visual colors")
@export var base_visual_color: Color = Color.WHITE
@export var dormant_visual_color: Color = Color(0.55, 0.58, 0.6, 0.86)
@export var phase_two_visual_color: Color = Color(1.0, 0.82, 0.62, 1.0)
@export var phase_three_visual_color: Color = Color(1.0, 0.62, 0.45, 1.0)

@onready var world_map: Map = get_tree().get_first_node_in_group("world_map") as Map
var _attack_sequence: int = 0
var _last_center_tile: Vector2i = Vector2i(-99999, -99999)


func _ready() -> void:
	super()
	_last_center_tile = _get_center_tile()
	$AttackCooldown.wait_time = base_attack_interval
	boss_phase_changed.connect(_on_boss_phase_changed)
	_apply_dormant_visual()


func awaken() -> void:
	var was_dormant: bool = dormant
	super()
	if was_dormant and not dormant:
		_apply_dormant_visual()
		play_boss_visual_event.rpc(&"awaken")
		_show_effect.rpc(global_position, 2.5 * Constants.TILE_SIZE, Color(0.75, 0.55, 0.25, 0.4), 0.9)


func _physics_process(delta: float) -> void:
	if not _is_server() or _is_dead:
		return
	if dormant:
		velocity = Vector2.ZERO
		_try_proximity_awaken()
		return
	_update_target()
	if not is_instance_valid(target_player):
		velocity = Vector2.ZERO
		navigation.clear_target()
		return
	face_target()
	var distance_tiles: float = global_position.distance_to(target_player.global_position) \
		/ float(Constants.TILE_SIZE)
	if $AttackCooldown.is_stopped():
		_perform_next_attack(distance_tiles)
		return
	if distance_tiles <= 2.2:
		velocity = Vector2.ZERO
		navigation.stop_at_current_position()
		return
	_move_large_actor(delta)


func _try_proximity_awaken() -> void:
	resolve_target_player(true)
	if not is_instance_valid(target_player):
		return
	var radius: float = activation_radius_tiles * float(Constants.TILE_SIZE)
	if global_position.distance_squared_to(target_player.global_position) <= radius * radius:
		awaken()


func _move_large_actor(delta: float) -> void:
	navigation.set_target(target_player)
	var next_position: Vector2 = navigation.update_navigation(delta, 2)
	if not next_position.is_finite():
		velocity = Vector2.ZERO
		return
	var next_tile: Vector2i = world_map.world_to_navigation_tile(next_position)
	if not _can_occupy_center(next_tile):
		velocity = Vector2.ZERO
		navigation.cancel_path()
		return
	move_towards_position(next_position)
	var current_tile: Vector2i = _get_center_tile()
	if current_tile != _last_center_tile:
		_last_center_tile = current_tile
		_apply_step_damage()


func _can_occupy_center(center_tile: Vector2i) -> bool:
	if not is_instance_valid(world_map):
		return false
	for y_offset: int in range(-footprint_radius_tiles, footprint_radius_tiles + 1):
		for x_offset: int in range(-footprint_radius_tiles, footprint_radius_tiles + 1):
			var tile: Vector2i = center_tile + Vector2i(x_offset, y_offset)
			if not world_map.is_navigation_tile_walkable(
					tile, true, get_instance_id()
				):
				return false
	return true


func _perform_next_attack(distance_tiles: float) -> void:
	$AttackCooldown.wait_time = base_attack_interval * _get_phase_interval_multiplier()
	$AttackCooldown.start()
	play_boss_visual_event.rpc(&"attack")
	_attack_sequence += 1
	if distance_tiles <= 1.8:
		_fist_attack()
		return
	match _attack_sequence % 4:
		0:
			_earthquake_attack()
		1:
			_rock_throw_attack()
		2:
			_stonefall_attack()
		_:
			_raise_stone_wall()


func _fist_attack() -> void:
	if not is_instance_valid(target_player):
		return
	var damage: float = 34.0 * _get_phase_damage_multiplier()
	target_player.call("getDamage", self, damage, &"normal")
	_show_effect.rpc(target_player.global_position, 0.9 * Constants.TILE_SIZE, Color(0.7, 0.48, 0.2, 0.5), 0.35)


func _earthquake_attack() -> void:
	var radius_pixels: float = earthquake_radius_tiles * float(Constants.TILE_SIZE)
	_show_effect.rpc(global_position, radius_pixels, Color(0.72, 0.35, 0.08, 0.45), 0.65)
	for candidate: Node in get_tree().get_nodes_in_group(Strings.GROUP_PLAYER):
		var player: Node2D = candidate as Node2D
		if player == null or global_position.distance_to(player.global_position) > radius_pixels:
			continue
		player.call("getDamage", self, 22.0 * _get_phase_damage_multiplier(), &"normal")
		_knock_back_player(player, 2)


func _rock_throw_attack() -> void:
	if not is_instance_valid(target_player):
		return
	var entity_spawner: WorldEntitySpawner = WorldEntitySpawner.get_for(self)
	if entity_spawner == null:
		return
	entity_spawner.spawn_projectile(
		self,
		"golemRock",
		target_player.global_position,
		StringName(Strings.GROUP_PLAYER),
		_on_rock_hit
	)


func _on_rock_hit(body: Node) -> void:
	if multiplayer.is_server() and is_instance_valid(body) and body.has_method("getDamage"):
		body.call("getDamage", self, 28.0 * _get_phase_damage_multiplier(), &"normal")


func _stonefall_attack() -> void:
	if not is_instance_valid(target_player) or not is_instance_valid(world_map):
		return
	var target_tile: Vector2i = world_map.world_to_navigation_tile(target_player.global_position)
	var impact_position: Vector2 = world_map.navigation_tile_to_world(target_tile)
	_show_effect.rpc(
		impact_position,
		1.15 * Constants.TILE_SIZE,
		Color(1.0, 0.12, 0.04, 0.35),
		stonefall_warning_seconds
	)
	await get_tree().create_timer(stonefall_warning_seconds).timeout
	if not is_inside_tree() or _is_dead:
		return
	for candidate: Node in get_tree().get_nodes_in_group(Strings.GROUP_PLAYER):
		var player: Node2D = candidate as Node2D
		if player != null and player.global_position.distance_to(impact_position) \
				<= 1.15 * Constants.TILE_SIZE:
			player.call("getDamage", self, 42.0 * _get_phase_damage_multiplier(), &"normal")


func _raise_stone_wall() -> void:
	if not is_instance_valid(target_player) or not is_instance_valid(world_map):
		return
	var building_manager: BuildingManager = get_tree().get_first_node_in_group(
		"building_manager"
	) as BuildingManager
	if building_manager == null:
		return
	var target_tile: Vector2i = world_map.world_to_navigation_tile(target_player.global_position)
	var direction: Vector2i = _to_cardinal_tile(
		target_player.global_position - global_position
	)
	var wall_tile: Vector2i = target_tile - direction
	building_manager.place_generated_building(&"golem_rock_wall", wall_tile, &"stone_golem")


func _apply_step_damage() -> void:
	var radius: float = 1.25 * float(Constants.TILE_SIZE)
	for candidate: Node in get_tree().get_nodes_in_group(Strings.GROUP_PLAYER):
		var player: Node2D = candidate as Node2D
		if player != null and global_position.distance_to(player.global_position) <= radius:
			player.call("getDamage", self, 7.0 * _get_phase_damage_multiplier(), &"normal")


func _knock_back_player(player: Node2D, distance_tiles: int) -> void:
	if not is_instance_valid(world_map) or not player.has_method("launch_from_jump_pad"):
		return
	var direction: Vector2i = _to_cardinal_tile(player.global_position - global_position)
	var origin: Vector2i = world_map.world_to_navigation_tile(player.global_position)
	for distance: int in range(distance_tiles, 0, -1):
		var destination: Vector2i = origin + direction * distance
		if world_map.is_navigation_tile_walkable(destination, true, player.get_instance_id()):
			player.rpc("launch_from_jump_pad", world_map.navigation_tile_to_world(destination), 0.25)
			return


func _get_phase_damage_multiplier() -> float:
	return 1.45 if boss_phase == 3 else 1.2 if boss_phase == 2 else 1.0


func _get_phase_interval_multiplier() -> float:
	return 0.58 if boss_phase == 3 else 0.78 if boss_phase == 2 else 1.0


func _on_boss_phase_changed(_phase: int) -> void:
	play_boss_visual_event.rpc(&"phase")
	_show_effect.rpc(global_position, 2.1 * Constants.TILE_SIZE, Color(0.85, 0.18, 0.05, 0.4), 0.7)
	var visuals: CanvasItem = get_node_or_null("MovingParts") as CanvasItem
	if visuals != null:
		visuals.modulate = phase_three_visual_color if boss_phase == 3 \
			else phase_two_visual_color if boss_phase == 2 else base_visual_color


func _apply_dormant_visual() -> void:
	var visuals: CanvasItem = get_node_or_null("MovingParts") as CanvasItem
	if visuals != null:
		visuals.modulate = dormant_visual_color if dormant else base_visual_color


func _get_center_tile() -> Vector2i:
	return world_map.world_to_navigation_tile(global_position) \
		if is_instance_valid(world_map) else Vector2i.ZERO


func _to_cardinal_tile(direction: Vector2) -> Vector2i:
	if absf(direction.x) >= absf(direction.y):
		return Vector2i.RIGHT if direction.x >= 0.0 else Vector2i.LEFT
	return Vector2i.DOWN if direction.y >= 0.0 else Vector2i.UP


@rpc("authority", "call_local", "reliable")
func _show_effect(
		world_position: Vector2,
		radius: float,
		color: Color,
		duration: float
	) -> void:
	var effect: GolemAttackEffect = ATTACK_EFFECT_SCENE.instantiate() as GolemAttackEffect
	if effect == null:
		return
	get_tree().current_scene.add_child(effect)
	effect.global_position = world_position
	effect.configure(radius, color, duration)
