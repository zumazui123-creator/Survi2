extends StaticBody2D
class_name NavigationBuilding

@export var objectId: String = "":
	set(value):
		objectId = value
		if is_node_ready():
			_apply_object_definition()

var data: Dictionary = {}
var hp: float = 40.0
var spawner: Node2D
var loaded: bool = false
var navigation_tiles: Array[Vector2i] = []
@export var navigation_footprint: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i.ZERO, Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]


func _ready() -> void:
	_apply_object_definition()


func getDamage(causer: Node, amount: float, damage_type: StringName) -> void:
	if not loaded:
		return
	if hp <= 0:
		return
	var required_tool: StringName = StringName(data.get("tool", ""))
	var total_damage: float = amount * 2.0 if damage_type == required_tool else amount
	$AnimationPlayer.play("shake")
	$hitParticle.emitting = true
	hp -= total_damage
	if hp <= 0:
		if is_instance_valid(causer) \
				and causer.is_in_group("player") \
				and causer.has_signal("object_destroyed"):
			causer.emit_signal("object_destroyed")
		startBreaking()


func startBreaking() -> void:
	$AnimationPlayer.play("break")


func breakObject() -> void:
	if not multiplayer.is_server():
		return
	$NavigationBlocker.release()
	if is_instance_valid(spawner):
		spawner.remove_building(self, navigation_tiles)
	queue_free()
	spawnDrops()

func spawnDrops() -> void:
	var drops: Dictionary = data.get("drops", {})
	for drop_value: Variant in drops.keys():
		var drop: String = String(drop_value)
		var amount_data: Dictionary = drops.get(drop, {})
		var minimum: int = int(amount_data.get("min", 0))
		var maximum: int = int(amount_data.get("max", minimum))
		WorldEntitySpawner.get_for(self).spawn_pickups(
			drop,
			global_position,
			randi_range(minimum, maximum)
		)


func register_navigation_blockers(tiles: Array[Vector2i]) -> void:
	navigation_tiles = tiles.duplicate()
	$NavigationBlocker.register_tiles(navigation_tiles)


func get_navigation_tiles(origin: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset in navigation_footprint:
		result.append(origin + offset)
	return result


func _apply_object_definition() -> void:
	loaded = false
	if objectId.is_empty() or not Items.objects.has(objectId):
		return
	data = (Items.objects[objectId] as Dictionary).duplicate(true)
	hp = float(data.get("hp", 40.0))
	var sprite: Sprite2D = get_node_or_null("Sprite") as Sprite2D
	if sprite != null:
		sprite.texture = Items.get_object_texture(objectId)
	loaded = true
