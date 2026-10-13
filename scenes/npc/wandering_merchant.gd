extends CharacterBody2D
class_name WanderingMerchant

@export_range(1, 8, 1) var wander_radius_tiles: int = 4
@export_range(0.5, 10.0, 0.5) var move_interval: float = 3.0

@onready var world_map: Map = get_tree().get_first_node_in_group("world_map") as Map
@onready var move_timer: Timer = $MoveTimer
var home_tile: Vector2i
var _world_spawner: WorldEntitySpawner


func _ready() -> void:
	home_tile = world_map.world_to_navigation_tile(global_position) \
		if is_instance_valid(world_map) else Vector2i.ZERO
	_world_spawner = WorldEntitySpawner.get_for(self)
	if is_instance_valid(_world_spawner) \
			and not _world_spawner.pickup_spawned.is_connected(_on_pickup_spawned):
		_world_spawner.pickup_spawned.connect(_on_pickup_spawned)
	move_timer.wait_time = move_interval
	if multiplayer.is_server():
		move_timer.start()


func _on_move_timer_timeout() -> void:
	if not multiplayer.is_server() or not is_instance_valid(world_map):
		return
	var current: Vector2i = world_map.world_to_navigation_tile(global_position)
	var directions: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	directions.shuffle()
	for direction: Vector2i in directions:
		var destination: Vector2i = current + direction
		if destination.distance_to(home_tile) > float(wander_radius_tiles):
			continue
		if not world_map.is_navigation_tile_walkable(destination, true, get_instance_id()):
			continue
		global_position = world_map.navigation_tile_to_world(destination)
		return


func _on_pickup_spawned(pickup: WorldPickup) -> void:
	if multiplayer.is_server():
		call_deferred("_try_trade", pickup)


func _try_trade(pickup: WorldPickup) -> void:
	if not is_instance_valid(pickup) or not pickup.is_available_for_structure():
		return
	if pickup.global_position.distance_to(global_position) > 1.5 * Constants.TILE_SIZE:
		return
	var result_item: String = ""
	if pickup.itemId == "iron":
		result_item = "energy_drink"
	elif pickup.itemId == "food":
		result_item = "magicHerb"
	if result_item.is_empty():
		return
	if pickup.consume_for_structure(1) <= 0:
		return
	_world_spawner.spawn_pickup(
		result_item,
		global_position + Vector2(Constants.TILE_SIZE, 0.0),
		1
	)


func getDamage(_causer: Node, _amount: float, _damage_type: StringName) -> void:
	pass
