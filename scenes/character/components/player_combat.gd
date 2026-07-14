extends Node

signal mob_killed
signal object_destroyed
signal player_killed

@export_group("References")
@export var player: CharacterBody2D
@export var hit_area: Area2D

@onready var hands = %Hands if has_node("%Hands") else null

var spawnsProjectile := ""

# Combo settings
var combo_count := 0
var last_hit_time := 0.0
const COMBO_WINDOW_MS := 2000.0 # Time in ms to maintain combo
const COMBO_MULTIPLIER := 0.1  # 10% damage increase per combo level

func _ready():
	mob_killed.connect(mobKilled)
	player_killed.connect(enemyPlayerKilled)
	object_destroyed.connect(objectDestroyed)

func hit(_inp_action : String):
	player.animation.speed_scale = player.status.attack_rate
	var action_anim = Items.equips[player.items.equippedItem]["attack"] if player.items.equippedItem else Strings.ANIM_PUNCHING
	if not player.animation.is_playing() or player.animation.current_animation != action_anim:
		player.animation.play(action_anim)
		var delay : float = 0.8 / player.status.attack_rate
		await get_tree().create_timer(delay).timeout
		player.animation.stop()


func punchCheckCollision():
	var id = multiplayer.get_unique_id()
	if spawnsProjectile:
		if str(id) == player.name:
			sendProjectile.rpc_id(1, player.movement.direction if player.movement else Vector2.ZERO)

	if player.items.equippedItem:
		Inventory.useItemDurability(str(player.name), player.items.equippedItem)

	# Update combo
	var current_time = Time.get_ticks_msec()
	if current_time - last_hit_time > COMBO_WINDOW_MS:
		combo_count = 0
	combo_count += 1
	last_hit_time = current_time

	for body in hit_area.get_overlapping_bodies():
		if body != player and body.is_in_group(Strings.GROUP_DAMAGEABLE):
			var base_damage = player.status.attack_damage
			if player.items.equippedItem:
				base_damage += Items.equips[player.items.equippedItem]["damage"]
			
			# Apply combo multiplier
			var damage = base_damage * (1.0 + (combo_count - 1) * COMBO_MULTIPLIER)

			var damage_type = Items.equips[player.items.equippedItem]["damageType"] if player.items.equippedItem else player.status.damage_type
			body.getDamage(self, damage, damage_type)

@rpc("any_peer", "reliable")
func sendProjectile(towards):
	Items.spawnProjectile(player, spawnsProjectile, towards, Strings.GROUP_DAMAGEABLE)


@rpc("authority", "call_local", "reliable")
func increaseScore(by):
	# Stats werden jetzt über den Status erhöht
	player.status.hp += by * 5
	player.status.maxHP += by * 5
	player.status.attack_damage += by
	player.status.gain_exp(10*by)
	Multihelper.spawnedPlayers[int(str(player.name))]["score"] += by
	Multihelper.player_score_updated.emit()


func objectDestroyed():
	increaseScore.rpc(Constants.OBJECT_SCORE_GAIN)

func mobKilled():
	increaseScore.rpc(Constants.MOB_SCORE_GAIN)

func enemyPlayerKilled():
	increaseScore.rpc(Constants.PK_SCORE_GAIN)

func getDamage(causer, amount, _type):
	if causer.is_in_group("player"):
		return

	player.status.hp -= amount
	if player.status.hp <= 0 and causer.is_in_group(Strings.GROUP_PLAYER):
		causer.get_node("PlayerCombat").player_killed.emit()

func die():
	if not multiplayer.is_server():
		return
	var peerId := int(str(player.name))
	Multihelper._deregister_character.rpc(peerId)
	player.p_items.dropInventory()
	Multihelper.showSpawnUI.rpc_id(peerId)
	player.queue_free()

@rpc("any_peer", "reliable")
func projectileHit(body):
	var damage = player.status.attack_damage
	if player.items.equippedItem:
		damage += Items.equips[player.items.equippedItem]["damage"]
	body.getDamage(player, damage, player.status.damage_type)
