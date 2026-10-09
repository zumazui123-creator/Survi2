extends TowerWeapon
class_name BurningTowerWeapon

const EFFECT_SCRIPT: Script = preload(
	"res://scenes/spawn/buildings/damage_over_time_effect.gd"
)
const EFFECT_NODE_NAME: StringName = &"BurningDamageEffect"

@export_range(0.5, 20.0, 0.5) var burn_duration: float = 5.0
@export_range(0.5, 20.0, 0.5) var burn_damage_per_tick: float = 5.0
@export_range(0.1, 5.0, 0.1) var burn_tick_interval: float = 1.0


func _on_projectile_hit(body: Node, source: Node2D, target_group: StringName) -> void:
	if not multiplayer.is_server() \
			or not is_instance_valid(body) \
			or not body.is_in_group(target_group) \
			or not body.has_method("getDamage"):
		return
	body.call("getDamage", source, attack_damage, damage_type)
	var existing: DamageOverTimeEffect = body.get_node_or_null(
		NodePath(String(EFFECT_NODE_NAME))
	) as DamageOverTimeEffect
	if existing != null:
		existing.refresh(burn_duration)
		return
	var effect: DamageOverTimeEffect = EFFECT_SCRIPT.new() as DamageOverTimeEffect
	effect.name = EFFECT_NODE_NAME
	effect.configure(
		source,
		burn_damage_per_tick,
		burn_duration,
		burn_tick_interval,
		&"fireDamage"
	)
	body.add_child(effect)
