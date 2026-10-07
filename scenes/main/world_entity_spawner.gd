extends Node
class_name WorldEntitySpawner

@export var pickups_root: Node2D
@export var projectiles_root: Node2D

const PICKUP_SCENE: PackedScene = preload("res://scenes/item/pickup.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/attacks/projectile_attack.tscn")


static func get_for(node: Node) -> WorldEntitySpawner:
	return node.get_tree().get_first_node_in_group("world_entity_spawner") as WorldEntitySpawner


func spawn_pickups(item_id: String, world_position: Vector2, amount: int) -> void:
	for _index in range(amount):
		var pickup = PICKUP_SCENE.instantiate()
		pickup.itemId = item_id
		pickups_root.add_child(pickup, true)
		pickup.global_position = world_position + Vector2(randf_range(-15.0, 15.0), randf_range(-15.0, 15.0))


func spawn_projectile(
		spawner: Node2D,
		projectile_id: String,
		target_position: Vector2,
		target_group: StringName,
		hit_callback: Callable = Callable()
	) -> void:
	if not multiplayer.is_server() or not is_instance_valid(projectiles_root):
		return
	var projectile: Node2D = PROJECTILE_SCENE.instantiate() as Node2D
	if projectile == null:
		return
	projectile.set("projectileId", projectile_id)
	projectile.set("targetGroup", target_group)
	projectile.set("spawner", spawner)
	projectile.position = projectiles_root.to_local(spawner.global_position)
	var projectile_visuals: Node2D = projectile.get_node_or_null("MovingParts") as Node2D
	var source_visuals: Node2D = spawner.get_node_or_null("MovingParts") as Node2D
	if source_visuals == null:
		source_visuals = spawner.get_node_or_null("Visuals/MovingParts") as Node2D
	if projectile_visuals != null and source_visuals != null:
		projectile_visuals.rotation = source_visuals.global_rotation
	if hit_callback.is_valid():
		projectile.connect("hitPlayer", hit_callback)
	else:
		var combat: Node = spawner.get("combat") as Node
		if combat != null and combat.has_method("projectileHit"):
			projectile.connect("hitPlayer", Callable(combat, "projectileHit"))
	projectile.set("targetPos", projectiles_root.to_local(target_position))
	projectiles_root.add_child(projectile, true)
