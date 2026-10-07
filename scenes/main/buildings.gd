extends Node2D
class_name Buildings

@export var world_map: Map

var placed_buildings : Dictionary[Vector2i, Node] = {}

func place_building(building_scene: PackedScene, tile_pos: Vector2i) -> bool:
	if not multiplayer.is_server():
		return false
	var building: NavigationBuilding = building_scene.instantiate() as NavigationBuilding
	if building == null:
		push_warning("Building scene must use NavigationBuilding")
		return false
	var occupied_tiles: Array[Vector2i] = building.get_navigation_tiles(tile_pos)
	for occupied_tile in occupied_tiles:
		if occupied_tile in placed_buildings \
				or not world_map.is_navigation_tile_walkable(occupied_tile, true):
			print("Cannot place a building at ", tile_pos)
			building.free()
			return false
	self.add_child(building, true)
	if building.objectId.is_empty():
		building.objectId = "rock1"
	building.global_position = world_map.navigation_tile_to_world(tile_pos)
	building.spawner = self
	building.register_navigation_blockers(occupied_tiles)
	for occupied_tile in occupied_tiles:
		placed_buildings[occupied_tile] = building
	print("Placed building at ", tile_pos)
	return true


func remove_building(building: Node, occupied_tiles: Array[Vector2i]) -> void:
	for tile in occupied_tiles:
		if placed_buildings.get(tile) == building:
			placed_buildings.erase(tile)
	
