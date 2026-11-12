extends Node2D
class_name GhostPuzzleGuardVisual

var _sprite: Sprite2D
var _definition: ActorDefinition
var _frame_index: int = 0
var _frame_elapsed: float = 0.0


func _ready() -> void:
	add_to_group(&"sensor_enemy")


func configure(actor_id: StringName) -> void:
	_definition = Items.actor_definitions.get(String(actor_id)) as ActorDefinition
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "GhostSprite"
		add_child(_sprite)
	if _definition == null or _definition.texture == null:
		queue_redraw()
		return
	_sprite.texture = _definition.texture
	_sprite.scale = _definition.visual_scale
	_sprite.modulate = _definition.visual_modulate
	_sprite.region_enabled = _definition.frame_count > 1 \
		and _definition.frame_size.x > 0 \
		and _definition.frame_size.y > 0
	_frame_index = 0
	_frame_elapsed = 0.0
	_apply_frame()


func set_tile_offset(tile_offset: Vector2i) -> void:
	position = Vector2(tile_offset) * float(Constants.TILE_SIZE)


func set_guard_active(active: bool) -> void:
	visible = active
	if active:
		add_to_group(&"sensor_enemy")
	else:
		remove_from_group(&"sensor_enemy")


func _process(delta: float) -> void:
	if _definition == null or _definition.frame_count <= 1 \
			or _definition.animation_fps <= 0.0:
		return
	_frame_elapsed += delta
	var seconds_per_frame: float = 1.0 / _definition.animation_fps
	while _frame_elapsed >= seconds_per_frame:
		_frame_elapsed -= seconds_per_frame
		_frame_index = (_frame_index + 1) % _definition.frame_count
		_apply_frame()


func _apply_frame() -> void:
	if _sprite == null or _definition == null or not _sprite.region_enabled:
		return
	_sprite.region_rect = Rect2(
		Vector2(
			float(_frame_index * _definition.frame_size.x),
			float(_definition.frame_row * _definition.frame_size.y)
		),
		Vector2(_definition.frame_size)
	)


func _draw() -> void:
	if _definition != null and _definition.texture != null:
		return
	var color: Color = Color(0.62, 0.58, 1.0, 0.92)
	draw_circle(Vector2(0.0, -8.0), 18.0, color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-18.0, -5.0),
		Vector2(18.0, -5.0),
		Vector2(12.0, 24.0),
		Vector2(0.0, 14.0),
		Vector2(-12.0, 24.0),
	]), color)
	draw_circle(Vector2(-6.0, -10.0), 3.0, Color.WHITE)
	draw_circle(Vector2(6.0, -10.0), 3.0, Color.WHITE)
