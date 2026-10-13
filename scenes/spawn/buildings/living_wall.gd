extends BuildingEntity
class_name LivingWallBuilding

@export_range(0.1, 20.0, 0.5) var regeneration_per_tick: float = 6.0

@onready var regeneration_timer: Timer = $RegenerationTimer


func _ready() -> void:
	super()
	if multiplayer.is_server():
		regeneration_timer.start()


func _on_regeneration_timer_timeout() -> void:
	if multiplayer.is_server() and hp > 0.0:
		hp = minf(max_hp, hp + regeneration_per_tick)
