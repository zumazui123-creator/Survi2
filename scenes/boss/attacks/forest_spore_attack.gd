extends BossAttack
class_name ForestSporeAttack

@export_range(0.1, 4.0, 0.1) var warning_seconds: float = 0.75
@export_range(1, 8, 1) var pulse_count: int = 3
@export_range(1.0, 100.0, 1.0) var damage_per_pulse: float = 8.0

func execute(boss: BossCreature) -> void:
	for target: Node2D in get_nearby_players(boss, 12.0):
		_delayed_spore_zone(boss, target.global_position)

func _delayed_spore_zone(boss: BossCreature, position: Vector2) -> void:
	show_effect(boss, position, 1.15, Color(0.55, 0.2, 0.75, 0.32), warning_seconds)
	await boss.get_tree().create_timer(warning_seconds).timeout
	if not is_instance_valid(boss) or boss.is_defeated():
		return
	for pulse: int in range(pulse_count):
		damage_players_in_radius(boss, position, 1.15, damage_per_pulse * boss.get_phase_damage_multiplier())
		show_effect(boss, position, 1.15, Color(0.62, 0.28, 0.78, 0.25), 0.45)
		if pulse < pulse_count - 1:
			await boss.get_tree().create_timer(0.65).timeout
