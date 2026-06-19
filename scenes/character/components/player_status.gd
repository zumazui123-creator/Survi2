extends Control
class_name PlayerStatus

signal hp_changed(current, max_val)
signal exp_changed(current, max_val)
signal level_changed(new_level)
signal hydration_changed(value)
signal food_changed(value)

@export_group("UI References")
@export var hp_bar: ProgressBar
@export var exp_bar: ProgressBar
@export var hydration_bar: ProgressBar
@export var food_bar: ProgressBar
@export var name_label: Label

@export_group("References")
@export var player: Player
var items: Node
var animation: Node
var movement: Node
var combat: Node

@onready var dayNight 	  = $"../../../dayNight"


@onready var popup_settings: PopupPanel = $"../PopupSettings"
@onready var popup_info: PopupPanel = $"../PopupInfo"

var last_time_hydration: float = 0
var last_time_food: float = 0
var hydration_rate: float = 2
var food_rate: float = 5

var hydration := 100.0:
	set(value):
		hydration = clamp(value, 0, 100)
		hydration_changed.emit(hydration)

var food := 100.0:
	set(value):
		food = clamp(value, 0, 100)
		food_changed.emit(food)


var level := 1:
	set(value):
		level = value
		level_changed.emit(level)

func level_up():
	level += 1
	var threshold = maxExp
	maxExp = 100.0 * level
	exp -= threshold
	attack_damage += 2 # Bonus pro Level
	maxHP += 20
	hp = maxHP
	if animation:
		animation._play_level_up_animation()



@export_group("Stats")
@export var maxHP := 250.0
@export var hp := maxHP:
	set(value):
		hp = clamp(value, 0, maxHP)
		hp_changed.emit(hp, maxHP)
		if is_instance_valid(player) and player.has_node("bloodParticles"):
			player.get_node("bloodParticles").emitting = true
		if hp <= 0 and combat:
			combat.die()

@export var maxExp := 100.0
@export var exp := 0:
	set(value):
		exp = value
		exp_changed.emit(exp, maxExp)
		if exp >= maxExp:
			level_up()

@export var attack_damage := 10.0
@export var attack_rate := 1.0
@export var attack_range := 1.0
@export var damage_type := "normal"

var char_info := {"hp": 1,
		"foodBar": 1,
		"hydrationBar": 1,
		"moveSpeed": 1,
		"attackDmg": 1,
		"attackRate": 1,
		"attackRange": 1,
		"damageType": 1,
		"name": "",
		"pixel_position": [1, 1],
		"tile_position": [1, 1],
		"items": "",
		"time": 3, #TODO
		"terminated": false
		}

func setPlayerName(newName:String):
	char_info["name"] = newName
	_update_level_ui(level)

func resizeNameToFit():
	if not name_label: return
	var fontSize = 14
	while name_label.get_line_count() > 1:
		fontSize -= 1
		name_label.set("theme_override_font_sizes/font_size", fontSize)

func getPlayerStatus():
	char_info = {"hp": hp,
		"foodBar": food,
		"hydrationBar": hydration,
		"moveSpeed": movement.move_speed_factor if movement else 1.0,
		"attackDmg": attack_damage,
		"attackRate": attack_rate,
		"attackRange": attack_range,
		"damageType": damage_type,
		"name": player.playerName,
		"pixel_position": [player.position.x, player.position.y],
		"tile_position":[movement.current_map_position.x, movement.current_map_position.y] if movement else [0,0],
		"items": Inventory.getItems(str(player.name)),
		"time": 3, #TODO
		"terminated": false
		}
	return char_info


func _ready() -> void:
	if not player: player = get_parent()
	if not items: items = player.p_items
	if not animation: animation = player.p_animation
	if not movement: movement = player.p_movement
	if not combat: combat = player.p_combat

	# Verbinde interne Signale für UI-Updates
	hp_changed.connect(_update_hp_ui)
	exp_changed.connect(_update_exp_ui)
	level_changed.connect(_update_level_ui)
	hydration_changed.connect(_update_hydration_ui)
	food_changed.connect(_update_food_ui)

	if player.name != str(multiplayer.get_unique_id()):
		if has_node("Bar"): $Bar.visible = false
		if has_node("WorkContainer"): $WorkContainer.visible = false

	if player.playerName != "":
		setPlayerName(player.playerName)
	elif char_info.has("name") and char_info["name"] != "":
		setPlayerName(char_info["name"])

	hydration = 100.0
	food = 100.0

	# Initiale UI-Synchronisierung
	_update_hp_ui(hp, maxHP)
	_update_exp_ui(exp, 100.0)
	_update_hydration_ui(hydration)
	_update_food_ui(food)
	_update_level_ui(level)

	getPlayerStatus()


# UI Update Funktionen
func _update_hp_ui(current, max_val):
	if hp_bar:
		hp_bar.max_value = max_val
		hp_bar.value = current

func _update_exp_ui(current, max_val):
	if exp_bar:
		exp_bar.max_value = max_val
		exp_bar.value = current

func _update_level_ui(new_level):
	if name_label and player:
		name_label.text = player.playerName + " [Lvl " + str(new_level) + "]"
		resizeNameToFit()

func _update_hydration_ui(value):
	if hydration_bar:
		hydration_bar.value = value

func _update_food_ui(value):
	if food_bar:
		food_bar.value = value

@rpc("any_peer", "call_local", "reliable")
func gain_exp(amount: float):
	exp += amount

#@rpc("authority", "call_local", "reliable")
@rpc("any_peer", "call_local", "reliable")
func get_heal(heal_hp : float):
	hp += heal_hp

func _process(_delta: float) -> void:
	var now = GameTime.get_hour()
	if now - last_time_hydration > hydration_rate:
		hydration -= 1
		last_time_hydration = now

	if now - last_time_food > food_rate:
		food -= 1
		last_time_food = now


func _on_settings_button_pressed() -> void:
	popup_settings.visible = true


func _on_info_button_pressed() -> void:
	popup_info.visible = true


func _on_settings_ok_btn_pressed() -> void:
	popup_settings.visible = false
