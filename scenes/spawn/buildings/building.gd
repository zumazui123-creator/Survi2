extends StaticBody2D
class_name BuildingEntity

@export var building_id: StringName
@export var builder_peer_id: int = 1

var definition: BuildingDefinition
var hp: float = 40.0
var max_hp: float = 40.0
var spawner: Node
var navigation_tiles: Array[Vector2i] = []
var loaded: bool = false


func _ready() -> void:
	if definition == null and not building_id.is_empty():
		var manager: Node = get_tree().get_first_node_in_group("building_manager")
		if manager != null and manager.has_method("get_definition"):
			definition = manager.call("get_definition", building_id) as BuildingDefinition
	_apply_definition()


func configure(value: BuildingDefinition, owner_peer_id: int) -> void:
	definition = value
	building_id = value.building_id if value != null else &""
	builder_peer_id = owner_peer_id
	_apply_definition()


func getDamage(causer: Node, amount: float, damage_type: StringName) -> void:
	if not loaded or hp <= 0.0:
		return
	var required_tool: StringName = definition.required_tool
	var tool_damage: float = amount * 2.0 if damage_type == required_tool else amount
	var total_damage: float = tool_damage * _get_protection_multiplier()
	$AnimationPlayer.play("shake")
	$hitParticle.emitting = true
	hp -= total_damage
	if hp > 0.0:
		return
	if is_instance_valid(causer) \
			and causer.is_in_group("player") \
			and causer.has_signal("object_destroyed"):
		causer.emit_signal("object_destroyed")
	startBreaking()


func _get_protection_multiplier() -> float:
	var multiplier: float = 1.0
	for candidate: Node in get_tree().get_nodes_in_group(&"building_protector"):
		if candidate == self or not candidate.has_method("get_damage_multiplier_for"):
			continue
		multiplier = minf(
			multiplier,
			float(candidate.call("get_damage_multiplier_for", self))
		)
	return clampf(multiplier, 0.1, 1.0)


func startBreaking() -> void:
	$AnimationPlayer.play("break")


func breakObject() -> void:
	if not multiplayer.is_server():
		return
	$NavigationBlocker.release()
	if is_instance_valid(spawner) and spawner.has_method("remove_building"):
		spawner.call("remove_building", self)
	spawnDrops()
	queue_free()


func spawnDrops() -> void:
	if definition == null:
		return
	var entity_spawner: WorldEntitySpawner = WorldEntitySpawner.get_for(self)
	if entity_spawner == null:
		return
	for drop_value: Variant in definition.drops.keys():
		var drop: String = String(drop_value)
		var amount_data: Dictionary = definition.drops.get(drop_value, {})
		var minimum: int = int(amount_data.get("min", 0))
		var maximum: int = int(amount_data.get("max", minimum))
		entity_spawner.spawn_pickups(
			drop,
			global_position,
			randi_range(minimum, maximum)
		)


func register_navigation_blockers(tiles: Array[Vector2i]) -> void:
	navigation_tiles = tiles.duplicate()
	if definition != null and not definition.blocks_navigation:
		return
	var navigation_blocker: NavigationBlocker = get_node_or_null(
		"NavigationBlocker"
	) as NavigationBlocker
	if navigation_blocker != null:
		navigation_blocker.register_tiles(navigation_tiles)


func get_navigation_tiles(origin: Vector2i) -> Array[Vector2i]:
	if definition == null:
		return [origin]
	return definition.get_occupied_tiles(origin)


func _apply_definition() -> void:
	loaded = false
	if definition == null:
		return
	building_id = definition.building_id
	max_hp = definition.max_hp
	hp = max_hp
	var sprite: Sprite2D = get_node_or_null("Sprite") as Sprite2D
	if sprite != null and definition.texture != null:
		sprite.texture = definition.texture
	loaded = true
