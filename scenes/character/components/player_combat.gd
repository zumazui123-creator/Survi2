extends Node

signal mob_killed
signal object_destroyed
signal player_killed

@export_group("References")
@export var player: CharacterBody2D
@export var status: PlayerStatus
@export var player_items: Node
@export var animation_player: AnimationPlayer
@export var hit_area: Area2D

@onready var hands = %Hands if has_node("%Hands") else null

var spawnsProjectile := ""

func _ready():
	if not player: player = get_parent()
	if not status: status = %PlayerStatus
	if not player_items: player_items = $"../PlayerItems"
	if not animation_player: animation_player = $"../AnimationPlayer"
	if not hit_area: hit_area = %HitArea

	mob_killed.connect(mobKilled)
	player_killed.connect(enemyPlayerKilled)
	object_destroyed.connect(objectDestroyed)

func hit(_inp_action : String):
	animation_player.speed_scale = status.attack_rate
	var action_anim = Items.equips[player_items.equippedItem]["attack"] if player_items.equippedItem else Strings.ANIM_PUNCHING
	if not animation_player.is_playing() or animation_player.current_animation != action_anim:
		animation_player.play(action_anim)
		var delay : float = 0.8 / status.attack_rate
		await get_tree().create_timer(delay).timeout
		animation_player.stop()
		

func punchCheckCollision():
	var id = multiplayer.get_unique_id()
	if spawnsProjectile:
		if str(id) == player.name:
			sendProjectile.rpc_id(1, player.player_movement.direction)
	
	if player_items.equippedItem:
		Inventory.useItemDurability(str(player.name), player_items.equippedItem)
		
	for body in hit_area.get_overlapping_bodies():
		if body != player and body.is_in_group(Strings.GROUP_DAMAGEABLE):
			var damage = status.attack_damage
			if player_items.equippedItem:
				damage += Items.equips[player_items.equippedItem]["damage"]
			
			var damage_type = Items.equips[player_items.equippedItem]["damageType"] if player_items.equippedItem else status.damage_type
			body.getDamage(self, damage, damage_type)

@rpc("any_peer", "reliable")
func sendProjectile(towards):
	Items.spawnProjectile(player, spawnsProjectile, towards, Strings.GROUP_DAMAGEABLE)


@rpc("authority", "call_local", "reliable")
func increaseScore(by):
	# Stats werden jetzt über den Status erhöht
	status.hp += by * 5
	status.maxHP += by * 5
	status.attack_damage += by
	
	Multihelper.spawnedPlayers[int(str(player.name))]["score"] += by
	Multihelper.player_score_updated.emit()

func objectDestroyed():
	increaseScore.rpc(Constants.OBJECT_SCORE_GAIN)
	status.gain_exp(10)

func mobKilled():
	increaseScore.rpc(Constants.MOB_SCORE_GAIN)
	status.gain_exp(10)

func enemyPlayerKilled():
	increaseScore.rpc(Constants.PK_SCORE_GAIN)
	status.gain_exp(20)

func getDamage(causer, amount, _type):
	if causer.is_in_group("player"):
		return
		
	status.hp -= amount
	if status.hp <= 0 and causer.is_in_group(Strings.GROUP_PLAYER):
		causer.get_node("PlayerCombat").player_killed.emit()

func die():
	if not multiplayer.is_server():
		return
	var peerId := int(str(player.name))
	Multihelper._deregister_character.rpc(peerId)
	player_items.dropInventory()
	Multihelper.showSpawnUI.rpc_id(peerId)
	player.queue_free()

@rpc("any_peer", "reliable")
func projectileHit(body):
	var damage = status.attack_damage
	if player_items.equippedItem:
		damage += Items.equips[player_items.equippedItem]["damage"]
	body.getDamage(player, damage, status.damage_type)
