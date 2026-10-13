extends StaticBody2D
class_name BossWeakPoint

signal weak_point_damaged(weak_point: BossWeakPoint)
signal weak_point_destroyed(weak_point: BossWeakPoint)

@export var max_hp: float = 160.0
@export var hp: float = 160.0
@export var destroyed: bool = false:
	set(value):
		destroyed = value
		_apply_destroyed_state()


func _ready() -> void:
	hp = clampf(hp, 0.0, max_hp)
	_apply_destroyed_state()


func getDamage(_causer: Node, amount: float, _damage_type: StringName) -> void:
	if not multiplayer.is_server() or destroyed or amount <= 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	weak_point_damaged.emit(self)
	if hp <= 0.0:
		destroyed = true
		weak_point_destroyed.emit(self)


func _apply_destroyed_state() -> void:
	if not is_inside_tree():
		return
	visible = not destroyed
	if destroyed:
		remove_from_group(&"damageable")
		remove_from_group(&"sensor_object")
	else:
		if not is_in_group(&"damageable"):
			add_to_group(&"damageable")
		if not is_in_group(&"sensor_object"):
			add_to_group(&"sensor_object")
	var collision: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		collision.set_deferred("disabled", destroyed)
