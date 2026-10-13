extends BossAttack
class_name ForestHealAttack

@export_range(0.01, 0.5, 0.01) var heal_ratio: float = 0.08

func execute(boss: BossCreature) -> void:
	var world_map: Map = boss.get_world_map()
	if not is_instance_valid(world_map):
		return
	var tree_manager: TreeManager = boss.get_tree().get_first_node_in_group("tree_manager") as TreeManager
	if tree_manager == null:
		return
	var center_tile: Vector2i = world_map.world_to_navigation_tile(boss.global_position)
	var trees: Array[TreeState] = tree_manager.get_trees_in_radius(center_tile, 11)
	if trees.is_empty():
		return
	var source_tree: TreeEntity = tree_manager.activate_tree(trees[0].tile)
	if source_tree != null:
		source_tree.getDamage(boss, 9999.0, &"axe")
	boss.hp = minf(boss.maxhp, boss.hp + boss.maxhp * heal_ratio)
	show_effect(boss, boss.global_position, 3.0, Color(0.2, 1.0, 0.32, 0.38), 0.9)
