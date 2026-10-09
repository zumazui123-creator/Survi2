extends BuildingEntity
class_name CookingStationBuilding

@export var input_item_id: String = "food"
@export var output_item_id: String = "cookedFood"
@export_range(0.1, 30.0, 0.5) var cooking_duration: float = 3.0

@onready var cooking_timer: Timer = $CookingTimer
@onready var world_map: Map = get_tree().get_first_node_in_group("world_map") as Map
var _world_spawner: WorldEntitySpawner
var _queued_food: int = 0


func can_accept_processing_item(item_id: StringName) -> bool:
	return String(item_id) == input_item_id


func _ready() -> void:
	super()
	_world_spawner = WorldEntitySpawner.get_for(self)
	if is_instance_valid(_world_spawner) \
			and not _world_spawner.pickup_spawned.is_connected(_on_pickup_spawned):
		_world_spawner.pickup_spawned.connect(_on_pickup_spawned)
	if not cooking_timer.timeout.is_connected(_on_cooking_timer_timeout):
		cooking_timer.timeout.connect(_on_cooking_timer_timeout)
	cooking_timer.wait_time = cooking_duration
	call_deferred("_scan_existing_pickups")


func _scan_existing_pickups() -> void:
	if not multiplayer.is_server() \
			or not is_instance_valid(_world_spawner) \
			or not is_instance_valid(_world_spawner.pickups_root):
		return
	for child: Node in _world_spawner.pickups_root.get_children():
		var pickup: WorldPickup = child as WorldPickup
		if pickup != null:
			_try_accept_pickup(pickup)


func _on_pickup_spawned(pickup: WorldPickup) -> void:
	if multiplayer.is_server():
		call_deferred("_try_accept_pickup", pickup)


func _try_accept_pickup(pickup: WorldPickup) -> void:
	if not is_instance_valid(pickup) \
			or not pickup.is_available_for_structure() \
			or pickup.itemId != input_item_id \
			or not is_instance_valid(world_map):
		return
	var pickup_tile: Vector2i = world_map.world_to_navigation_tile(pickup.global_position)
	var station_tile: Vector2i = world_map.world_to_navigation_tile(global_position)
	if pickup_tile != station_tile:
		return
	var consumed: int = pickup.consume_for_structure(pickup.stackCount)
	_queued_food += consumed
	if _queued_food > 0 and cooking_timer.is_stopped():
		cooking_timer.start()


func _on_cooking_timer_timeout() -> void:
	if not multiplayer.is_server() or _queued_food <= 0:
		return
	_queued_food -= 1
	var output_position: Vector2 = _find_output_position()
	_world_spawner.spawn_pickup(output_item_id, output_position, 1)
	if _queued_food > 0:
		cooking_timer.start()


func _find_output_position() -> Vector2:
	if not is_instance_valid(world_map):
		return global_position + Vector2(Constants.TILE_SIZE, 0.0)
	var origin: Vector2i = world_map.world_to_navigation_tile(global_position)
	var directions: Array[Vector2i] = [
		Vector2i.RIGHT,
		Vector2i.DOWN,
		Vector2i.LEFT,
		Vector2i.UP,
	]
	for direction: Vector2i in directions:
		var candidate: Vector2i = origin + direction
		if world_map.is_navigation_tile_walkable(candidate, true):
			return world_map.navigation_tile_to_world(candidate)
	return global_position
