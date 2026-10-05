extends CharacterBody2D

enum AIState { IDLE, CHASE, ATTACK, BLOCKED, DEAD }

var spawner : Node2D
var targetPlayer : CharacterBody2D
@export var targetPlayerId : int:
	set(value):
		targetPlayerId = value
		if is_inside_tree():
			_resolve_target_player()
@export var ai_state := AIState.IDLE

@onready var navigation: EnemyNavigation = $EnemyNavigation

#stats
@export var enemyId := "":
	set(value):
		enemyId = value
		var enemyData = Items.mobs[value]
		%Sprite2D.texture = Items.get_actor_texture(value)
		for stat in enemyData.keys():
			set(stat, enemyData[stat])

var maxhp := 100.0:
	set(value):
		maxhp = value
		hp = value
var hp := maxhp:
	set(value):
		hp = value
		$EnemyUI/HPBar.value = hp/maxhp
var speed := 2000.0
var attack := ""
var attackRange := 50.0
var attackDamage := 20.0
var drops := {}

func _ready() -> void:
	if multiplayer.is_server():
		_resolve_target_player()


func _physics_process(delta):
	if !multiplayer.is_server():
		return
	if not is_instance_valid(targetPlayer):
		_resolve_target_player(true)
	if not is_instance_valid(targetPlayer):
		velocity = Vector2.ZERO
		ai_state = AIState.IDLE
		navigation.clear_target()
		if not GameTime.is_night_time():
			die(false)
		return

	rotateToTarget()
	if global_position.distance_to(targetPlayer.global_position) <= attackRange:
		if ai_state != AIState.ATTACK:
			navigation.stop_at_current_position()
		velocity = Vector2.ZERO
		ai_state = AIState.ATTACK
		tryAttack()
		return

	ai_state = AIState.CHASE
	navigation.set_target(targetPlayer)
	var desired_range_tiles := maxi(1, floori(attackRange / Constants.TILE_SIZE))
	var next_position := navigation.update_navigation(delta, desired_range_tiles)
	if not next_position.is_finite():
		velocity = Vector2.ZERO
		ai_state = AIState.BLOCKED
		return
	move_towards_position(next_position)

func rotateToTarget():
	$MovingParts.look_at(targetPlayer.global_position)

func move_towards_position(next_position: Vector2):
	var direction = (next_position - global_position).normalized()
	velocity = direction * speed
	move_and_slide()

func tryAttack():
	if multiplayer.is_server() and $AttackCooldown.is_stopped():
		$AttackCooldown.start()
		var projectileScene := load("res://scenes/attacks/"+attack+"_attack.tscn")
		var projectile = projectileScene.instantiate()
		spawner.get_node("../Projectiles").add_child(projectile,true)
		projectile.global_position = global_position
		projectile.get_node("MovingParts").rotation = $MovingParts.rotation
		projectile.hitPlayer.connect(hitPlayer)
		projectile.targetPos = targetPlayer.global_position
		
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
	if multiplayer.is_server() and ai_state != AIState.DEAD:
		ai_state = AIState.DEAD
		navigation.shutdown()
		if is_instance_valid(spawner):
			spawner.decreasePlayerEnemyCount(targetPlayerId)
		queue_free()
		if dropLoot:
			dropLoots()

func dropLoots():
	if not GameTime.is_night_time():
		return
	for drop in drops.keys():
		WorldEntitySpawner.get_for(self).spawn_pickups(drop, global_position, randi_range(drops[drop]["min"], drops[drop]["max"]))


func _resolve_target_player(allow_nearest := false) -> void:
	var players_root := get_tree().get_first_node_in_group("players_root")
	if players_root == null:
		targetPlayer = null
		return
	targetPlayer = players_root.get_node_or_null(str(targetPlayerId)) as CharacterBody2D
	if is_instance_valid(targetPlayer) or not allow_nearest:
		return

	var nearest_distance := INF
	for candidate in players_root.get_children():
		if not candidate is CharacterBody2D:
			continue
		var candidate_distance: float = global_position.distance_squared_to(candidate.global_position)
		if candidate_distance < nearest_distance:
			nearest_distance = candidate_distance
			targetPlayer = candidate
			targetPlayerId = int(str(candidate.name))
