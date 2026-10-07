extends Node
class_name PlayerComboController

@export_group("References")
@export var player: CharacterBody2D
@export var combat: PlayerCombat
@export var stats: PlayerStats
@export var effects: PlayerComboEffects

@export_group("Definitions")
@export var combo_definitions: Array[ComboDefinition] = []

@onready var world_map: Map = get_tree().get_first_node_in_group("world_map") as Map


func _ready() -> void:
	# This component is server-owned even though the Player node itself belongs to
	# its controlling peer. It lets the server authoritatively broadcast effects.
	set_multiplayer_authority(1, false)


func try_execute_combo(sequence: PackedStringArray) -> bool:
	var definition: ComboDefinition = _find_combo(sequence)
	if definition == null:
		return false
	if multiplayer.is_server():
		_execute_authorized_combo(definition)
	else:
		request_combo.rpc_id(1, definition.combo_id)
	return true


func get_code_commands() -> PackedStringArray:
	var code_commands: PackedStringArray = PackedStringArray()
	for definition: ComboDefinition in combo_definitions:
		if definition == null or definition.code_command.is_empty():
			continue
		code_commands.append(definition.code_command)
	return code_commands


@rpc("any_peer", "reliable")
func request_combo(combo_id: StringName) -> void:
	if not multiplayer.is_server() or not _is_authorized_sender():
		return
	var definition: ComboDefinition = _find_combo_by_id(combo_id)
	if definition == null:
		return
	_execute_authorized_combo(definition)


func _execute_authorized_combo(definition: ComboDefinition) -> void:
	if not is_instance_valid(stats) or not stats.try_consume_mana(definition.mana_cost):
		return
	_apply_damage(definition)
	play_combo_effect.rpc(definition.combo_id)


@rpc("authority", "call_local", "reliable")
func play_combo_effect(combo_id: StringName) -> void:
	var definition: ComboDefinition = _find_combo_by_id(combo_id)
	if definition == null:
		return
	var directions: Array[Vector2i] = _get_target_directions(definition)
	if is_instance_valid(effects):
		effects.play_effect(definition.visual_effect, directions, definition.effect_duration)


func _find_combo(sequence: PackedStringArray) -> ComboDefinition:
	for definition: ComboDefinition in combo_definitions:
		if definition != null and definition.matches(sequence):
			return definition
	return null


func _find_combo_by_id(combo_id: StringName) -> ComboDefinition:
	for definition: ComboDefinition in combo_definitions:
		if definition != null and definition.combo_id == combo_id:
			return definition
	return null


func _get_target_directions(definition: ComboDefinition) -> Array[Vector2i]:
	var directions: Array[Vector2i] = []
	for direction_action: String in definition.target_directions:
		if not Strings.direction_map.has(direction_action):
			continue
		directions.append(Strings.direction_map[direction_action])
	return directions


func _apply_damage(definition: ComboDefinition) -> void:
	if not is_instance_valid(player) or not is_instance_valid(world_map):
		return
	var origin_tile: Vector2i = world_map.world_to_navigation_tile(player.global_position)
	var pulse_count: int = maxi(definition.damage_pulse_count, 1)
	_apply_damage_pulse(definition, origin_tile)
	for pulse_index: int in range(1, pulse_count):
		var delay: float = definition.damage_pulse_interval * float(pulse_index)
		var timer: SceneTreeTimer = get_tree().create_timer(delay)
		timer.timeout.connect(_apply_damage_pulse.bind(definition, origin_tile))


func _apply_damage_pulse(definition: ComboDefinition, origin_tile: Vector2i) -> void:
	if not is_instance_valid(player) or not is_instance_valid(combat) or not is_instance_valid(world_map):
		return
	var target_tile_hits: Dictionary[Vector2i, int] = _get_target_tile_hits(definition, origin_tile)
	if target_tile_hits.is_empty():
		return

	var base_damage: float = combat.get_combo_damage(definition.damage_multiplier)
	for candidate: Node in get_tree().get_nodes_in_group(Strings.GROUP_DAMAGEABLE):
		if candidate == player or not candidate.has_method("getDamage"):
			continue
		var damageable: Node2D = candidate as Node2D
		if not is_instance_valid(damageable) or damageable.is_queued_for_deletion():
			continue
		var target_tile: Vector2i = world_map.world_to_navigation_tile(damageable.global_position)
		if not target_tile_hits.has(target_tile):
			continue
		var hit_count: int = target_tile_hits[target_tile]
		var damage: float = base_damage * float(hit_count)
		damageable.call("getDamage", combat, damage, combat.stats.damage_type)


func _get_target_tile_hits(
		definition: ComboDefinition,
		origin_tile: Vector2i
	) -> Dictionary[Vector2i, int]:
	var target_tile_hits: Dictionary[Vector2i, int] = {}
	for direction_index: int in range(definition.target_directions.size()):
		var direction_action: String = definition.target_directions[direction_index]
		if not Strings.direction_map.has(direction_action):
			continue
		var direction: Vector2i = Strings.direction_map[direction_action]
		var target_tile: Vector2i = origin_tile + direction
		var previous_hit_count: int = int(target_tile_hits.get(target_tile, 0))
		target_tile_hits[target_tile] = previous_hit_count + definition.get_target_hit_count(direction_index)
	return target_tile_hits


func _is_authorized_sender() -> bool:
	var sender_id: int = multiplayer.get_remote_sender_id()
	return sender_id == 0 or sender_id == player.get_multiplayer_authority()
