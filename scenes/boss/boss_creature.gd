extends Enemy
class_name BossCreature

signal boss_awakened()
signal boss_phase_changed(phase: int)

@export var dormant: bool = true
@export_range(0.05, 1.0, 0.05) var phase_two_threshold: float = 0.6
@export_range(0.05, 1.0, 0.05) var phase_three_threshold: float = 0.3

var boss_phase: int = 1


func awaken() -> void:
	if not dormant:
		return
	dormant = false
	boss_awakened.emit()


func getDamage(causer: Node, amount: float, damage_type: StringName) -> void:
	var hp_before_damage: float = hp
	if dormant and amount > 0.0:
		awaken()
	super(causer, amount, damage_type)
	if hp < hp_before_damage and not _is_dead:
		play_boss_visual_event.rpc(&"hurt")
	_update_boss_phase()


func _update_boss_phase() -> void:
	if maxhp <= 0.0:
		return
	var ratio: float = hp / maxhp
	var new_phase: int = 3 if ratio <= phase_three_threshold \
		else 2 if ratio <= phase_two_threshold else 1
	if new_phase == boss_phase:
		return
	boss_phase = new_phase
	boss_phase_changed.emit(boss_phase)


func _should_despawn_while_idle() -> bool:
	return false


func _can_drop_loot() -> bool:
	return true


## Shared extension points used by composable BossAttack nodes.
func get_phase_damage_multiplier() -> float:
	return 1.0


func get_phase_interval_multiplier() -> float:
	return 1.0


func get_world_map() -> Map:
	return get_tree().get_first_node_in_group("world_map") as Map


func is_defeated() -> bool:
	return _is_dead or not is_inside_tree()


@rpc("authority", "call_local", "reliable")
func play_boss_visual_event(event_name: StringName) -> void:
	var visual: BossAnimatedVisual = get_node_or_null("MovingParts/BossVisual") as BossAnimatedVisual
	if visual != null:
		visual.play_visual_event(event_name)
