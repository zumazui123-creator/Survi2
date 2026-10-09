extends Node
class_name StructureBurnTimer

signal expired

@export_range(1.0, 3600.0, 1.0) var burn_duration_seconds: float = 180.0

@onready var timer: Timer = $Timer


func start_burning() -> void:
	if not multiplayer.is_server():
		return
	timer.start(burn_duration_seconds)


func stop_burning() -> void:
	timer.stop()


func get_time_left() -> float:
	return timer.time_left


func _on_timer_timeout() -> void:
	if multiplayer.is_server():
		expired.emit()

