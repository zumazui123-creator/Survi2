extends Node
class_name DamageOverTimeEffect

var source: Node
var damage_per_tick: float = 0.0
var remaining_ticks: int = 0
var damage_type: StringName = &"fireDamage"
var tick_interval: float = 1.0


func configure(
		new_source: Node,
		new_damage_per_tick: float,
		duration_seconds: float,
		new_tick_interval: float,
		new_damage_type: StringName
	) -> void:
	source = new_source
	damage_per_tick = maxf(new_damage_per_tick, 0.0)
	tick_interval = maxf(new_tick_interval, 0.1)
	remaining_ticks = maxi(ceili(duration_seconds / tick_interval), 1)
	damage_type = new_damage_type


func refresh(duration_seconds: float) -> void:
	remaining_ticks = maxi(ceili(duration_seconds / tick_interval), remaining_ticks)


func _ready() -> void:
	_run_ticks()


func _run_ticks() -> void:
	while remaining_ticks > 0 and is_instance_valid(get_parent()):
		await get_tree().create_timer(tick_interval).timeout
		var target: Node = get_parent()
		if not is_instance_valid(target) or not target.has_method("getDamage"):
			break
		target.call("getDamage", source, damage_per_tick, damage_type)
		remaining_ticks -= 1
	queue_free()
