extends BossAttack
class_name ForestLogAttack

@export_range(1.0, 100.0, 1.0) var damage: float = 34.0
var _active_boss: BossCreature

func execute(boss: BossCreature) -> void:
	if not is_instance_valid(boss.target_player):
		return
	var spawner: WorldEntitySpawner = WorldEntitySpawner.get_for(boss)
	if spawner == null:
		return
	_active_boss = boss
	spawner.spawn_projectile(boss, "forestLog", boss.target_player.global_position, StringName(Strings.GROUP_PLAYER), _on_log_hit)

func _on_log_hit(body: Node) -> void:
	if not multiplayer.is_server() or not is_instance_valid(_active_boss) or not is_instance_valid(body) or not body.has_method("getDamage"):
		return
	body.call("getDamage", _active_boss, damage * _active_boss.get_phase_damage_multiplier(), &"normal")
