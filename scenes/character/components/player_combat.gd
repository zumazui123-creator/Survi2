extends Node

signal mob_killed
signal object_destroyed
signal player_killed

@export_group("References")
@export var player: Player
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
	player.p_animation.speed_scale = player.p_status.attack_rate
	var action_anim = Items.equips[player.p_items.equippedItem]["attack"] if player.p_items.equippedItem else Strings.ANIM_PUNCHING
	if not player.p_animation.is_playing() or player.p_animation.current_animation != action_anim:
		player.p_animation.play(action_anim)
		var delay : float = 0.8 / player.p_status.attack_rate
		await get_tree().create_timer(delay).timeout
		player.p_animation.stop()


func punchCheckCollision():
	var id = multiplayer.get_unique_id()
	if spawnsProjectile:
		if str(id) == player.name:
			sendProjectile.rpc_id(1, player.p_movement.direction if player.p_movement else Vector2.ZERO)

	if player.p_items.equippedItem:
		Inventory.useItemDurability(str(player.name), player.p_items.equippedItem)

	# Update combo
	var current_time = Time.get_ticks_msec()
	if current_time - last_hit_time > COMBO_WINDOW_MS:
		combo_count = 0
	combo_count += 1
	last_hit_time = current_time

	for body in hit_area.get_overlapping_bodies():
		if body != player and body.is_in_group(Strings.GROUP_DAMAGEABLE):
			var base_damage = player.p_status.attack_damage
			if player.p_items.equippedItem:
				base_damage += Items.equips[player.p_items.equippedItem]["damage"]
			
			# Apply combo multiplier
			var damage = base_damage * (1.0 + (combo_count - 1) * COMBO_MULTIPLIER)

			var damage_type = Items.equips[player.p_items.equippedItem]["damageType"] if player.p_items.equippedItem else player.p_status.damage_type
			body.getDamage(self, damage, damage_type)

@rpc("any_peer", "reliable")
func sendProjectile(towards):
	Items.spawnProjectile(player, spawnsProjectile, towards, Strings.GROUP_DAMAGEABLE)


@rpc("authority", "call_local", "reliable")
func increaseScore(by):
	# Stats werden jetzt über den Status erhöht
	player.p_status.hp += by * 5
	player.p_status.maxHP += by * 5
	player.p_status.attack_damage += by
	player.p_status.gain_exp(10*by)
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

	player.p_status.hp -= amount
	if player.p_status.hp <= 0 and causer.is_in_group(Strings.GROUP_PLAYER):
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
	var damage = player.p_status.attack_damage
	if player.p_items.equippedItem:
		damage += Items.equips[player.p_items.equippedItem]["damage"]
	body.getDamage(player, damage, player.p_status.damage_type)
