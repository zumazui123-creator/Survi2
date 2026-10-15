extends LandmarkGuardian
class_name WorldEventAttacker

var protected_target: CharacterBody2D
var target_village_id: int = -1
var village_manager: VillageManager


func configure_event_guard(
		value_home_position: Vector2,
		value_target: CharacterBody2D,
		value_village_id: int = -1
	) -> void:
	configure_guard(value_home_position)
	protected_target = value_target
	target_village_id = value_village_id


func _update_target() -> void:
	if not is_instance_valid(protected_target) and target_village_id >= 0:
		if not is_instance_valid(village_manager):
			village_manager = get_tree().get_first_node_in_group(
				"village_manager"
			) as VillageManager
		if is_instance_valid(village_manager):
			protected_target = village_manager.get_nearest_resident(
				target_village_id,
				global_position
			)
	if is_instance_valid(protected_target):
		target_player = protected_target
		return
	super()


func tryAttack() -> void:
	var attack_target: CharacterBody2D = target_player
	var cooldown: Timer = get_node_or_null("AttackCooldown") as Timer
	var can_apply_direct_hit: bool = is_instance_valid(protected_target) \
		and attack_target == protected_target \
		and attack == &"slash" \
		and cooldown != null \
		and cooldown.is_stopped()
	super()
	if can_apply_direct_hit \
			and is_instance_valid(attack_target) \
			and attack_target.has_method("getDamage"):
		attack_target.call("getDamage", self, attackDamage, &"normal")


func _should_despawn_while_idle() -> bool:
	return false
