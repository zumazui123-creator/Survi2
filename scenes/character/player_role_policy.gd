extends RefCounted
class_name PlayerRolePolicy

const ADMIN_PLAYER_NAME: String = "Admin"


static func is_admin_name(player_name: String) -> bool:
	return player_name.strip_edges() == ADMIN_PLAYER_NAME


static func is_admin_player(candidate: Node) -> bool:
	var player: CharacterBody2D = candidate as CharacterBody2D
	if player == null or not player.is_in_group(Strings.GROUP_PLAYER):
		return false
	return is_admin_name(String(player.get("playerName")))
