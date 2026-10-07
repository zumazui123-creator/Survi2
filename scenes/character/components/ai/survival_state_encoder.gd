extends RefCounted
class_name SurvivalStateEncoder

const TRACKED_CHANNELS: Array[int] = [
	PlayerSensor.CHANNEL_WATER,
	PlayerSensor.CHANNEL_ITEM,
	PlayerSensor.CHANNEL_ANIMAL,
	PlayerSensor.CHANNEL_ENEMY,
	PlayerSensor.CHANNEL_OBJECT,
]
const TRACKED_LABELS: Array[String] = [
	"water",
	"item",
	"animal",
	"enemy",
	"object",
]
const MAX_DISTANCE_BUCKET: int = 9

var stat_bin_count: int = 4
var distance_bin_size: int = 3


func configure(value_stat_bin_count: int, value_distance_bin_size: int) -> void:
	stat_bin_count = maxi(2, value_stat_bin_count)
	distance_bin_size = maxi(1, value_distance_bin_size)


func encode(observation: Dictionary) -> String:
	var parts: Array[String] = []
	_encode_stats(observation, parts)
	_encode_action_mask(observation, parts)

	var local_map: PackedByteArray = observation.get("local_map", PackedByteArray())
	var side: int = _get_map_side(local_map)
	if side <= 0:
		parts.append("map=invalid")
	else:
		for tracked_index: int in range(TRACKED_CHANNELS.size()):
			parts.append(
				"%s=%s" % [
					TRACKED_LABELS[tracked_index],
					_nearest_signature(local_map, side, TRACKED_CHANNELS[tracked_index]),
				]
			)
	_encode_goal_delta(observation, parts)
	return "|".join(parts)


func get_description() -> String:
	return "%d Statistik-Bins, %d Tiles pro Distanz-Bin" % [
		stat_bin_count,
		distance_bin_size,
	]


func _encode_stats(observation: Dictionary, parts: Array[String]) -> void:
	var stats: PackedFloat32Array = observation.get("stats", PackedFloat32Array())
	for stat_index: int in range(PlayerSensor.STAT_COUNT):
		var value: float = stats[stat_index] if stat_index < stats.size() else 0.0
		parts.append("stat%d=%d" % [stat_index, _quantize_stat(value)])


func _encode_action_mask(observation: Dictionary, parts: Array[String]) -> void:
	var action_mask: PackedByteArray = observation.get("action_mask", PackedByteArray())
	var mask_bits: int = 0
	for action: int in range(action_mask.size()):
		if action_mask[action] != 0:
			mask_bits |= 1 << action
	parts.append("mask=%d" % mask_bits)


func _encode_goal_delta(observation: Dictionary, parts: Array[String]) -> void:
	var goal_delta: PackedFloat32Array = observation.get("goal_delta", PackedFloat32Array())
	if goal_delta.size() < 2:
		parts.append("goal=none")
		return
	var delta: Vector2i = Vector2i(roundi(goal_delta[0]), roundi(goal_delta[1]))
	parts.append("goal=%s" % _vector_signature(delta))


func _get_map_side(local_map: PackedByteArray) -> int:
	if local_map.is_empty() or local_map.size() % PlayerSensor.CHANNEL_COUNT != 0:
		return 0
	var cells_per_channel: int = int(local_map.size() / PlayerSensor.CHANNEL_COUNT)
	var side: int = roundi(sqrt(float(cells_per_channel)))
	return side if side * side == cells_per_channel else 0


func _nearest_signature(local_map: PackedByteArray, side: int, channel: int) -> String:
	var channel_offset: int = channel * side * side
	var radius: int = int(side / 2)
	var nearest_delta: Vector2i = Vector2i.ZERO
	var nearest_distance: int = 2147483647
	for local_y: int in range(side):
		for local_x: int in range(side):
			var index: int = channel_offset + local_y * side + local_x
			if index < 0 or index >= local_map.size() or local_map[index] == 0:
				continue
			var delta: Vector2i = Vector2i(local_x - radius, local_y - radius)
			var distance: int = absi(delta.x) + absi(delta.y)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_delta = delta
	if nearest_distance == 2147483647:
		return "none"
	return _vector_signature(nearest_delta)


func _vector_signature(delta: Vector2i) -> String:
	var distance: int = absi(delta.x) + absi(delta.y)
	return "%d,%d,%d" % [
		_sign_int(delta.x),
		_sign_int(delta.y),
		_distance_bucket(distance),
	]


func _quantize_stat(value: float) -> int:
	return mini(stat_bin_count - 1, int(clampf(value, 0.0, 1.0) * stat_bin_count))


func _distance_bucket(distance: int) -> int:
	return mini(MAX_DISTANCE_BUCKET, int(distance / distance_bin_size))


func _sign_int(value: int) -> int:
	if value < 0:
		return -1
	if value > 0:
		return 1
	return 0
