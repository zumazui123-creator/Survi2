extends Node
class_name PlayerCombat

signal mob_killed
signal object_destroyed
signal player_killed

@export_group("References")
@export var player: CharacterBody2D
@export var hit_area: Area2D
@export var stats: PlayerStats
@export var blood_particles: CPUParticles2D
@export var action_audio: AudioStreamPlayer2D
@export var drink_audio: AudioStreamPlayer2D
@export var allow_player_damage: bool = true

@export_group("Water Interaction")
@export_range(1.0, 100.0, 1.0) var hydration_per_drink: float = 25.0

@onready var hands: Sprite2D = %Hands if has_node("%Hands") else null
@onready var hand_contact: Node2D = hit_area.get_node_or_null("HitCollision") as Node2D \
		if is_instance_valid(hit_area) else null

var spawnsProjectile: String = ""
var _is_drinking: bool = false

# Combo settings
var combo_count: int = 0
var last_hit_time: float = 0.0
const COMBO_WINDOW_MS: float = 2000.0 # Time in ms to maintain combo
const COMBO_MULTIPLIER: float = 0.1  # 10% damage increase per combo level

func _ready():
	mob_killed.connect(mobKilled)
	player_killed.connect(enemyPlayerKilled)
	object_destroyed.connect(objectDestroyed)
	if not stats.died.is_connected(_on_player_died):
		stats.died.connect(_on_player_died)

func hit(_inp_action : String):
	player.animation.speed_scale = stats.attack_rate
	var action_anim: String = _get_action_animation()
	if not player.animation.is_playing() or player.animation.current_animation != action_anim:
		player.animation.play(action_anim)
		var delay : float = 0.8 / stats.attack_rate
		await get_tree().create_timer(delay).timeout
		player.animation.stop()


## Uses the active attack animation without applying attack collision, durability,
## projectile, or combo effects. The hand contact point must be over a water tile.
func drink() -> bool:
	if not can_drink_from_water() or not is_instance_valid(stats):
		return false

	var action_anim: String = _get_action_animation()
	var previous_action_audio_volume: float = 0.0
	var should_restore_action_audio: bool = is_instance_valid(action_audio)
	if should_restore_action_audio:
		previous_action_audio_volume = action_audio.volume_db
		action_audio.volume_db = -80.0

	_is_drinking = true
	player.animation.speed_scale = stats.attack_rate
	player.animation.play(action_anim)
	if is_instance_valid(drink_audio):
		drink_audio.play()

	var delay: float = 0.8 / maxf(stats.attack_rate, 0.01)
	await get_tree().create_timer(delay).timeout
	if player.animation.current_animation == action_anim:
		player.animation.stop()
	_is_drinking = false
	if should_restore_action_audio:
		action_audio.volume_db = previous_action_audio_volume
	stats.hydration += hydration_per_drink
	return true


func can_drink_from_water() -> bool:
	if not is_instance_valid(player) or not is_instance_valid(player.sensor):
		return false
	if is_instance_valid(hand_contact) \
			and player.sensor.is_water_at_world_position(hand_contact.global_position):
		return true
	if is_instance_valid(hands) \
			and player.sensor.is_water_at_world_position(hands.global_position):
		return true
	return false


func _get_action_animation() -> String:
	if player.items and not player.items.equippedItem.is_empty():
		var equipped_item: Dictionary = Items.equips.get(player.items.equippedItem, {})
		if equipped_item.has("attack"):
			return String(equipped_item["attack"])
	return Strings.ANIM_PUNCHING


func get_combo_damage(damage_multiplier: float) -> float:
	var damage: float = stats.attack_damage
	if player.items and not player.items.equippedItem.is_empty():
		var equipped_item: Dictionary = Items.equips.get(player.items.equippedItem, {})
		damage += float(equipped_item.get("damage", 0.0))
	return maxf(damage * damage_multiplier, 0.0)


func punchCheckCollision():
	if _is_drinking:
		return
	var id = multiplayer.get_unique_id()
	if spawnsProjectile:
		if str(id) == player.name:
			sendProjectile.rpc_id(
				1,
				player.movement.facing_direction if player.movement else Vector2.ZERO
			)

	if player.items.equippedItem:
		Inventory.useItemDurability(str(player.name), player.items.equippedItem)

	# Update combo
	var current_time: int = Time.get_ticks_msec()
	if current_time - last_hit_time > COMBO_WINDOW_MS:
		combo_count = 0
	combo_count += 1
	last_hit_time = current_time

	for body in hit_area.get_overlapping_bodies():
		if body != player and body.is_in_group(Strings.GROUP_DAMAGEABLE):
			var base_damage: float = stats.attack_damage
			if player.items.equippedItem:
				base_damage += Items.equips[player.items.equippedItem]["damage"]
			
			# Apply combo multiplier
			var damage: float = base_damage * (1.0 + (combo_count - 1) * COMBO_MULTIPLIER)

			var damage_type: StringName = Items.equips[player.items.equippedItem]["damageType"] if player.items.equippedItem else stats.damage_type
			body.getDamage(self, damage, damage_type)

@rpc("any_peer", "reliable")
func sendProjectile(towards):
	WorldEntitySpawner.get_for(self).spawn_projectile(player, spawnsProjectile, towards, Strings.GROUP_DAMAGEABLE)


@rpc("authority", "call_local", "reliable")
func increaseScore(by):
	# Stats werden jetzt über den Status erhöht
	stats.max_hp += by * 5
	stats.hp += by * 5
	stats.attack_damage += by
	stats.gain_exp(10*by)
	Multihelper.spawnedPlayers[int(str(player.name))]["score"] += by
	Multihelper.player_score_updated.emit()


func objectDestroyed():
	increaseScore.rpc(Constants.OBJECT_SCORE_GAIN)

func mobKilled():
	increaseScore.rpc(Constants.MOB_SCORE_GAIN)

func enemyPlayerKilled():
	increaseScore.rpc(Constants.PK_SCORE_GAIN)

func getDamage(causer: Node, amount: float, _damage_type: StringName) -> void:
	if amount <= 0.0 or stats.hp <= 0.0:
		return

	var attacker_combat: PlayerCombat = _resolve_attacking_combat(causer)
	if attacker_combat != null:
		if attacker_combat.player == player:
			return
		if not allow_player_damage:
			return

	var was_alive: bool = stats.hp > 0.0
	stats.apply_damage(amount)
	if was_alive and stats.hp <= 0.0 and attacker_combat != null:
		attacker_combat.player_killed.emit()


func _resolve_attacking_combat(causer: Node) -> PlayerCombat:
	if causer is PlayerCombat:
		return causer as PlayerCombat
	if causer is CharacterBody2D and causer.is_in_group(Strings.GROUP_PLAYER):
		return causer.get("combat") as PlayerCombat
	return null

func die():
	if not multiplayer.is_server():
		return
	var peerId: int = int(str(player.name))
	Multihelper._deregister_character.rpc(peerId)
	player.items.dropInventory()
	Multihelper.showSpawnUI.rpc_id(peerId)
	player.queue_free()


func _on_player_died() -> void:
	if is_instance_valid(blood_particles):
		blood_particles.restart()
		blood_particles.emitting = true
	die()

@rpc("any_peer", "reliable")
func projectileHit(body):
	var damage: float = stats.attack_damage
	if player.items.equippedItem:
		damage += Items.equips[player.items.equippedItem]["damage"]
	body.getDamage(player, damage, stats.damage_type)
