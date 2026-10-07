extends StaticBody2D
class_name TreeEntity

signal health_changed(tile: Vector2i, current_hp: float)
signal tree_destroyed(tile: Vector2i)

@export var objectId: String = "":
	set(value):
		if value:
			objectId = value
			data = Items.objects[value]
			hp = data["hp"]
			$Sprite.texture = Items.get_object_texture(value)
			loaded = true

var data: Dictionary = {}
var hp: float = 40.0
var loaded: bool = false
var tree_tile: Vector2i = Vector2i.ZERO


func configure_managed_tree(tile: Vector2i, tree_object_id: String, current_hp: float) -> void:
	tree_tile = tile
	objectId = tree_object_id
	hp = current_hp
	$AnimationPlayer.stop()
	$Sprite.scale = Vector2.ONE

func getDamage(causer, amount, type):
	if !loaded:
		return
	if hp <= 0:
		return
	var totalDamage = amount * 2 if type == data["tool"] else amount
	$AnimationPlayer.play("shake")
	$hitParticle.emitting = true
	hp -= totalDamage
	health_changed.emit(tree_tile, float(hp))
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
	tree_destroyed.emit(tree_tile)
	$NavigationBlocker.release()
	queue_free()
	spawnDrops()

func spawnDrops():
	for drop in data["drops"].keys():
		WorldEntitySpawner.get_for(self).spawn_pickups(drop, global_position, randi_range(data["drops"][drop]["min"], data["drops"][drop]["max"]))


func register_navigation_blocker(tile: Vector2i) -> void:
	var tiles: Array[Vector2i] = [tile]
	$NavigationBlocker.register_tiles(tiles)
