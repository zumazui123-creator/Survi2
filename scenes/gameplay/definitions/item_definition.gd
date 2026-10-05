extends Resource
class_name ItemDefinition

enum Kind {
	MATERIAL,
	CONSUMABLE,
	EQUIPMENT,
}

@export var item_id: StringName
@export var icon: Texture2D
@export var kind: Kind = Kind.MATERIAL
@export var attack: StringName
@export var damage := 0.0
@export var damage_type: StringName
@export var durability := 0.0
@export var equipment_scene: PackedScene
@export var projectile_id: StringName
@export var effects: Dictionary = {}
@export var recipe: Dictionary = {}


func to_legacy_equipment() -> Dictionary:
	var data := {
		"attack": String(attack),
		"damage": damage,
		"damageType": String(damage_type),
		"durability": durability,
	}
	if equipment_scene:
		data["packed_scene"] = equipment_scene
	if not projectile_id.is_empty():
		data["projectile"] = String(projectile_id)
	return data
