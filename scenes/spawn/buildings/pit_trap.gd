extends BuildingEntity
class_name PitTrapBuilding

const DAMAGE_COOLDOWN_META: StringName = &"pit_trap_damage_until"

@export_range(1.0, 100.0, 1.0) var contact_damage: float = 24.0
@export_range(100, 5000, 100) var damage_cooldown_ms: int = 1200

@onready var damage_area: Area2D = $DamageArea


func _ready() -> void:
	super()
	if not damage_area.body_entered.is_connected(_on_body_entered):
		damage_area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not multiplayer.is_server() or not is_instance_valid(body):
		return
	if not body.has_method("getDamage"):
		return
	var now: int = Time.get_ticks_msec()
	if int(body.get_meta(DAMAGE_COOLDOWN_META, 0)) > now:
		return
	body.set_meta(DAMAGE_COOLDOWN_META, now + damage_cooldown_ms)
	body.call("getDamage", self, contact_damage, &"normal")
