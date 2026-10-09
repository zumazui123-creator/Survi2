extends Resource
class_name ProjectileDefinition

@export var projectile_id: StringName
@export var texture: Texture2D
@export var max_hits := 1
@export var speed := 50.0
@export var lifetime := 1.0
@export var curve_speed := true
@export_range(1, 16, 1) var horizontal_frames: int = 4
@export var effect: StringName


func to_legacy_dict() -> Dictionary:
	var data := {
		"maxHits": max_hits,
		"speed": speed,
		"time": lifetime,
		"curveSpeed": curve_speed,
		"horizontalFrames": horizontal_frames,
	}
	if not effect.is_empty():
		data["effect"] = String(effect)
	return data
