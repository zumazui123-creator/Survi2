extends BossAttack
class_name ForestRootAttack

@export_range(0.1, 4.0, 0.1) var warning_seconds: float = 0.75
@export_range(1.0, 100.0, 1.0) var damage: float = 30.0

func execute(boss: BossCreature) -> void:
	var targets: Array[Node2D] = get_nearby_players(boss, 12.0)
	var target_count: int = mini(targets.size(), 3 if boss.boss_phase == 3 else 2)
	for index: int in range(target_count):
		_delayed_impact(boss, targets[index].global_position)

func _delayed_impact(boss: BossCreature, position: Vector2) -> void:
	show_effect(boss, position, 0.9, Color(0.22, 0.75, 0.16, 0.38), warning_seconds)
	await boss.get_tree().create_timer(warning_seconds).timeout
	if not is_instance_valid(boss) or boss.is_defeated():
		return
	damage_players_in_radius(boss, position, 0.9, damage * boss.get_phase_damage_multiplier())
