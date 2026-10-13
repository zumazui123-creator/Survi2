extends BossAttack
class_name ForestVineAttack

@export_range(0.1, 5.0, 0.1) var lock_duration: float = 1.2
@export_range(1.0, 100.0, 1.0) var damage: float = 14.0

func execute(boss: BossCreature) -> void:
	var target: CharacterBody2D = boss.target_player
	if not is_instance_valid(target):
		return
	show_effect(boss, target.global_position, 0.7, Color(0.1, 0.6, 0.18, 0.42), lock_duration)
	if target.has_method("apply_movement_lock"):
		target.rpc("apply_movement_lock", lock_duration)
	target.call("getDamage", boss, damage * boss.get_phase_damage_multiplier(), &"normal")
