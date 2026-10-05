extends Node
class_name NavigationBlocker

var _world_map: Map
var _tiles: Array[Vector2i] = []
var _navigation_generation := -1
var _registered := false


func register_tiles(tiles: Array[Vector2i]) -> void:
	release()
	_world_map = get_tree().get_first_node_in_group("world_map") as Map
	if _world_map == null:
		push_warning("NavigationBlocker could not find the active Map")
		return
	_navigation_generation = _world_map.navigation_generation
	_tiles = tiles.duplicate()
	for tile in _tiles:
		_world_map.add_navigation_blocker(tile)
	_registered = true


func release() -> void:
	if not _registered:
		return
	_registered = false
	if is_instance_valid(_world_map) \
			and _world_map.navigation_generation == _navigation_generation:
		for tile in _tiles:
			_world_map.remove_navigation_blocker(tile)
	_tiles.clear()
	_world_map = null


func _exit_tree() -> void:
	release()
