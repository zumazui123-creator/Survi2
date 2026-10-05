extends Node
class_name WorldEntitySpawner

@export var pickups_root: Node2D
@export var projectiles_root: Node2D

const PICKUP_SCENE := preload("res://scenes/item/pickup.tscn")
const PROJECTILE_SCENE := preload("res://scenes/attacks/projectile_attack.tscn")


static func get_for(node: Node) -> WorldEntitySpawner:
	return node.get_tree().get_first_node_in_group("world_entity_spawner") as WorldEntitySpawner


func spawn_pickups(item_id: String, world_position: Vector2, amount: int) -> void:
	for _index in range(amount):
		var pickup = PICKUP_SCENE.instantiate()
		pickup.itemId = item_id
		pickup.position = world_position + Vector2(randf_range(-15.0, 15.0), randf_range(-15.0, 15.0))
		pickups_root.add_child(pickup, true)


func spawn_projectile(spawner, projectile_id: String, target_position: Vector2, target_group: StringName) -> void:
	var projectile = PROJECTILE_SCENE.instantiate()
	projectile.projectileId = projectile_id
	projectile.targetGroup = target_group
	projectile.position = spawner.position
	projectile.get_node("MovingParts").rotation = spawner.get_node("MovingParts").rotation
	projectile.hitPlayer.connect(spawner.combat.projectileHit)
	projectile.targetPos = target_position
	projectile.spawner = spawner
	projectiles_root.add_child(projectile, true)
