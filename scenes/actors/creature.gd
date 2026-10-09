extends CharacterBody2D
class_name Creature

var spawner: Node
var target_player: CharacterBody2D

@export var targetPlayerId: int:
	set(value):
		targetPlayerId = value
		if is_inside_tree():
			_resolve_target_player()

@export var actor_id: StringName:
	set(value):
		actor_id = value
		if not actor_id.is_empty():
			_apply_actor_definition(actor_id)

@export var maxhp := 100.0:
	set(value):
		maxhp = maxf(value, 1.0)
		hp = maxhp

@export var hp := 100.0:
	set(value):
		hp = clampf(value, 0.0, maxhp)
		_update_hp_bar()

var speed := 50.0
var attack: StringName
var attackRange := 50.0
var attackDamage := 1.0
var drops: Dictionary = {}
var _is_dead := false


func _ready() -> void:
	_update_hp_bar()
	if _is_server():
		_resolve_target_player()


func tryAttack() -> void:
	if not _is_server() or _is_dead or not is_instance_valid(target_player):
		return
	var attack_cooldown := get_node_or_null("AttackCooldown") as Timer
	if attack_cooldown == null or not attack_cooldown.is_stopped():
		return

	var projectile_scene := load(_get_attack_scene_path()) as PackedScene
	if projectile_scene == null:
		push_warning("No attack scene found for creature attack '%s'." % attack)
		return
	var world_spawner := WorldEntitySpawner.get_for(self)
	if world_spawner == null or world_spawner.projectiles_root == null:
		push_warning("Creature cannot find the world projectile container.")
		return

	attack_cooldown.start()
	var projectile := projectile_scene.instantiate() as Node2D
	if projectile == null:
		push_warning("Creature attack scene root must inherit Node2D.")
		return
	projectile.set("spawner", self)
	world_spawner.projectiles_root.add_child(projectile, true)
	projectile.global_position = global_position
	var projectile_visuals := projectile.get_node_or_null("MovingParts") as Node2D
	var moving_parts := get_node_or_null("MovingParts") as Node2D
	if projectile_visuals != null and moving_parts != null:
		projectile_visuals.rotation = moving_parts.rotation
	if projectile.has_signal("hitPlayer"):
		projectile.connect("hitPlayer", hitPlayer)
	projectile.set("targetPos", target_player.global_position)


func hitPlayer(body: Node) -> void:
	if _is_server() and body.has_method("getDamage"):
		body.call("getDamage", self, attackDamage, "normal")


func getDamage(causer: Node, amount: float, _damage_type: StringName) -> void:
	if not _is_server() or _is_dead or amount <= 0.0:
		return
	hp -= amount
	var blood_particles := get_node_or_null("bloodParticles") as CPUParticles2D
	if blood_particles != null:
		blood_particles.emitting = true
	if hp > 0.0:
		return
	if is_instance_valid(causer) and causer.is_in_group("player") and causer.has_signal("mob_killed"):
		causer.emit_signal("mob_killed")
	die(true)


func die(drop_loot: bool) -> void:
	if not _is_server() or _is_dead:
		return
	_is_dead = true
	_before_death()
	_release_spawn_slot()
	if drop_loot and _can_drop_loot():
		_drop_loots()
	queue_free()


func face_target() -> void:
	if not is_instance_valid(target_player):
		return
	var moving_parts := get_node_or_null("MovingParts") as Node2D
	if moving_parts != null:
		moving_parts.look_at(target_player.global_position)


func resolve_target_player(allow_nearest := false) -> CharacterBody2D:
	_resolve_target_player(allow_nearest)
	return target_player


func _apply_actor_definition(id: StringName) -> void:
	var definition := Items.actor_definitions.get(String(id)) as ActorDefinition
	if definition == null:
		push_warning("Unknown creature actor_id '%s'." % id)
		return
	var sprite := get_node_or_null("%Sprite2D") as Sprite2D
	if sprite != null:
		sprite.texture = definition.texture
	maxhp = definition.max_hp
	speed = definition.speed
	attack = definition.attack
	attackDamage = definition.attack_damage
	attackRange = definition.attack_range
	drops = definition.drops.duplicate(true)


func _update_hp_bar() -> void:
	var hp_bar := get_node_or_null("%HPBar") as ProgressBar
	if hp_bar != null:
		hp_bar.value = hp / maxhp


func _drop_loots() -> void:
	var world_spawner := WorldEntitySpawner.get_for(self)
	if world_spawner == null:
		return
	for drop_id in drops:
		var amount_data := drops[drop_id] as Dictionary
		var minimum := int(amount_data.get("min", 0))
		var maximum := int(amount_data.get("max", minimum))
		world_spawner.spawn_pickups(drop_id, global_position, randi_range(minimum, maximum))


func _resolve_target_player(allow_nearest := false) -> void:
	var players_root := get_tree().get_first_node_in_group("players_root")
	if players_root == null:
		target_player = null
		return
	target_player = players_root.get_node_or_null(str(targetPlayerId)) as CharacterBody2D
	if is_instance_valid(target_player) or not allow_nearest:
		return

	var nearest_distance := INF
	for candidate in players_root.get_children():
		if not candidate is CharacterBody2D:
			continue
		var candidate_player := candidate as CharacterBody2D
		var candidate_distance := global_position.distance_squared_to(candidate_player.global_position)
		if candidate_distance < nearest_distance:
			nearest_distance = candidate_distance
			target_player = candidate_player
			targetPlayerId = int(str(candidate_player.name))


func _get_attack_scene_path() -> String:
	return "res://scenes/attacks/%s_attack.tscn" % attack


func _before_death() -> void:
	pass


func _release_spawn_slot() -> void:
	pass


func _can_drop_loot() -> bool:
	return true


func _is_server() -> bool:
	return multiplayer != null and multiplayer.is_server()
