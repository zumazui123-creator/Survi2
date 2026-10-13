extends Node
class_name ActorVisualController

@export var sprite: Sprite2D

static var _placeholder_textures: Dictionary[String, ImageTexture] = {}

var _configured_actor_id: StringName = &""
var _definition: ActorDefinition
var _frame_index: int = 0
var _frame_elapsed: float = 0.0


func _ready() -> void:
	_configure_for_parent()


func _process(delta: float) -> void:
	var creature: Creature = get_parent() as Creature
	if creature == null:
		set_process(false)
		return
	if creature.actor_id != _configured_actor_id:
		_configure_for_parent()
	if _definition == null or _definition.frame_count <= 1 \
			or _definition.animation_fps <= 0.0:
		return
	_frame_elapsed += delta
	var seconds_per_frame: float = 1.0 / _definition.animation_fps
	while _frame_elapsed >= seconds_per_frame:
		_frame_elapsed -= seconds_per_frame
		_frame_index = (_frame_index + 1) % _definition.frame_count
		_apply_frame()


func _configure_for_parent() -> void:
	var creature: Creature = get_parent() as Creature
	if creature == null or sprite == null or creature.actor_id.is_empty():
		return
	_configured_actor_id = creature.actor_id
	_definition = Items.actor_definitions.get(String(_configured_actor_id)) as ActorDefinition
	if _definition == null:
		return
	if _definition.texture != null:
		sprite.texture = _definition.texture
	elif _definition.placeholder_color.a > 0.0:
		sprite.texture = _get_placeholder_texture(
			_definition.placeholder_color,
			_definition.placeholder_size
		)
	sprite.scale = _definition.visual_scale
	sprite.modulate = _definition.visual_modulate
	_frame_index = 0
	_frame_elapsed = 0.0
	sprite.region_enabled = _definition.frame_count > 1 \
		and _definition.frame_size.x > 0 and _definition.frame_size.y > 0
	_apply_frame()


func _apply_frame() -> void:
	if sprite == null or _definition == null or not sprite.region_enabled:
		return
	sprite.region_rect = Rect2(
		Vector2(
			float(_frame_index * _definition.frame_size.x),
			float(_definition.frame_row * _definition.frame_size.y)
		),
		Vector2(_definition.frame_size)
	)


func _get_placeholder_texture(color: Color, size: Vector2i) -> ImageTexture:
	var normalized_size: Vector2i = Vector2i(maxi(size.x, 1), maxi(size.y, 1))
	var cache_key: String = "%s:%d:%d" % [
		color.to_html(), normalized_size.x, normalized_size.y
	]
	if _placeholder_textures.has(cache_key):
		return _placeholder_textures[cache_key]
	var image: Image = Image.create(
		normalized_size.x,
		normalized_size.y,
		false,
		Image.FORMAT_RGBA8
	)
	image.fill(color)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_placeholder_textures[cache_key] = texture
	return texture
