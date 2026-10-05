extends Node
class_name PlayerStats

signal hp_changed(current: float, maximum: float)
signal exp_changed(current: float, maximum: float)
signal level_changed(value: int)
signal hydration_changed(value: float)
signal food_changed(value: float)
signal died

@export var player: CharacterBody2D

@export_group("Stats")
@export var max_hp: float = 250.0:
	set(value):
		max_hp = maxf(value, 1.0)
		hp = minf(hp, max_hp)
		hp_changed.emit(hp, max_hp)

@export var hp: float = 250.0:
	set(value):
		hp = clampf(value, 0.0, max_hp)
		hp_changed.emit(hp, max_hp)
		if hp <= 0.0:
			died.emit()

@export var max_exp: float = 100.0
@export var exp: float = 0.0:
	set(value):
		exp = value
		exp_changed.emit(exp, max_exp)
		if exp >= max_exp:
			_level_up()

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

@export var hydration_interval_hours: float = 2.0
@export var food_interval_hours: float = 5.0

var terminated := false
var _last_hydration_hour := 0.0
var _last_food_hour := 0.0


func _ready() -> void:
	died.connect(_on_died)
	_emit_initial_state()


func _process(_delta: float) -> void:
	var current_hour: float = GameTime.get_hour()
	if current_hour - _last_hydration_hour > hydration_interval_hours:
		hydration -= 1.0
		_last_hydration_hour = current_hour

	if current_hour - _last_food_hour > food_interval_hours:
		food -= 1.0
		_last_food_hour = current_hour


func _emit_initial_state() -> void:
	hp_changed.emit(hp, max_hp)
	exp_changed.emit(exp, max_exp)
	level_changed.emit(level)
	hydration_changed.emit(hydration)
	food_changed.emit(food)


func _level_up() -> void:
	var threshold := max_exp
	level += 1
	max_exp = 100.0 * level
	exp -= threshold
	attack_damage += 2.0
	max_hp += 20.0
	hp = max_hp
	if player and player.animation:
		player.animation._play_level_up_animation(level)


func _on_died() -> void:
	if player and player.has_node("bloodParticles"):
		player.get_node("bloodParticles").emitting = true
	if player and player.combat:
		player.combat.die()


func gain_exp(amount: float) -> void:
	exp += amount


@rpc("any_peer", "call_local", "reliable")
func get_heal(heal_hp: float) -> void:
	hp += heal_hp


func snapshot() -> Dictionary:
	var movement = player.movement if player else null
	return {
		"hp": hp,
		"foodBar": food,
		"hydrationBar": hydration,
		"moveSpeed": movement.move_speed_factor if movement else 1.0,
		"attackDmg": attack_damage,
		"attackRate": attack_rate,
		"attackRange": attack_range,
		"damageType": damage_type,
		"name": player.playerName if player else "",
		"pixel_position": [player.position.x, player.position.y] if player else [0, 0],
		"tile_position": [movement.current_map_position.x, movement.current_map_position.y] if movement else [0, 0],
		"items": Inventory.getItems(str(player.name)) if player else {},
		"time": GameTime.get_hour(),
		"terminated": terminated,
	}
