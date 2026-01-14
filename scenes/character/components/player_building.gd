extends Node
class_name PlayerBuilding

@export var player : Player
@export var buildings_parent : Node2D

# supports two building modes, one is painting tiles in tilemap in Map autoload,
# the other is placing building scenes in the world

# dict of available building scenes
var building_scenes = {
    #"wall": preload("res://scenes/buildings/Wall.tscn"),
}

# dict of paintable tile atlas coords
var paintable_tiles = {
    "grass": Vector2i(0, 0),
    "water": Vector2i(18, 0),
}

func build(building_type: String, position: Vector2) -> void:
    if building_type in building_scenes:
        var building_instance = building_scenes[building_type].instantiate()
        building_instance.position = position
        player.get_parent().add_child(building_instance)
        print("Built ", building_type, " at ", position)
    else:
        print("Building type ", building_type, " not found.")

func paint(tile_type: String, tile_pos: Vector2i) -> void:
    if tile_type in paintable_tiles:
        Map.set_field(tile_pos, paintable_tiles[tile_type])
        print("Painted ", tile_type, " at ", tile_pos)
    else:
        print("Tile type ", tile_type, " not found.")