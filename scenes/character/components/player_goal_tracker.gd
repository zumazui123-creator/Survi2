extends Node
class_name PlayerGoalTracker

signal goal_reached()

@export var player: CharacterBody2D
@export var movement: PlayerMovement
@export var stats: PlayerStats

@onready var world_map: Map = get_tree().get_first_node_in_group("world_map")

var is_completed := false


func _ready() -> void:
	stats.terminated = false
	movement.tile_step_finished.connect(_on_tile_step_finished)


func reset_goal() -> void:
	is_completed = false
	stats.terminated = false


func _on_tile_step_finished(map_position: Vector2i) -> void:
	if is_completed or not player.is_multiplayer_authority():
		return
	if Multihelper.level.get("end", "") != Constants.END_LABY:
		return
	if not is_instance_valid(world_map):
		return
	if map_position != world_map.endPosition:
		return

	is_completed = true
	stats.terminated = true
	goal_reached.emit()
