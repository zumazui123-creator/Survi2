extends BossAttack
class_name ForestSummonAttack

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy/enemy.tscn")
@export_range(1, 8, 1) var maximum_saplings: int = 4

func execute(boss: BossCreature) -> void:
	var world_map: Map = boss.get_world_map()
	if not is_instance_valid(world_map):
		return
	var existing: int = 0
	for candidate: Node in boss.get_tree().get_nodes_in_group(&"forest_sapling"):
		if is_instance_valid(candidate):
			existing += 1
	var wanted: int = 2 if boss.boss_phase == 2 else 3
	var spawn_count: int = mini(wanted, maximum_saplings - existing)
	if spawn_count <= 0:
		return
	var enemies_root: Node2D = boss.get_tree().get_first_node_in_group("enemies_root") as Node2D
	if enemies_root == null:
		return
	var offsets: Array[Vector2i] = [Vector2i(3, 0), Vector2i(-3, 0), Vector2i(0, 3), Vector2i(0, -3)]
	var center_tile: Vector2i = world_map.world_to_navigation_tile(boss.global_position)
	for index: int in range(spawn_count):
		var sapling: Enemy = ENEMY_SCENE.instantiate() as Enemy
		if sapling == null:
			continue
		sapling.actor_id = &"forestSapling"
		sapling.add_to_group(&"forest_sapling")
		sapling.global_position = world_map.navigation_tile_to_world(center_tile + offsets[index])
		sapling.spawner = boss
		enemies_root.add_child(sapling, true)
