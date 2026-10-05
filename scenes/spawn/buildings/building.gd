extends StaticBody2D
class_name NavigationBuilding

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
var navigation_tiles: Array[Vector2i] = []
@export var navigation_footprint: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i.ZERO, Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]

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

func breakObject():
	if !multiplayer.is_server():
		return
	$NavigationBlocker.release()
	if is_instance_valid(spawner):
		spawner.remove_building(self, navigation_tiles)
	queue_free()
	spawnDrops()

func spawnDrops():
	for drop in data["drops"].keys():
		WorldEntitySpawner.get_for(self).spawn_pickups(drop, global_position, randi_range(data["drops"][drop]["min"], data["drops"][drop]["max"]))


func register_navigation_blockers(tiles: Array[Vector2i]) -> void:
	navigation_tiles = tiles.duplicate()
	$NavigationBlocker.register_tiles(navigation_tiles)


func get_navigation_tiles(origin: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset in navigation_footprint:
		result.append(origin + offset)
	return result
