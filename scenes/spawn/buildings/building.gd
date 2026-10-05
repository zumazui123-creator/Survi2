extends StaticBody2D

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

func breakObject():
	if !multiplayer.is_server():
		return
	queue_free()
	spawner.spawnedObjects -= 1
	spawnDrops()

func spawnDrops():
	for drop in data["drops"].keys():
		WorldEntitySpawner.get_for(self).spawn_pickups(drop, position, randi_range(data["drops"][drop]["min"], data["drops"][drop]["max"]))
