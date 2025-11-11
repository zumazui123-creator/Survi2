extends Node

var player: CharacterBody2D
@onready var animation_player = $"../AnimationPlayer"
@onready var moving_parts = $"../MovingParts"

func _ready():
	player = get_parent()

func set_character_sprite(file_path):
	print("set_character_sprite: "+str(file_path))
	var sprite = moving_parts.get_node("Sprite2D")
	if sprite:
		sprite.texture = load(Constants.PATH_CHARACTER_BODIES+file_path)

func animate_player(dir: Vector2):
	if dir != Vector2.ZERO:
		moving_parts.rotation = dir.angle()
		if not animation_player.is_playing() or animation_player.current_animation != Strings.ANIM_WALKING:
			animation_player.play(Strings.ANIM_WALKING)
	else:
		animation_player.stop()

func handleAnims(vel, doing_action):
	var player_combat = player.get_node("PlayerCombat")
	if not player_combat:
		return
		
	if doing_action:
		var action_anim = Items.equips[player_combat.equippedItem]["attack"] if player_combat.equippedItem else Strings.ANIM_PUNCHING
		if not animation_player.is_playing() or animation_player.current_animation != action_anim:
			animation_player.play(action_anim)
	elif vel != Vector2.ZERO:
		if not animation_player.is_playing() or animation_player.current_animation != Strings.ANIM_WALKING:
			animation_player.play(Strings.ANIM_WALKING)
	else:
		animation_player.stop()
