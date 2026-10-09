extends TowerWeapon
class_name AreaTowerWeapon

const MAGIC_PULSE_EFFECT: PackedScene = preload(
	"res://scenes/spawn/buildings/magic_pulse_effect.tscn"
)

@export_range(0.5, 8.0, 0.25) var area_radius_tiles: float = 2.25
@export_range(0.0, 1.0, 0.05) var secondary_damage_multiplier: float = 0.75


func _on_projectile_hit(
		body: Node,
		source: Node2D,
		target_group: StringName
	) -> void:
	if not multiplayer.is_server() \
			or not is_instance_valid(body) \
			or not is_instance_valid(source) \
			or not body.is_in_group(target_group):
		return
	var impact: Node2D = body as Node2D
	if impact == null:
		return
	_show_magic_pulse.rpc(impact.global_position)
	var radius_pixels: float = area_radius_tiles * float(Constants.TILE_SIZE)
	var radius_squared: float = radius_pixels * radius_pixels
	for candidate: Node in source.get_tree().get_nodes_in_group(target_group):
		var target: Node2D = candidate as Node2D
		if target == null \
				or target.is_queued_for_deletion() \
				or not target.has_method("getDamage"):
			continue
		if impact.global_position.distance_squared_to(target.global_position) \
				> radius_squared:
			continue
		var damage: float = attack_damage
		if target != impact:
			damage *= secondary_damage_multiplier
		target.call("getDamage", source, damage, damage_type)


@rpc("authority", "call_local", "unreliable")
func _show_magic_pulse(world_position: Vector2) -> void:
	var effect: MagicPulseEffect = MAGIC_PULSE_EFFECT.instantiate() as MagicPulseEffect
	if effect == null:
		return
	var world_root: Node = get_tree().current_scene
	if world_root == null:
		return
	world_root.add_child(effect)
	effect.global_position = world_position
	effect.configure(area_radius_tiles * float(Constants.TILE_SIZE))

