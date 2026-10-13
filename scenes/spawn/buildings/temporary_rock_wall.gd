extends BuildingEntity
class_name TemporaryRockWallBuilding

@export_range(1.0, 60.0, 0.5) var lifetime_seconds: float = 9.0


func _ready() -> void:
	super()
	if multiplayer.is_server():
		_expire_after_delay()


func _expire_after_delay() -> void:
	await get_tree().create_timer(lifetime_seconds).timeout
	if is_instance_valid(self) and hp > 0.0:
		breakObject()
