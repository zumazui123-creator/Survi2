extends RefCounted
class_name TreeState

enum Representation {
	PASSIVE,
	ACTIVE,
	DESTROYED,
}

var tile: Vector2i
var object_id: String
var max_hp: float
var current_hp: float
var representation: Representation = Representation.PASSIVE
var active_node: TreeEntity
var passive_instance_index: int = -1
var highlighted: bool = false


func _init(spawn_data: TreeSpawnData, initial_hp: float) -> void:
	tile = spawn_data.tile
	object_id = spawn_data.object_id
	max_hp = initial_hp
	current_hp = initial_hp


func mark_active(tree: TreeEntity) -> void:
	active_node = tree
	representation = Representation.ACTIVE


func mark_passive() -> void:
	active_node = null
	representation = Representation.PASSIVE


func mark_destroyed() -> void:
	current_hp = 0.0
	active_node = null
	representation = Representation.DESTROYED


func restore() -> void:
	current_hp = max_hp
	active_node = null
	representation = Representation.PASSIVE


func is_destroyed() -> bool:
	return representation == Representation.DESTROYED
