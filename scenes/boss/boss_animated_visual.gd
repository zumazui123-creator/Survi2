extends AnimatedSprite2D
class_name BossAnimatedVisual

const DIRECTION_NAMES: Array[StringName] = [&"down", &"left", &"up", &"right"]

@export var movement_textures: Array[Texture2D] = []
@export var movement_frame_size: Vector2i = Vector2i(64, 64)
@export_range(1, 16, 1) var movement_frame_count: int = 1
@export_range(1.0, 20.0, 0.5) var movement_fps: float = 7.0
@export var animate_while_idle: bool = false

@export var attack_textures: Array[Texture2D] = []
@export var attack_frame_size: Vector2i = Vector2i(64, 64)
@export_range(1, 16, 1) var attack_frame_count: int = 1
@export_range(1.0, 20.0, 0.5) var attack_fps: float = 10.0

var _direction_index: int = 0
var _attacking: bool = false
var _last_world_position: Vector2
var _base_scale: Vector2
var _base_offset: Vector2
var _event_tween: Tween


func _ready() -> void:
	_base_scale = scale
	_base_offset = offset
	_last_world_position = global_position
	sprite_frames = SpriteFrames.new()
	_build_directional_animations(&"move", movement_textures, movement_frame_size, movement_frame_count, movement_fps, true)
	_build_directional_animations(&"attack", attack_textures, attack_frame_size, attack_frame_count, attack_fps, false)
	animation_finished.connect(_on_animation_finished)
	_update_animation(false)


func _process(_delta: float) -> void:
	var facing_parent: Node2D = get_parent() as Node2D
	if facing_parent != null:
		var facing_direction: Vector2 = Vector2.RIGHT.rotated(facing_parent.rotation)
		_direction_index = _direction_from_vector(facing_direction)
		rotation = -facing_parent.rotation
	var moved: bool = global_position.distance_squared_to(_last_world_position) > 0.25
	_last_world_position = global_position
	flip_h = _direction_index == 3 and movement_textures.size() > 1
	if not _attacking:
		_update_animation(moved)


func play_visual_event(event_name: StringName) -> void:
	match event_name:
		&"attack":
			_play_attack()
		&"awaken":
			_play_pulse(1.24, 0.36)
		&"phase":
			_play_pulse(1.18, 0.42)
		&"hurt":
			_play_pulse(1.08, 0.2)


func _play_attack() -> void:
	if not attack_textures.is_empty() and sprite_frames.has_animation(_animation_name(&"attack")):
		_attacking = true
		offset = _base_offset + Vector2(
			0.0,
			float(movement_frame_size.y - attack_frame_size.y) * 0.5
		)
		flip_h = _direction_index == 3 and attack_textures.size() > 1
		play(_animation_name(&"attack"))
		return
	_play_pulse(1.14, 0.28)


func _play_pulse(scale_multiplier: float, duration: float) -> void:
	if _event_tween != null and _event_tween.is_valid():
		_event_tween.kill()
	scale = _base_scale
	_event_tween = create_tween()
	_event_tween.set_trans(Tween.TRANS_BACK)
	_event_tween.set_ease(Tween.EASE_OUT)
	_event_tween.tween_property(self, "scale", _base_scale * scale_multiplier, duration * 0.45)
	_event_tween.set_ease(Tween.EASE_IN_OUT)
	_event_tween.tween_property(self, "scale", _base_scale, duration * 0.55)


func _update_animation(moved: bool) -> void:
	var animation_name: StringName = _animation_name(&"move")
	if animation != animation_name:
		play(animation_name)
	if moved or animate_while_idle:
		if not is_playing():
			play(animation_name)
	else:
		pause()
		frame = 0


func _on_animation_finished() -> void:
	if not _attacking:
		return
	_attacking = false
	offset = _base_offset
	_update_animation(false)


func _build_directional_animations(
		prefix: StringName,
		textures: Array[Texture2D],
		frame_size: Vector2i,
		frame_count: int,
		frames_per_second: float,
		loop_animation: bool
	) -> void:
	if textures.is_empty():
		return
	for direction_index: int in range(DIRECTION_NAMES.size()):
		var animation_name: StringName = StringName("%s_%s" % [prefix, DIRECTION_NAMES[direction_index]])
		sprite_frames.add_animation(animation_name)
		sprite_frames.set_animation_speed(animation_name, frames_per_second)
		sprite_frames.set_animation_loop(animation_name, loop_animation)
		var source_texture: Texture2D = textures[0] if textures.size() == 1 else textures[direction_index]
		var source_row: int = direction_index if textures.size() == 1 else 0
		for frame_index: int in range(frame_count):
			var frame_texture: AtlasTexture = AtlasTexture.new()
			frame_texture.atlas = source_texture
			frame_texture.region = Rect2(
				Vector2(frame_index * frame_size.x, source_row * frame_size.y),
				Vector2(frame_size)
			)
			sprite_frames.add_frame(animation_name, frame_texture)


func _animation_name(prefix: StringName) -> StringName:
	return StringName("%s_%s" % [prefix, DIRECTION_NAMES[_direction_index]])


func _direction_from_vector(direction: Vector2) -> int:
	if absf(direction.x) >= absf(direction.y):
		return 3 if direction.x >= 0.0 else 1
	return 0 if direction.y >= 0.0 else 2
