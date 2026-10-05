extends Node


@export var player : CharacterBody2D
@onready var world_map: Map = get_tree().get_first_node_in_group("world_map")
@onready var buildings: Buildings = get_tree().get_first_node_in_group("buildings")

# supports two building modes, one is painting tiles in tilemap in Map,
# the other is placing building scenes in the world

#@export var building_scenes : Dictionary[String, PackedScene] = {
	#
#}
var building_scenes : Dictionary[String, PackedScene] = {
	"wall" : preload("res://scenes/spawn/buildings/building.tscn")
}

# dict of paintable tile atlas coords
var paintable_tiles = {
	"grass": Vector2i(0, 0),
	"water": Vector2i(18, 0),
}

func build(building_type: String, tile_position: Vector2i) -> void:
	building_type = Strings.translate_building_names(Multihelper.lang, building_type);
	if multiplayer.is_server():
		execute_build(building_type, tile_position)
	else:
		request_build.rpc_id(1, building_type, tile_position)

@rpc("any_peer", "call_remote", "reliable")
func request_build(building_type: String, tile_position: Vector2i) -> void:
	if multiplayer.is_server():
		execute_build(building_type, tile_position)


func execute_build(building_type: String, tile_position: Vector2i) -> void:
	if building_type in building_scenes:
		buildings.place_building(building_scenes[building_type], tile_position)
	else:
		print("Building type ", building_type, " not found.")

func paint(tile_type: String, tile_pos: Vector2i) -> void:
	if multiplayer.is_server():
		execute_paint(tile_type, tile_pos)
	else:
		request_paint.rpc_id(1, tile_type, tile_pos)

@rpc("any_peer", "call_remote", "reliable")
func request_paint(tile_type: String, tile_pos: Vector2i) -> void:
	if multiplayer.is_server():
		execute_paint(tile_type, tile_pos)


func execute_paint(tile_type: String, tile_pos: Vector2i) -> void:
	if tile_type in paintable_tiles:
		world_map.set_field(tile_pos, paintable_tiles[tile_type])
		world_map.set_navigation_terrain_tile(tile_pos, tile_type == "grass")
		print("Painted ", tile_type, " at ", tile_pos)
	else:
		print("Tile type ", tile_type, " not found.")
