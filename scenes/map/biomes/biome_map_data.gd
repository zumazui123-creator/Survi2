extends RefCounted
class_name BiomeMapData

var size: Vector2i = Vector2i.ZERO
var _biome_ids: PackedStringArray = PackedStringArray()
var _temperatures: PackedFloat32Array = PackedFloat32Array()
var _moisture: PackedFloat32Array = PackedFloat32Array()
var _elevations: PackedFloat32Array = PackedFloat32Array()
var _guaranteed_region_centers: Dictionary[StringName, Vector2i] = {}


func initialize(map_size: Vector2i) -> void:
	size = Vector2i(maxi(map_size.x, 0), maxi(map_size.y, 0))
	var tile_count: int = size.x * size.y
	_biome_ids.resize(tile_count)
	_temperatures.resize(tile_count)
	_moisture.resize(tile_count)
	_elevations.resize(tile_count)


func set_tile_data(
		tile: Vector2i,
		biome_id: StringName,
		temperature: float,
		wetness: float,
		elevation: float
	) -> void:
	var index: int = _get_index(tile)
	if index < 0:
		return
	_biome_ids[index] = String(biome_id)
	_temperatures[index] = temperature
	_moisture[index] = wetness
	_elevations[index] = elevation


func set_biome_id(tile: Vector2i, biome_id: StringName) -> void:
	var index: int = _get_index(tile)
	if index >= 0:
		_biome_ids[index] = String(biome_id)


func set_guaranteed_region_center(biome_id: StringName, tile: Vector2i) -> void:
	_guaranteed_region_centers[biome_id] = tile


func get_guaranteed_region_center(biome_id: StringName) -> Vector2i:
	return _guaranteed_region_centers.get(biome_id, Vector2i(-1, -1))


func get_guaranteed_region_centers() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for center: Vector2i in _guaranteed_region_centers.values():
		result.append(center)
	return result


func get_biome_id(tile: Vector2i) -> StringName:
	var index: int = _get_index(tile)
	if index < 0 or _biome_ids[index].is_empty():
		return &"forest"
	return StringName(_biome_ids[index])


func get_temperature(tile: Vector2i) -> float:
	var index: int = _get_index(tile)
	return _temperatures[index] if index >= 0 else 0.5


func get_moisture(tile: Vector2i) -> float:
	var index: int = _get_index(tile)
	return _moisture[index] if index >= 0 else 0.5


func get_elevation(tile: Vector2i) -> float:
	var index: int = _get_index(tile)
	return _elevations[index] if index >= 0 else 0.5


func _get_index(tile: Vector2i) -> int:
	if tile.x < 0 or tile.y < 0 or tile.x >= size.x or tile.y >= size.y:
		return -1
	return tile.y * size.x + tile.x
