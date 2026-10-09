extends BuildingEntity
class_name SensorTowerBuilding

@export_range(1, 20, 1) var sensor_radius_bonus: int = 5

var _modifier_id: StringName
var _modified_sensor: PlayerSensor
var _search_elapsed: float = 0.0


func _ready() -> void:
	super()
	_modifier_id = StringName("sensor_tower_%s" % get_instance_id())
	call_deferred("_apply_sensor_bonus")
	set_process(true)


func _process(delta: float) -> void:
	if is_instance_valid(_modified_sensor):
		set_process(false)
		return
	_search_elapsed += delta
	if _search_elapsed < 1.0:
		return
	_search_elapsed = 0.0
	_apply_sensor_bonus()


func _exit_tree() -> void:
	_remove_sensor_bonus()


func _apply_sensor_bonus() -> void:
	_remove_sensor_bonus()
	for candidate: Node in get_tree().get_nodes_in_group(Strings.GROUP_PLAYER):
		var player: Survi2Player = candidate as Survi2Player
		if player == null or int(String(player.name)) != builder_peer_id:
			continue
		if is_instance_valid(player.sensor):
			_modified_sensor = player.sensor
			_modified_sensor.set_radius_modifier(_modifier_id, sensor_radius_bonus)
			_modified_sensor.set_enemy_marking_source(_modifier_id, true)
			set_process(false)
		return


func _remove_sensor_bonus() -> void:
	if is_instance_valid(_modified_sensor):
		_modified_sensor.remove_radius_modifier(_modifier_id)
		_modified_sensor.set_enemy_marking_source(_modifier_id, false)
	_modified_sensor = null
