extends RefCounted
class_name WorldEventNavigationGraph

## Shared AStar2D graph for actors that travel as part of a world event.
## The graph plans on map-tile coordinates. Transient actor collisions are
## deliberately handled by Map's reservation system, not by rebuilding AStar2D.

const CARDINAL_CONNECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN]

var _astar: AStar2D = AStar2D.new()
var _world_map: Map
var _point_id_by_tile: Dictionary[Vector2i, int] = {}
var _tile_by_point_id: Dictionary[int, Vector2i] = {}
var _built_revision: int = -1
var _built_generation: int = -1


func configure(world_map: Map) -> void:
	if _world_map == world_map:
		return
	_world_map = world_map
	invalidate()


func invalidate() -> void:
	_built_revision = -1
	_built_generation = -1
	_astar.clear()
	_point_id_by_tile.clear()
	_tile_by_point_id.clear()


func find_path(from_tile: Vector2i, to_tile: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not _ensure_graph():
		return result

	var from_id: int = _resolve_point_id(from_tile)
	var to_id: int = _resolve_point_id(to_tile)
	if from_id < 0 or to_id < 0:
		return result
	var point_path: PackedInt64Array = _astar.get_id_path(from_id, to_id)
	for point_id: int in point_path:
		if _tile_by_point_id.has(point_id):
			result.append(_tile_by_point_id[point_id])
	return result


func has_tile(tile: Vector2i) -> bool:
	return _ensure_graph() and _point_id_by_tile.has(tile)


func _ensure_graph() -> bool:
	if not is_instance_valid(_world_map) or not _world_map.astar_ready:
		return false
	if _built_revision != _world_map.navigation_revision \
			or _built_generation != _world_map.navigation_generation:
		_rebuild()
	return _astar.get_point_count() > 0


func _rebuild() -> void:
	_astar.clear()
	_point_id_by_tile.clear()
	_tile_by_point_id.clear()
	_astar.reserve_space(_world_map.walkable_tiles.size())

	var next_point_id: int = 0
	for tile: Vector2i in _world_map.walkable_tiles:
		if not _world_map.is_navigation_tile_walkable(tile):
			continue
		_point_id_by_tile[tile] = next_point_id
		_tile_by_point_id[next_point_id] = tile
		_astar.add_point(next_point_id, Vector2(tile))
		next_point_id += 1

	for tile: Vector2i in _point_id_by_tile:
		var point_id: int = _point_id_by_tile[tile]
		for direction: Vector2i in CARDINAL_CONNECTIONS:
			var neighbor: Vector2i = tile + direction
			if not _point_id_by_tile.has(neighbor):
				continue
			_astar.connect_points(point_id, _point_id_by_tile[neighbor], true)

	_built_revision = _world_map.navigation_revision
	_built_generation = _world_map.navigation_generation


func _resolve_point_id(tile: Vector2i) -> int:
	if _point_id_by_tile.has(tile):
		return _point_id_by_tile[tile]
	return _astar.get_closest_point(Vector2(tile))
