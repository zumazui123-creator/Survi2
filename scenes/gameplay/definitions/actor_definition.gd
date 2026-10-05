extends Resource
class_name ActorDefinition

@export var actor_id: StringName
@export var texture: Texture2D
@export var max_hp := 100.0
@export var speed := 50.0
@export var attack: StringName
@export var attack_damage := 1.0
@export var attack_range := 50.0
@export var drops: Dictionary = {}


func to_legacy_dict() -> Dictionary:
	return {
		"maxhp": max_hp,
		"speed": speed,
		"attack": String(attack),
		"attackDamage": attack_damage,
		"attackRange": attack_range,
		"drops": drops.duplicate(true),
	}
