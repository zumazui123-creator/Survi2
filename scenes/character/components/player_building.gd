extends Node


@export var player : CharacterBody2D

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
	execute_build.rpc(building_type, tile_position)

@rpc("call_local", "any_peer", "reliable")
func execute_build(building_type: String, tile_position: Vector2i) -> void:
	if building_type in building_scenes:
		Multihelper.main.buildings.place_building(building_scenes[building_type], tile_position)
	else:
		print("Building type ", building_type, " not found.")

func paint(tile_type: String, tile_pos: Vector2i) -> void:
	execute_paint.rpc(tile_type, tile_pos)

@rpc("call_local", "any_peer", "reliable")
func execute_paint(tile_type: String, tile_pos: Vector2i) -> void:
	if tile_type in paintable_tiles:
		Multihelper.map.set_field(tile_pos, paintable_tiles[tile_type])
		print("Painted ", tile_type, " at ", tile_pos)
	else:
		print("Tile type ", tile_type, " not found.")
