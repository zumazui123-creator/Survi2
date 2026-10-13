extends RefCounted
class_name BiomeGenerator

const TEMPERATURE_FREQUENCY: float = 0.009
const MOISTURE_FREQUENCY: float = 0.011
const ELEVATION_FREQUENCY: float = 0.013
const REGION_DETAIL_FREQUENCY: float = 0.035
const MINIMUM_BIOME_RATIO: float = 0.025
const MINIMUM_BIOME_TILES: int = 64

var _temperature_noise: FastNoiseLite = FastNoiseLite.new()
var _moisture_noise: FastNoiseLite = FastNoiseLite.new()
var _elevation_noise: FastNoiseLite = FastNoiseLite.new()
var _region_detail_noise: FastNoiseLite = FastNoiseLite.new()


func generate(
		map_size: Vector2i,
		seed_value: int,
		definitions: Array[BiomeDefinition]
	) -> BiomeMapData:
	_configure_noise(_temperature_noise, seed_value ^ 0x54454D50, TEMPERATURE_FREQUENCY)
	_configure_noise(_moisture_noise, seed_value ^ 0x4D4F4953, MOISTURE_FREQUENCY)
	_configure_noise(_elevation_noise, seed_value ^ 0x454C4556, ELEVATION_FREQUENCY)
	_configure_noise(_region_detail_noise, seed_value ^ 0x44455441, REGION_DETAIL_FREQUENCY)

	var result: BiomeMapData = BiomeMapData.new()
	result.initialize(map_size)
	for y: int in range(map_size.y):
		for x: int in range(map_size.x):
			var tile: Vector2i = Vector2i(x, y)
			var temperature: float = _sample_normalized(_temperature_noise, tile)
			var wetness: float = _sample_normalized(_moisture_noise, tile)
			var elevation: float = _sample_normalized(_elevation_noise, tile)
			result.set_tile_data(
				tile,
				_classify_biome(temperature, wetness, elevation),
				temperature,
				wetness,
				elevation
			)

	_ensure_minimum_biome_regions(result, definitions, seed_value)
	return result


func _configure_noise(noise: FastNoiseLite, seed_value: int, frequency: float) -> void:
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = frequency
	noise.fractal_octaves = 4
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5


func _sample_normalized(noise: FastNoiseLite, tile: Vector2i) -> float:
	return clampf((noise.get_noise_2d(tile.x, tile.y) + 1.0) * 0.5, 0.0, 1.0)


func _classify_biome(
		temperature: float,
		wetness: float,
		elevation: float
	) -> StringName:
	if elevation >= 0.68:
		return &"mountain"
	if temperature <= 0.31:
		return &"snow"
	if temperature >= 0.66 and wetness <= 0.48:
		return &"desert"
	if wetness >= 0.67:
		return &"swamp"
	return &"forest"


func _ensure_minimum_biome_regions(
		data: BiomeMapData,
		definitions: Array[BiomeDefinition],
		seed_value: int
	) -> void:
	if data.size.x <= 0 or data.size.y <= 0:
		return
	var minimum_tiles: int = maxi(
		MINIMUM_BIOME_TILES,
		roundi(float(data.size.x * data.size.y) * MINIMUM_BIOME_RATIO)
	)
	var reserved_anchors: Array[Vector2i] = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x42494F4D

	for definition: BiomeDefinition in definitions:
		if definition == null or definition.biome_id.is_empty():
			continue
		var largest_region_size: int = _get_largest_region_size(
			data,
			definition.biome_id
		)
		# Each guaranteed region must fit both of its biome landmarks plus
		# their safety margins. The organic edge still keeps the result natural.
		var radius: int = 30
		if largest_region_size < minimum_tiles:
			radius = maxi(
				radius,
				ceili(sqrt(float(minimum_tiles) / PI) * 1.25)
			)
		var anchor: Vector2i = _find_best_anchor(
			data,
			definition.biome_id,
			radius,
			reserved_anchors,
			rng
		)
		reserved_anchors.append(anchor)
		_paint_organic_region(data, definition.biome_id, anchor, radius)
		data.set_guaranteed_region_center(definition.biome_id, anchor)


func _get_largest_region_size(data: BiomeMapData, biome_id: StringName) -> int:
	var visited: Dictionary[Vector2i, bool] = {}
	var largest_size: int = 0
	for y: int in range(data.size.y):
		for x: int in range(data.size.x):
			var tile: Vector2i = Vector2i(x, y)
			if visited.has(tile) or data.get_biome_id(tile) != biome_id:
				continue
			var open_tiles: Array[Vector2i] = [tile]
			var read_index: int = 0
			var region_size: int = 0
			visited[tile] = true
			while read_index < open_tiles.size():
				var current: Vector2i = open_tiles[read_index]
				read_index += 1
				region_size += 1
				for direction: Vector2i in [
					Vector2i.LEFT,
					Vector2i.RIGHT,
					Vector2i.UP,
					Vector2i.DOWN,
				]:
					var neighbor: Vector2i = current + direction
					if neighbor.x < 0 or neighbor.y < 0 \
							or neighbor.x >= data.size.x or neighbor.y >= data.size.y \
							or visited.has(neighbor) \
							or data.get_biome_id(neighbor) != biome_id:
						continue
					visited[neighbor] = true
					open_tiles.append(neighbor)
			largest_size = maxi(largest_size, region_size)
	return largest_size


func _find_best_anchor(
		data: BiomeMapData,
		biome_id: StringName,
		radius: int,
		reserved_anchors: Array[Vector2i],
		rng: RandomNumberGenerator
	) -> Vector2i:
	var margin_x: int = mini(radius + 8, maxi(floori(float(data.size.x) / 3.0), 1))
	var margin_y: int = mini(radius + 8, maxi(floori(float(data.size.y) / 3.0), 1))
	var best_tile: Vector2i = Vector2i(
		floori(float(data.size.x) / 2.0),
		floori(float(data.size.y) / 2.0)
	)
	var best_score: float = -INF
	var anchor_spacing: int = maxi(radius * 2, 58)
	for _attempt: int in range(600):
		var tile: Vector2i = Vector2i(
			rng.randi_range(margin_x, maxi(margin_x, data.size.x - margin_x - 1)),
			rng.randi_range(margin_y, maxi(margin_y, data.size.y - margin_y - 1))
		)
		if _is_too_close_to_anchors(tile, reserved_anchors, anchor_spacing):
			continue
		var score: float = _get_biome_suitability(data, tile, biome_id)
		if score > best_score:
			best_score = score
			best_tile = tile
	return best_tile


func _get_biome_suitability(
		data: BiomeMapData,
		tile: Vector2i,
		biome_id: StringName
	) -> float:
	var temperature: float = data.get_temperature(tile)
	var wetness: float = data.get_moisture(tile)
	var elevation: float = data.get_elevation(tile)
	match biome_id:
		&"mountain":
			return elevation
		&"snow":
			return 1.0 - temperature
		&"desert":
			return temperature + (1.0 - wetness) * 0.8
		&"swamp":
			return wetness + (1.0 - elevation) * 0.25
		_:
			return wetness * 0.45 + (1.0 - absf(temperature - 0.5)) * 0.55


func _is_too_close_to_anchors(
		tile: Vector2i,
		anchors: Array[Vector2i],
		minimum_distance: int
	) -> bool:
	var minimum_distance_squared: int = minimum_distance * minimum_distance
	for anchor: Vector2i in anchors:
		if tile.distance_squared_to(anchor) < minimum_distance_squared:
			return true
	return false


func _paint_organic_region(
		data: BiomeMapData,
		biome_id: StringName,
		anchor: Vector2i,
		radius: int
	) -> void:
	var maximum_radius: float = float(radius) * 1.3
	for y: int in range(maxi(anchor.y - radius - 3, 0), mini(anchor.y + radius + 4, data.size.y)):
		for x: int in range(maxi(anchor.x - radius - 3, 0), mini(anchor.x + radius + 4, data.size.x)):
			var tile: Vector2i = Vector2i(x, y)
			var detail: float = _region_detail_noise.get_noise_2d(x, y) * 2.5
			if Vector2(tile - anchor).length() <= maximum_radius + detail:
				data.set_biome_id(tile, biome_id)
