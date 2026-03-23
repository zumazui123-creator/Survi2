extends Node2D
class_name Buildings

var placed_buildings : Dictionary[Vector2i, Node] = {}

func place_building(building_scene: PackedScene, tile_pos: Vector2i) -> void:
	if tile_pos in placed_buildings:
		print("A building is already placed at ", tile_pos)
		return
	var building := building_scene.instantiate()
	var objectId = 1
	self.add_child(building,true)
	
	building.objectId = "rock1"
	building.position = Multihelper.map.tile_map.map_to_local(tile_pos)
	building.spawner = self
	
	placed_buildings[tile_pos] = building
	print("Placed building at ", tile_pos)
	
