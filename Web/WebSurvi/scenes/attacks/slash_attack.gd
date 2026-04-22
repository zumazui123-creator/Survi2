extends Node2D

signal hitPlayer(body)
var targetPos : Vector2

func _on_animated_sprite_2d_animation_finished():
	queue_free()

func _on_animated_sprite_2d_frame_changed():
	if %Sprite.frame == 1:
		for body in %AttackArea.get_overlapping_bodies():
			if body.is_in_group("player"):
				hitPlayer.emit(body)
