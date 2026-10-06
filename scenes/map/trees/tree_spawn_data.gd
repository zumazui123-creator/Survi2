extends RefCounted
class_name TreeSpawnData

var tile: Vector2i
var object_id: String


func _init(
		spawn_tile: Vector2i = Vector2i.ZERO,
		spawn_object_id: String = "tree0"
	) -> void:
	tile = spawn_tile
	object_id = spawn_object_id
