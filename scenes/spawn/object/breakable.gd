extends StaticBody2D
class_name NavigationBreakable

@export var objectId := "":
	set(value):
		if value:
			objectId = value
			data = Items.objects[value]
			hp = data["hp"]
			$Sprite.texture = Items.get_object_texture(value)
			loaded = true

var data := {}
var hp = 40
var spawner : Node2D
var loaded = false

func getDamage(causer, amount, type):
	if !loaded:
		return
	if hp <= 0:
		return
	var totalDamage = amount * 2 if type == data["tool"] else amount
	$AnimationPlayer.play("shake")
	$hitParticle.emitting = true
	hp -= totalDamage
	if hp <= 0:
		if causer.is_in_group("player"):
			causer.object_destroyed.emit()
		startBreaking()

func startBreaking():
	$AnimationPlayer.play("break")
	#Also calling breakObject() in Animation

func breakObject():
	if !multiplayer.is_server():
		return
	$NavigationBlocker.release()
	queue_free()
	if is_instance_valid(spawner):
		spawner.spawnedObjects = maxi(0, spawner.spawnedObjects - 1)
	spawnDrops()

func spawnDrops():
	for drop in data["drops"].keys():
		WorldEntitySpawner.get_for(self).spawn_pickups(drop, global_position, randi_range(data["drops"][drop]["min"], data["drops"][drop]["max"]))


func register_navigation_blockers(tiles: Array[Vector2i]) -> void:
	$NavigationBlocker.register_tiles(tiles)


func get_navigation_tiles(origin: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y_offset in range(-1, 2):
		for x_offset in range(-1, 2):
			result.append(origin + Vector2i(x_offset, y_offset))
	return result
