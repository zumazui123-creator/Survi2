extends Node

@export var world_map: Map

func get_position_of_obj():
	return world_map.tile_map.map_to_local(world_map.walkable_tiles.pick_random())

func createObject(scene_path: String, position):
	var object_scene = load(scene_path)
	var object 	 = object_scene.instantiate()
	var objectId = Items.objects.keys().pick_random()
	object.objectId = objectId
	
	if position:
		object.position = get_position_of_obj()
	else:
		object.position = position
		
	return object
	

		
