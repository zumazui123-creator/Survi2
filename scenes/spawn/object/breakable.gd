extends StaticBody2D
class_name NavigationBreakable

@export var objectId: String = "":
	set(value):
		objectId = value
		loaded = false
		definition = Items.get_object_definition(value)
		if definition == null:
			return
		hp = definition.max_hp
		$Sprite.texture = definition.texture
		_apply_collision_size(definition.get_collision_size())
		loaded = true

var definition: WorldObjectDefinition
var hp: float = 40.0
var spawner: Node
var loaded: bool = false
var navigation_tiles: Array[Vector2i] = []

func getDamage(causer: Node, amount: float, damage_type: StringName) -> void:
	if !loaded:
		return
	if hp <= 0:
		return
	var required_tool: StringName = definition.required_tool
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
	if !multiplayer.is_server():
		return
	$NavigationBlocker.release()
	if is_instance_valid(spawner) and spawner.has_method("notify_breakable_removed"):
		spawner.call("notify_breakable_removed")
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
	$NavigationBlocker.register_tiles(navigation_tiles)


func get_navigation_tiles(origin: Vector2i) -> Array[Vector2i]:
	if definition == null:
		return [origin]
	return definition.get_occupied_tiles(origin)


func _apply_collision_size(size: Vector2) -> void:
	var collision_shape: CollisionShape2D = $CollisionShape2D
	var CircleShape: RectangleShape2D = collision_shape.shape as RectangleShape2D
	if CircleShape != null:
		CircleShape.size.x = Constants.TILE_SIZE*3 #min(size.x,size.y)
		CircleShape.size.y = Constants.TILE_SIZE*3  
		definition.collision_size = Vector2(CircleShape.size.x ,CircleShape.size.y) 
