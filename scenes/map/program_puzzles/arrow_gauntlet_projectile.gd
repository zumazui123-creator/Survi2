extends Node2D
class_name ArrowGauntletProjectile

@export var direction: Vector2 = Vector2.RIGHT
@export var speed: float = 430.0
@export var damage: float = 10.0
@export var building_damage: float = 4.0
@export var lifetime_seconds: float = 1.2

var _elapsed: float = 0.0
var _hit_bodies: Dictionary[int, bool] = {}


func _ready() -> void:
	if not direction.is_zero_approx():
		rotation = direction.angle()


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	position += direction.normalized() * speed * delta
	_elapsed += delta
	if _elapsed >= lifetime_seconds:
		queue_free()


func _on_hit_area_body_entered(body: Node2D) -> void:
	if not multiplayer.is_server() or body == null:
		return
	var body_id: int = body.get_instance_id()
	if _hit_bodies.has(body_id) or not body.is_in_group(&"damageable"):
		return
	_hit_bodies[body_id] = true
	if body.has_method("getDamage"):
		var applied_damage: float = building_damage if body is BuildingEntity else damage
		body.call("getDamage", self, applied_damage, &"normal")
	queue_free()
