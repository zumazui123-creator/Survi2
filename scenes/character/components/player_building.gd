extends Node
class_name PlayerBuilding

@export var player: CharacterBody2D
@onready var world_map: Map = get_tree().get_first_node_in_group("world_map")
@onready var building_manager: BuildingManager = get_tree().get_first_node_in_group(
	"building_manager"
) as BuildingManager

# supports two building modes, one is painting tiles in tilemap in Map,
# the other is placing building scenes in the world

var paintable_tiles: Dictionary[String, Vector2i] = {
	"grass": Vector2i(0, 0),
	"water": Vector2i(18, 0),
}

func build(building_type: String, tile_position: Vector2i) -> void:
	building_type = Strings.translate_building_names(Multihelper.lang, building_type)
	var building_id: StringName = StringName(building_type)
	if not _is_adjacent_to_player(tile_position):
		push_warning("PlayerBuilding: buildings must be placed next to the player")
		return
	if multiplayer.is_server():
		execute_build(building_id, tile_position, player.get_multiplayer_authority())
	else:
		request_build.rpc_id(1, building_id, tile_position)

@rpc("any_peer", "call_remote", "reliable")
func request_build(building_id: StringName, tile_position: Vector2i) -> void:
	if not multiplayer.is_server() or not _is_authorized_sender():
		return
	if not _is_adjacent_to_player(tile_position):
		push_warning("PlayerBuilding: rejected non-adjacent build request")
		return
	execute_build(building_id, tile_position, multiplayer.get_remote_sender_id())


func execute_build(
		building_id: StringName,
		tile_position: Vector2i,
		builder_peer_id: int
	) -> void:
	if not multiplayer.is_server() or not is_instance_valid(building_manager):
		return
	if not building_manager.has_definition(building_id):
		push_warning("Building type '%s' not found." % building_id)
		return
	var result: BuildingPlacementValidator.Result = building_manager.place_building(
		building_id,
		tile_position,
		builder_peer_id
	)
	if result != BuildingPlacementValidator.Result.OK:
		push_warning(
			"PlayerBuilding: %s Tile: %s" % [
				building_manager.get_placement_message(result),
				tile_position,
			]
		)

func paint(tile_type: String, tile_pos: Vector2i) -> void:
	if not _is_adjacent_to_player(tile_pos):
		push_warning("PlayerBuilding: tiles must be painted next to the player")
		return
	if multiplayer.is_server():
		execute_paint(tile_type, tile_pos)
	else:
		request_paint.rpc_id(1, tile_type, tile_pos)

@rpc("any_peer", "call_remote", "reliable")
func request_paint(tile_type: String, tile_pos: Vector2i) -> void:
	if not multiplayer.is_server() or not _is_authorized_sender():
		return
	if not _is_adjacent_to_player(tile_pos):
		push_warning("PlayerBuilding: rejected non-adjacent paint request")
		return
	execute_paint(tile_type, tile_pos)


func execute_paint(tile_type: String, tile_pos: Vector2i) -> void:
	if not multiplayer.is_server() or not is_instance_valid(world_map):
		return
	if tile_type in paintable_tiles:
		world_map.set_field(tile_pos, paintable_tiles[tile_type])
		world_map.set_navigation_terrain_tile(tile_pos, tile_type == "grass")
		print("Painted ", tile_type, " at ", tile_pos)
	else:
		print("Tile type ", tile_type, " not found.")


func _is_authorized_sender() -> bool:
	var sender_id: int = multiplayer.get_remote_sender_id()
	return is_instance_valid(player) and sender_id == player.get_multiplayer_authority()


func _is_adjacent_to_player(tile_position: Vector2i) -> bool:
	if not is_instance_valid(player) or not is_instance_valid(world_map):
		return false
	var player_tile: Vector2i = world_map.world_to_navigation_tile(player.global_position)
	var delta: Vector2i = tile_position - player_tile
	return absi(delta.x) + absi(delta.y) == 1
