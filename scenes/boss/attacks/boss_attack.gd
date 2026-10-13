extends Node
class_name BossAttack

@export_range(1, 3, 1) var minimum_phase: int = 1

func can_execute(boss: BossCreature) -> bool:
	return is_instance_valid(boss) and boss.boss_phase >= minimum_phase

func execute(_boss: BossCreature) -> void:
	pass

func get_nearby_players(boss: BossCreature, radius_tiles: float) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var radius_pixels: float = radius_tiles * float(Constants.TILE_SIZE)
	var radius_squared: float = radius_pixels * radius_pixels
	for candidate: Node in boss.get_tree().get_nodes_in_group(Strings.GROUP_PLAYER):
		var player: Node2D = candidate as Node2D
		if player != null and player.global_position.distance_squared_to(boss.global_position) <= radius_squared:
			result.append(player)
	return result

func damage_players_in_radius(boss: BossCreature, center: Vector2, radius_tiles: float, damage: float) -> void:
	var radius_pixels: float = radius_tiles * float(Constants.TILE_SIZE)
	var radius_squared: float = radius_pixels * radius_pixels
	for candidate: Node in boss.get_tree().get_nodes_in_group(Strings.GROUP_PLAYER):
		var player: Node2D = candidate as Node2D
		if player == null or player.global_position.distance_squared_to(center) > radius_squared:
			continue
		player.call("getDamage", boss, damage, &"normal")

func show_effect(boss: BossCreature, position: Vector2, radius_tiles: float, color: Color, duration: float) -> void:
	boss.rpc("show_attack_effect", position, radius_tiles * float(Constants.TILE_SIZE), color, duration)
