extends Node2D
class_name Buildings

var placed_buildings : Dictionary[Vector2i, Node] = {}

func place_building(building_scene: PackedScene, tile_pos: Vector2i) -> void:
	if tile_pos in placed_buildings:
		print("A building is already placed at ", tile_pos)
		return
	var building_instance = building_scene.instantiate()
	add_child(building_instance)
	building_instance.position = Multihelper.map.tile_map.map_to_local(tile_pos)
	placed_buildings[tile_pos] = building_instance
	print("Placed building at ", tile_pos)
