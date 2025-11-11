extends CharacterBody2D

var direction = [Vector2i(0,1),Vector2i(1,0),Vector2i(0,-1),Vector2i(-1,0)]

var spawner : Node2D
var targetPlayer : CharacterBody2D
@export var targetPlayerId : int:
	set(value):
		targetPlayerId = value
		targetPlayer = get_node("../../Players/"+str(value))

#stats
@export var animalId := "":
	set(value):
		animalId = value
		var animalData = Items.animals[value]
		%Sprite2D.texture = load("res://assets/characters/animal/"+value+".png")
		for stat in animalData.keys():
			set(stat, animalData[stat])

var maxhp := 100.0:
	set(value):
		maxhp = value
		hp = value
var hp := maxhp:
	set(value):
		hp = value
		$AnimalUI/HPBar.value = hp/maxhp

var speed := 2000.0
var attack := ""
var attackRange := 5.0
var attackDamage := 2.0
var drops := {}

func _process(_delta):
	if !multiplayer.is_server():
		return
		
	#randomWalk()
	if targetPlayer == null:
		return
	if position.distance_to(targetPlayer.position) < attackRange:
		$MovingParts.look_at(targetPlayer.position)
		tryAttack()

func randomWalk():
	velocity = direction.pick_random() * speed
	$MovingParts.look_at(velocity)
	move_and_slide()


#func move_towards(target_position : Vector2 ):
	##var direction = (target_position - position).normalized()
	#velocity = direction * speed
	#move_and_slide()

func tryAttack():
	if multiplayer.is_server() and $AttackCooldown.is_stopped():
		$AttackCooldown.start()
		var projectileScene := load("res://scenes/attacks/"+attack+".tscn")
		var projectile = projectileScene.instantiate()
		spawner.get_node("../Projectiles").add_child(projectile,true)
		projectile.position = position
		projectile.get_node("MovingParts").rotation = $MovingParts.rotation
		projectile.hitPlayer.connect(hitPlayer)
		projectile.targetPos = targetPlayer.position
		
func hitPlayer(body):
	if multiplayer.is_server():
		body.getDamage(self, attackDamage, "normal")
	
func getDamage(causer, amount, _type):
	hp -= amount
	$bloodParticles.emitting = true
	if hp <= 0:
		if causer.is_in_group("player"):
			causer.mob_killed.emit()
		die(true)

func die(dropLoot):
	if multiplayer.is_server():
		spawner.decreasePlayerAnimalCount(targetPlayerId)
		queue_free()
		if dropLoot:
			dropLoots()

func dropLoots():
	for drop in drops.keys(): # TODO png food
		Items.spawnPickups(drop, position, randi_range(drops[drop]["min"],drops[drop]["max"]))
