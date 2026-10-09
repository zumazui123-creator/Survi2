extends Node2D

signal hitPlayer(body)

var spawner
var projectileData := {}
var projectileId := "":
	set(value):
		projectileId = value
		projectileData = Items.projectiles[value]
		for stat in projectileData.keys():
			if stat == "horizontalFrames":
				continue
			set(stat, projectileData[stat])
		%Sprite2D.texture = Items.get_projectile_texture(value)
		var horizontal_frames: int = int(projectileData.get("horizontalFrames", 4))
		%Sprite2D.hframes = maxi(horizontal_frames, 1)
		%Sprite2D.frame = 0
		$AnimationPlayer.active = horizontal_frames > 1
		
# maxHits, speed, time, curveSpeed
var targetGroup := "damageable"
var maxHits := 1
@export var speed: float = 10.0
@export var time: float = 1.0
var curveSpeed := true
var elapsed_time: float = 0.0
var hitBodies := []
var targetPos : Vector2:
	set(value):
		targetPos = value
		direction = (targetPos - position).normalized()
var direction: Vector2

func _process(delta: float):
	if multiplayer.is_server():
		if curveSpeed:
			position += direction * speed * elapsed_time
		else:
			position += direction * speed
		elapsed_time += delta
		if elapsed_time >= time:
			disappear()

func _on_animated_sprite_2d_animation_finished():
	if multiplayer.is_server():
		queue_free()

func _on_attack_area_body_entered(body):
	if !multiplayer.is_server():
		return
	if body.is_in_group(targetGroup) and body not in hitBodies:
		if spawner and body == spawner:
			return
		hitBodies.append(body)
		hitPlayer.emit(body)
		maxHits -= 1
	if maxHits <= 0:
		disappear()
		
func disappear():
	if !multiplayer.is_server():
		return
	queue_free()
