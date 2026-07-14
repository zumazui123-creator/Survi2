extends AnimationPlayer

@export_group("References")
@export var player: CharacterBody2D


@onready var moving_parts = $"../MovingParts"

func _ready():
	if not player: player = get_parent()
	
func _play(anim):
	play(Strings.ANIM_WALKING)
	play(anim)
	
func set_character_sprite(file_path):
	print("set_character_sprite: "+str(file_path))
	var sprite = moving_parts.get_node("Sprite2D")
	if sprite:
		sprite.texture = load(Constants.PATH_CHARACTER_BODIES+file_path)

func animate_player(dir: Vector2):
	if dir != Vector2.ZERO:
		moving_parts.rotation = dir.angle()
		if not is_playing() or current_animation != Strings.ANIM_WALKING:
			play(Strings.ANIM_WALKING)
	else:
		stop()

func handleAnims(vel, doing_action):
	if not player.p_combat:
		return
		
	if doing_action:
		var action_anim = Items.equips[player.p_combat.equippedItem]["attack"] if player.p_combat.equippedItem else Strings.ANIM_PUNCHING
		if not is_playing() or current_animation != action_anim:
			play(action_anim)
	elif vel != Vector2.ZERO:
		if not is_playing() or current_animation != Strings.ANIM_WALKING:
			play(Strings.ANIM_WALKING)
	else:
		stop()
		
func _play_level_up_animation(level : int ):
	if not is_inside_tree():
		return
	var label = Label.new()
	label.text = "LEVEL UP! (" + str(level) + ")"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Basic styling
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color.YELLOW)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	
	# Position it above the player
	label.z_index = 100
	add_child(label)
	label.position = Vector2(-50, -80)
	
	# Initial scale
	label.scale = Vector2(0.5, 0.5)
	label.pivot_offset = Vector2(50, 10)
	
	var tween = create_tween()
	tween.set_parallel(true)

	# Float up
	tween.tween_property(
		label,
		"position:y",
		label.position.y - 60,
		2.0
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Fade out
	tween.tween_property(
		label,
		"modulate:a",
		0.0,
		2.0
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# Scale up
	tween.tween_property(
		label,
		"scale",
		Vector2(1.2, 1.2),
		0.5
	).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	tween.chain().tween_callback(label.queue_free)
