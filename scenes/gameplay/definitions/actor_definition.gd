extends Resource
class_name ActorDefinition

@export var actor_id: StringName
@export var texture: Texture2D
@export var max_hp: float = 100.0
@export var speed: float = 50.0
@export var attack: StringName
@export var attack_damage: float = 1.0
@export var attack_range: float = 50.0
@export var drops: Dictionary = {}
@export_group("Visual")
@export var frame_size: Vector2i = Vector2i.ZERO
@export_range(1, 32, 1) var frame_count: int = 1
@export_range(0.0, 30.0, 0.5) var animation_fps: float = 0.0
@export_range(0, 32, 1) var frame_row: int = 0
@export var visual_scale: Vector2 = Vector2.ONE
@export var visual_modulate: Color = Color.WHITE
@export var placeholder_color: Color = Color.TRANSPARENT
@export var placeholder_size: Vector2i = Vector2i(32, 32)


func to_legacy_dict() -> Dictionary:
	return {
		"maxhp": max_hp,
		"speed": speed,
		"attack": String(attack),
		"attackDamage": attack_damage,
		"attackRange": attack_range,
		"drops": drops.duplicate(true),
	}
