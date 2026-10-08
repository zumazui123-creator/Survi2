extends Node
class_name TowerWeapon

@export_range(0.1, 60.0, 0.5) var attack_damage: float = 15.0
@export_range(0.1, 10.0, 0.1) var attack_interval: float = 1.25
@export var projectile_id: String = "magicBolt"
@export var damage_type: StringName = &"normal"


func fire(source: Node2D, target: Node2D, target_group: StringName) -> bool:
	if not multiplayer.is_server() or not is_instance_valid(source) or not is_instance_valid(target):
		return false
	var entity_spawner: WorldEntitySpawner = WorldEntitySpawner.get_for(source)
	if entity_spawner == null:
		return false
	entity_spawner.spawn_projectile(
		source,
		projectile_id,
		target.global_position,
		target_group,
		_on_projectile_hit.bind(source, target_group)
	)
	return true


func _on_projectile_hit(body: Node, source: Node2D, target_group: StringName) -> void:
	if not multiplayer.is_server() \
			or not is_instance_valid(body) \
			or not body.is_in_group(target_group) \
			or not body.has_method("getDamage"):
		return
	body.call("getDamage", source, attack_damage, damage_type)
