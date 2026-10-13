extends BossCreature
class_name ForestColossus

const ATTACK_EFFECT_SCENE: PackedScene = preload(
	"res://scenes/boss/golem_attack_effect.tscn"
)

@export_range(2.0, 20.0, 0.5) var activation_radius_tiles: float = 7.0
@export_range(0.1, 10.0, 0.1) var base_attack_interval: float = 2.5

@onready var arena_controller: BossArenaController = $BossArenaController
@onready var world_map: Map = get_tree().get_first_node_in_group("world_map") as Map
@onready var root_attack: BossAttack = $Attacks/RootAttack
@onready var thorn_attack: BossAttack = $Attacks/ThornAttack
@onready var vine_attack: BossAttack = $Attacks/VineAttack
@onready var spore_attack: BossAttack = $Attacks/SporeAttack
@onready var log_attack: BossAttack = $Attacks/LogAttack
@onready var heal_attack: BossAttack = $Attacks/HealAttack
@onready var summon_attack: BossAttack = $Attacks/SummonAttack

var _attack_sequence: int = 0


func _ready() -> void:
	super()
	$AttackCooldown.wait_time = base_attack_interval
	boss_phase_changed.connect(_on_boss_phase_changed)
	arena_controller.all_weak_points_destroyed.connect(_on_roots_destroyed)
	_apply_visual_state()


func awaken() -> void:
	var was_dormant: bool = dormant
	super()
	if was_dormant and not dormant:
		_apply_visual_state()
		play_boss_visual_event.rpc(&"awaken")


func getDamage(causer: Node, amount: float, damage_type: StringName) -> void:
	if arena_controller != null and arena_controller.is_boss_protected():
		arena_controller.activate_arena()
		show_attack_effect.rpc(
			global_position,
			2.2 * Constants.TILE_SIZE,
			Color(0.18, 0.75, 0.24, 0.28),
			0.45
		)
		return
	super(causer, amount, damage_type)


func _physics_process(_delta: float) -> void:
	if not _is_server() or _is_dead:
		return
	velocity = Vector2.ZERO
	if dormant:
		_try_proximity_awaken()
		return
	_update_target()
	if not is_instance_valid(target_player):
		return
	face_target()
	if $AttackCooldown.is_stopped():
		_perform_next_attack()


func _try_proximity_awaken() -> void:
	resolve_target_player(true)
	if not is_instance_valid(target_player):
		return
	var radius: float = activation_radius_tiles * float(Constants.TILE_SIZE)
	if global_position.distance_squared_to(target_player.global_position) <= radius * radius:
		arena_controller.activate_arena()


func _perform_next_attack() -> void:
	$AttackCooldown.wait_time = base_attack_interval * get_phase_interval_multiplier()
	$AttackCooldown.start()
	play_boss_visual_event.rpc(&"attack")
	_attack_sequence += 1
	var basic_attacks: Array[BossAttack] = [
		root_attack,
		thorn_attack,
		vine_attack,
		spore_attack,
		log_attack,
	]
	var selected_attack: BossAttack
	if boss_phase >= 2 and _attack_sequence % 6 == 0:
		selected_attack = heal_attack if _attack_sequence % 12 == 0 else summon_attack
	else:
		selected_attack = basic_attacks[(_attack_sequence - 1) % basic_attacks.size()]
	if selected_attack != null and selected_attack.can_execute(self):
		selected_attack.execute(self)


func get_phase_damage_multiplier() -> float:
	return 1.5 if boss_phase == 3 else 1.2 if boss_phase == 2 else 1.0


func get_phase_interval_multiplier() -> float:
	return 0.55 if boss_phase == 3 else 0.78 if boss_phase == 2 else 1.0


func get_world_map() -> Map:
	return world_map


func is_defeated() -> bool:
	return _is_dead or not is_inside_tree()


func _on_roots_destroyed() -> void:
	show_attack_effect.rpc(
		global_position,
		3.5 * Constants.TILE_SIZE,
		Color(0.8, 1.0, 0.35, 0.4),
		1.0
	)


func _on_boss_phase_changed(_phase: int) -> void:
	_apply_visual_state()
	play_boss_visual_event.rpc(&"phase")
	show_attack_effect.rpc(
		global_position,
		3.0 * Constants.TILE_SIZE,
		Color(0.35, 1.0, 0.18, 0.4),
		0.8
	)


func _apply_visual_state() -> void:
	var visuals: CanvasItem = get_node_or_null("MovingParts") as CanvasItem
	if visuals == null:
		return
	if dormant:
		visuals.modulate = Color(0.48, 0.58, 0.42, 0.9)
	elif boss_phase == 3:
		visuals.modulate = Color(0.75, 1.0, 0.35, 1.0)
	elif boss_phase == 2:
		visuals.modulate = Color(0.62, 0.9, 0.42, 1.0)
	else:
		visuals.modulate = Color.WHITE


@rpc("authority", "call_local", "reliable")
func show_attack_effect(
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
