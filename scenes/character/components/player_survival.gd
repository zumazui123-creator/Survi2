extends Node
class_name PlayerSurvival

const MINUTES_PER_DAY := 1440
const MINUTES_PER_HOUR := 60

@export var player: CharacterBody2D
@export var stats: PlayerStats
@export var hydration_interval_hours: float = 2.0
@export var food_interval_hours: float = 5.0

var _last_absolute_minute := -1
var _hydration_elapsed_minutes := 0.0
var _food_elapsed_minutes := 0.0


func _ready() -> void:
	if not player.is_multiplayer_authority():
		return
	GameTime.time_tick.connect(_on_time_tick)


func _on_time_tick(day: int, hour: int, minute: int) -> void:
	var absolute_minute := day * MINUTES_PER_DAY + hour * MINUTES_PER_HOUR + minute
	if _last_absolute_minute < 0:
		_last_absolute_minute = absolute_minute
		return

	var elapsed_minutes := maxi(absolute_minute - _last_absolute_minute, 0)
	_last_absolute_minute = absolute_minute
	_hydration_elapsed_minutes += elapsed_minutes
	_food_elapsed_minutes += elapsed_minutes

	_hydration_elapsed_minutes = _apply_drain(
		_hydration_elapsed_minutes,
		maxf(hydration_interval_hours * MINUTES_PER_HOUR, 1.0),
		true
	)
	_food_elapsed_minutes = _apply_drain(
		_food_elapsed_minutes,
		maxf(food_interval_hours * MINUTES_PER_HOUR, 1.0),
		false
	)


func _apply_drain(elapsed_minutes: float, interval_minutes: float, is_hydration: bool) -> float:
	var drain_count := floori(elapsed_minutes / interval_minutes)
	if drain_count <= 0:
		return elapsed_minutes

	if is_hydration:
		stats.hydration -= drain_count
	else:
		stats.food -= drain_count
	return elapsed_minutes - drain_count * interval_minutes
