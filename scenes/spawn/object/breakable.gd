extends StaticBody2D
class_name NavigationBreakable

@export var objectId: String = "":
	set(value):
		objectId = value
		loaded = false
		if value.is_empty() or not Items.objects.has(value):
			return
		data = (Items.objects[value] as Dictionary).duplicate(true)
		hp = float(data.get("hp", 40.0))
		$Sprite.texture = Items.get_object_texture(value)
		loaded = true

var data: Dictionary = {}
var hp: float = 40.0
var spawner: Node
var loaded: bool = false

func getDamage(causer: Node, amount: float, damage_type: StringName) -> void:
	if !loaded:
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
	#Also calling breakObject() in Animation

func breakObject() -> void:
	if !multiplayer.is_server():
		return
	$NavigationBlocker.release()
	if is_instance_valid(spawner) and spawner.has_method("notify_breakable_removed"):
		spawner.call("notify_breakable_removed")
	spawnDrops()
	queue_free()

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
	$NavigationBlocker.register_tiles(tiles)


func get_navigation_tiles(origin: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = [origin]
	return result
