extends Node
class_name BossArenaController

signal arena_activated()
signal protection_changed(protected: bool)
signal all_weak_points_destroyed()

@export var weak_point_paths: Array[NodePath] = []

var _boss: BossCreature
var _weak_points: Array[BossWeakPoint] = []
var _activated: bool = false


func _ready() -> void:
	_boss = get_parent() as BossCreature
	for path: NodePath in weak_point_paths:
		var weak_point: BossWeakPoint = get_node_or_null(path) as BossWeakPoint
		if weak_point == null:
			continue
		_weak_points.append(weak_point)
		weak_point.weak_point_damaged.connect(_on_weak_point_damaged)
		weak_point.weak_point_destroyed.connect(_on_weak_point_destroyed)
	protection_changed.emit(is_boss_protected())


func activate_arena() -> void:
	if _activated:
		return
	_activated = true
	if is_instance_valid(_boss):
		_boss.awaken()
	arena_activated.emit()


func is_boss_protected() -> bool:
	for weak_point: BossWeakPoint in _weak_points:
		if is_instance_valid(weak_point) and not weak_point.destroyed:
			return true
	return false


func get_remaining_weak_point_count() -> int:
	var remaining: int = 0
	for weak_point: BossWeakPoint in _weak_points:
		if is_instance_valid(weak_point) and not weak_point.destroyed:
			remaining += 1
	return remaining


func _on_weak_point_damaged(_weak_point: BossWeakPoint) -> void:
	activate_arena()


func _on_weak_point_destroyed(_weak_point: BossWeakPoint) -> void:
	var protected: bool = is_boss_protected()
	protection_changed.emit(protected)
	if not protected:
		all_weak_points_destroyed.emit()
