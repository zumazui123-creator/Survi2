extends Node
class_name PlayerBiomeEffects

signal biome_changed(biome_id: StringName, definition: BiomeDefinition)

@export_group("References")
@export var player: CharacterBody2D
@export var stats: PlayerStats
@export var movement: PlayerMovement

@export_group("Timing")
@export_range(0.1, 2.0, 0.1) var effect_interval: float = 0.5

var _world_map: Map
var _elapsed: float = 0.0
var _current_biome_id: StringName = &""


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < effect_interval:
		return
	var elapsed_effect_time: float = _elapsed
	_elapsed = 0.0
	_update_biome_effects(elapsed_effect_time)


func _exit_tree() -> void:
	if is_instance_valid(movement) and is_instance_valid(player) \
			and player.is_multiplayer_authority():
		movement.set_environment_speed_multiplier(1.0)


func get_current_biome_id() -> StringName:
	return _current_biome_id


func _update_biome_effects(elapsed_effect_time: float) -> void:
	if not _resolve_world_map() or not is_instance_valid(player):
		return
	var tile: Vector2i = _world_map.world_to_navigation_tile(player.global_position)
	var definition: BiomeDefinition = _world_map.get_biome_definition_at(tile)
	var biome_id: StringName = definition.biome_id if definition != null else &""
	if biome_id != _current_biome_id:
		_current_biome_id = biome_id
		biome_changed.emit(_current_biome_id, definition)

	if is_instance_valid(movement) and player.is_multiplayer_authority():
		var speed_multiplier: float = definition.movement_speed_multiplier \
			if definition != null else 1.0
		movement.set_environment_speed_multiplier(speed_multiplier)

	if not multiplayer.is_server() or not is_instance_valid(stats) or stats.hp <= 0.0:
		return
	if definition == null:
		return
	if definition.hydration_drain_per_second > 0.0:
		stats.hydration -= definition.hydration_drain_per_second * elapsed_effect_time
	if definition.damage_per_second > 0.0:
		stats.apply_damage(definition.damage_per_second * elapsed_effect_time)


func _resolve_world_map() -> bool:
	if not is_instance_valid(_world_map):
		_world_map = get_tree().get_first_node_in_group("world_map") as Map
	return is_instance_valid(_world_map)
