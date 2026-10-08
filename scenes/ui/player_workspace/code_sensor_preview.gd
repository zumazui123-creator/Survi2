extends VBoxContainer
class_name CodeSensorPreview

@onready var preview_text: RichTextLabel = %SensorPreviewText
@onready var variables_text: RichTextLabel = %VariablesText

var sensor: PlayerSensor
var _refresh_elapsed: float = 0.0


func _ready() -> void:
	set_process(false)
	_show_message("Sensor wird verbunden …")


func bind_sensor(value: PlayerSensor) -> void:
	sensor = value
	_refresh_elapsed = 0.0
	set_process(is_instance_valid(sensor))
	if is_instance_valid(sensor):
		_refresh()
	else:
		_show_message("Kein Sensor verfügbar")


func show_variables(variables: Dictionary) -> void:
	if not is_instance_valid(variables_text):
		return
	if variables.is_empty():
		variables_text.text = "Noch keine Variablen"
		return
	var names: Array = variables.keys()
	names.sort()
	var lines: PackedStringArray = PackedStringArray()
	for name_value: Variant in names:
		var variable_name: String = String(name_value)
		lines.append("%s = %s" % [variable_name, str(variables[name_value])])
	variables_text.text = "\n".join(lines)


func _process(delta: float) -> void:
	if not is_visible_in_tree() or not is_instance_valid(sensor):
		return
	_refresh_elapsed += delta
	if _refresh_elapsed < 0.5:
		return
	_refresh_elapsed = 0.0
	_refresh()


func _refresh() -> void:
	if not sensor.is_ready_to_scan():
		_show_message("Sensor wartet auf die Karte …")
		return
	var observation: Dictionary = sensor.scan()
	var map_value: Variant = observation.get("local_map", PackedByteArray())
	if not map_value is PackedByteArray:
		_show_message("Keine Sensordaten")
		return
	var local_map: PackedByteArray = map_value
	var side: int = sensor.get_map_side_length()
	if local_map.size() < PlayerSensor.CHANNEL_COUNT * side * side:
		_show_message("Unvollständige Sensordaten")
		return

	var lines: PackedStringArray = PackedStringArray()
	lines.append("Radius: %d Tiles" % sensor.scan_radius_tiles)
	lines.append("P Spieler  E Gegner  A Tier")
	lines.append("i Item  O Objekt  ~ Wasser")
	for y: int in range(side):
		var row: String = ""
		for x: int in range(side):
			row += _get_tile_symbol(local_map, side, x, y)
		lines.append(row)
	lines.append(_format_stats(observation))
	preview_text.text = "\n".join(lines)


func _get_tile_symbol(local_map: PackedByteArray, side: int, x: int, y: int) -> String:
	var center: int = sensor.scan_radius_tiles
	if x == center and y == center:
		return "P"
	if absi(x - center) + absi(y - center) > sensor.scan_radius_tiles:
		return " "
	if _read_channel(local_map, side, PlayerSensor.CHANNEL_ENEMY, x, y):
		return "E"
	if _read_channel(local_map, side, PlayerSensor.CHANNEL_ANIMAL, x, y):
		return "A"
	if _read_channel(local_map, side, PlayerSensor.CHANNEL_ITEM, x, y):
		return "i"
	if _read_channel(local_map, side, PlayerSensor.CHANNEL_OBJECT, x, y):
		return "O"
	if _read_channel(local_map, side, PlayerSensor.CHANNEL_GOAL, x, y):
		return "G"
	if _read_channel(local_map, side, PlayerSensor.CHANNEL_WATER, x, y):
		return "~"
	if _read_channel(local_map, side, PlayerSensor.CHANNEL_WALKABLE, x, y):
		return "."
	return "#"


func _read_channel(
		local_map: PackedByteArray,
		side: int,
		channel: int,
		x: int,
		y: int
	) -> bool:
	var index: int = channel * side * side + y * side + x
	return index >= 0 and index < local_map.size() and local_map[index] > 0


func _format_stats(observation: Dictionary) -> String:
	var stats_value: Variant = observation.get("stats", PackedFloat32Array())
	if not stats_value is PackedFloat32Array:
		return ""
	var stats: PackedFloat32Array = stats_value
	if stats.size() < PlayerSensor.STAT_COUNT:
		return ""
	return "HP %d%%  Wasser %d%%\nEssen %d%%  Mana %d%%" % [
		roundi(stats[PlayerSensor.STAT_HP] * 100.0),
		roundi(stats[PlayerSensor.STAT_HYDRATION] * 100.0),
		roundi(stats[PlayerSensor.STAT_FOOD] * 100.0),
		roundi(stats[PlayerSensor.STAT_MANA] * 100.0),
	]


func _show_message(message: String) -> void:
	if is_instance_valid(preview_text):
		preview_text.text = message
