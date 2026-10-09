extends Node2D

signal hitPlayer(body)
var spawner: Node2D
var targetPos: Vector2


func _on_animated_sprite_2d_animation_finished() -> void:
	if multiplayer.is_server():
		queue_free()


func _on_animated_sprite_2d_frame_changed() -> void:
	if multiplayer.is_server():
		if %Sprite.frame == 1:
			for body: Node2D in %AttackArea.get_overlapping_bodies():
				if body == spawner:
					continue
				if body.is_in_group("player") or body is BuildingEntity:
					hitPlayer.emit(body)
