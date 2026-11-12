extends Node
class_name AdminCommandService

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy/enemy.tscn")
const INVALID_TILE: Vector2i = Vector2i(-999999, -999999)

@export var enemies_root: Node2D
@export var world_map: Map
@export_range(1, 8, 1) var minimum_spawn_radius_tiles: int = 2
@export_range(1, 12, 1) var maximum_spawn_radius_tiles: int = 5

var _last_spawned_enemy_by_peer: Dictionary[int, Enemy] = {}


func request_create_enemy(
		requesting_player: Survi2Player,
		actor_id: StringName
	) -> bool:
	if not PlayerRolePolicy.is_admin_player(requesting_player):
		return false
	var normalized_actor_id: StringName = StringName(String(actor_id).to_lower())
	if not Items.mobs.has(String(normalized_actor_id)):
		return false
	var peer_id: int = requesting_player.get_multiplayer_authority()
	if multiplayer.is_server():
		return _server_create_enemy(peer_id, normalized_actor_id)
	_request_create_enemy.rpc_id(1, String(normalized_actor_id))
	return true


func request_send_last_enemy(
		requesting_player: Survi2Player,
		target_player_name: String
	) -> bool:
	if not PlayerRolePolicy.is_admin_player(requesting_player) \
			or target_player_name.strip_edges().is_empty():
		return false
	var peer_id: int = requesting_player.get_multiplayer_authority()
	if multiplayer.is_server():
		return _server_send_last_enemy(peer_id, target_player_name)
	_request_send_last_enemy.rpc_id(1, target_player_name.strip_edges())
	return true


@rpc("any_peer", "call_remote", "reliable")
func _request_create_enemy(actor_id: String) -> void:
	if not multiplayer.is_server():
		return
	_server_create_enemy(
		multiplayer.get_remote_sender_id(),
		StringName(actor_id.to_lower())
	)


@rpc("any_peer", "call_remote", "reliable")
func _request_send_last_enemy(target_player_name: String) -> void:
	if not multiplayer.is_server():
		return
	_server_send_last_enemy(
		multiplayer.get_remote_sender_id(),
		target_player_name
	)


func _server_create_enemy(peer_id: int, actor_id: StringName) -> bool:
	var admin: Survi2Player = _get_player_for_peer(peer_id)
	if not PlayerRolePolicy.is_admin_player(admin):
		return false
	if not Items.mobs.has(String(actor_id)):
		_notify(admin, "Admin: Unbekannter Gegnertyp '%s'. Erlaubt sind: %s" % [
			actor_id,
			_get_enemy_type_list(),
		])
		return false
	if not is_instance_valid(enemies_root) or not is_instance_valid(world_map):
		_notify(admin, "Admin: Die Gegnerverwaltung ist nicht verfügbar.")
		return false

	var spawn_tile: Vector2i = _find_spawn_tile(admin)
	if spawn_tile == INVALID_TILE:
		_notify(admin, "Admin: In der Nähe ist kein freies Tile für einen Gegner.")
		return false
	var enemy: Enemy = ENEMY_SCENE.instantiate() as Enemy
	if enemy == null:
		_notify(admin, "Admin: Der Gegner konnte nicht erstellt werden.")
		return false
	enemy.spawner = enemies_root
	enemy.targetPlayerId = 0
	enemy.actor_id = actor_id
	enemy.set_meta(Enemy.ADMIN_WAITING_FOR_TARGET_META, true)
	enemy.position = enemies_root.to_local(
		world_map.navigation_tile_to_world(spawn_tile)
	)
	enemies_root.add_child(enemy, true)
	_last_spawned_enemy_by_peer[peer_id] = enemy
	_notify(
		admin,
		"Admin: Gegner '%s' erstellt. Nutze 'sende gegner zu NAME'." % actor_id
	)
	return true


func _server_send_last_enemy(peer_id: int, target_player_name: String) -> bool:
	var admin: Survi2Player = _get_player_for_peer(peer_id)
	if not PlayerRolePolicy.is_admin_player(admin):
		return false
	var enemy: Enemy = _last_spawned_enemy_by_peer.get(peer_id) as Enemy
	if not is_instance_valid(enemy):
		_last_spawned_enemy_by_peer.erase(peer_id)
		_notify(admin, "Admin: Erstelle zuerst einen Gegner.")
		return false
	var target: Survi2Player = _find_player_by_name(target_player_name)
	if target == null:
		_notify(admin, "Admin: Spieler '%s' wurde nicht gefunden." % target_player_name)
		return false
	if PlayerRolePolicy.is_admin_player(target):
		_notify(admin, "Admin: Gegner greifen keinen Admin an.")
		return false
	enemy.remove_meta(Enemy.ADMIN_WAITING_FOR_TARGET_META)
	if not enemy.assign_target_player(target):
		_notify(admin, "Admin: Der Gegner konnte nicht zugewiesen werden.")
		return false
	_notify(
		admin,
		"Admin: Gegner '%s' wurde zu '%s' geschickt." % [
			enemy.actor_id,
			target.playerName,
		]
	)
	return true


func _find_spawn_tile(admin: Survi2Player) -> Vector2i:
	if not is_instance_valid(world_map) or not world_map.astar_ready:
		return INVALID_TILE
	var origin: Vector2i = world_map.world_to_navigation_tile(
		admin.global_position
	)
	var minimum_radius: int = mini(
		minimum_spawn_radius_tiles,
		maximum_spawn_radius_tiles
	)
	var maximum_radius: int = maxi(
		minimum_spawn_radius_tiles,
		maximum_spawn_radius_tiles
	)
	for radius: int in range(minimum_radius, maximum_radius + 1):
		var candidates: Array[Vector2i] = []
		for y_offset: int in range(-radius, radius + 1):
			for x_offset: int in range(-radius, radius + 1):
				if maxi(absi(x_offset), absi(y_offset)) != radius:
					continue
				candidates.append(origin + Vector2i(x_offset, y_offset))
		candidates.shuffle()
		for candidate: Vector2i in candidates:
			if not world_map.is_navigation_tile_walkable(candidate, true):
				continue
			if not world_map.get_navigation_path(candidate, origin).is_empty():
				return candidate
	return INVALID_TILE


func _get_player_for_peer(peer_id: int) -> Survi2Player:
	for candidate: Node in get_tree().get_nodes_in_group(Strings.GROUP_PLAYER):
		var player: Survi2Player = candidate as Survi2Player
		if player != null and player.get_multiplayer_authority() == peer_id:
			return player
	return null


func _find_player_by_name(requested_name: String) -> Survi2Player:
	var normalized_name: String = requested_name.strip_edges()
	var case_insensitive_match: Survi2Player
	for candidate: Node in get_tree().get_nodes_in_group(Strings.GROUP_PLAYER):
		var player: Survi2Player = candidate as Survi2Player
		if player == null:
			continue
		if player.playerName == normalized_name:
			return player
		if player.playerName.nocasecmp_to(normalized_name) == 0:
			case_insensitive_match = player
	return case_insensitive_match


func _get_enemy_type_list() -> String:
	var enemy_types: Array[String] = []
	for actor_value: Variant in Items.mobs.keys():
		enemy_types.append(String(actor_value))
	enemy_types.sort()
	return ", ".join(enemy_types)


func _notify(player: Survi2Player, message: String) -> void:
	if not is_instance_valid(player):
		return
	player.sendMessage.rpc_id(player.get_multiplayer_authority(), message)
