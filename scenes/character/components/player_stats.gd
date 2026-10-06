extends Node
class_name PlayerStats

signal hp_changed(current: float, maximum: float)
signal exp_changed(current: float, maximum: float)
signal level_changed(value: int)
signal leveled_up(value: int)
signal hydration_changed(value: float)
signal food_changed(value: float)
signal died()

@export_group("Stats")
@export var max_hp: float = 250.0:
	set(value):
		max_hp = maxf(value, 1.0)
		hp = minf(hp, max_hp)
		hp_changed.emit(hp, max_hp)

@export var hp: float = 250.0:
	set(value):
		var previous_hp := hp
		hp = clampf(value, 0.0, max_hp)
		hp_changed.emit(hp, max_hp)
		if previous_hp > 0.0 and hp <= 0.0:
			died.emit()

@export var max_exp: float = 100.0:
	set(value):
		max_exp = maxf(value, 1.0)
		exp_changed.emit(exp, max_exp)

@export var exp: float = 0.0:
	set(value):
		exp = maxf(value, 0.0)
		exp_changed.emit(exp, max_exp)

@export var level: int = 1:
	set(value):
		level = maxi(value, 1)
		level_changed.emit(level)

@export var attack_damage: float = 10.0
@export var attack_rate: float = 1.0
@export var attack_range: float = 1.0
@export var damage_type: StringName = &"normal"

@export_group("Survival")
@export var hydration: float = 100.0:
	set(value):
		hydration = clampf(value, 0.0, 100.0)
		hydration_changed.emit(hydration)

@export var food: float = 100.0:
	set(value):
		food = clampf(value, 0.0, 100.0)
		food_changed.emit(food)

var terminated := false


func _ready() -> void:
	_emit_initial_state()


func _emit_initial_state() -> void:
	hp_changed.emit(hp, max_hp)
	exp_changed.emit(exp, max_exp)
	level_changed.emit(level)
	hydration_changed.emit(hydration)
	food_changed.emit(food)


func gain_exp(amount: float) -> void:
	if amount <= 0.0:
		return

	var remaining_exp := exp + amount
	while remaining_exp >= max_exp:
		remaining_exp -= max_exp
		_apply_level_up()
	exp = remaining_exp


func _apply_level_up() -> void:
	level += 1
	max_exp = 100.0 * level
	attack_damage += 2.0
	max_hp += 20.0
	hp = max_hp
	leveled_up.emit(level)


func apply_damage(amount: float) -> void:
	if amount > 0.0:
		hp -= amount


func heal(amount: float) -> void:
	if amount > 0.0:
		hp += amount
