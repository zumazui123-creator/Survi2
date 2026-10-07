extends Control
class_name PlayerStatusView

signal settings_requested
signal info_requested

@export_group("UI References")
@export var hp_bar: ProgressBar
@export var mana_bar: ProgressBar
@export var exp_bar: ProgressBar
@export var hydration_bar: ProgressBar
@export var food_bar: ProgressBar
@export var name_label: Label

@export_group("References")
@export var player: CharacterBody2D
@export var stats: PlayerStats

func _ready() -> void:
	stats.hp_changed.connect(_update_hp_ui)
	stats.mana_changed.connect(_update_mana_ui)
	stats.exp_changed.connect(_update_exp_ui)
	stats.level_changed.connect(_update_level_ui)
	stats.hydration_changed.connect(_update_hydration_ui)
	stats.food_changed.connect(_update_food_ui)

	if player.name != str(multiplayer.get_unique_id()):
		if has_node("Bar"):
			$Bar.visible = false
		if has_node("WorkContainer"):
			$WorkContainer.visible = false

	_update_hp_ui(stats.hp, stats.max_hp)
	_update_mana_ui(stats.mana, stats.max_mana)
	_update_exp_ui(stats.exp, stats.max_exp)
	_update_hydration_ui(stats.hydration)
	_update_food_ui(stats.food)
	_update_level_ui(stats.level)


func set_player_name(new_name: String) -> void:
	if name_label:
		name_label.text = new_name + " [Lvl " + str(stats.level) + "]"
		_resize_name_to_fit()


func _resize_name_to_fit() -> void:
	if not name_label:
		return
	var font_size: int = 14
	while name_label.get_line_count() > 1 and font_size > 8:
		font_size -= 1
		name_label.set("theme_override_font_sizes/font_size", font_size)


func _update_hp_ui(current: float, maximum: float) -> void:
	if hp_bar:
		hp_bar.max_value = maximum
		hp_bar.value = current


func _update_mana_ui(current: float, maximum: float) -> void:
	if mana_bar:
		mana_bar.max_value = maximum
		mana_bar.value = current


func _update_exp_ui(current: float, maximum: float) -> void:
	if exp_bar:
		exp_bar.max_value = maximum
		exp_bar.value = current


func _update_level_ui(new_level: int) -> void:
	if name_label and player:
		name_label.text = player.playerName + " [Lvl " + str(new_level) + "]"
		_resize_name_to_fit()


func _update_hydration_ui(value: float) -> void:
	if hydration_bar:
		hydration_bar.value = value


func _update_food_ui(value: float) -> void:
	if food_bar:
		food_bar.value = value


func _on_settings_button_pressed() -> void:
	settings_requested.emit()


func _on_info_button_pressed() -> void:
	info_requested.emit()
