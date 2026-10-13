extends BossAttack
class_name ForestThornAttack

@export_range(1.0, 100.0, 1.0) var damage: float = 22.0

func execute(boss: BossCreature) -> void:
	var radius_tiles: float = 4.5 if boss.boss_phase == 3 else 3.5
	show_effect(boss, boss.global_position, radius_tiles, Color(0.32, 0.88, 0.16, 0.35), 0.55)
	damage_players_in_radius(boss, boss.global_position, radius_tiles, damage * boss.get_phase_damage_multiplier())
