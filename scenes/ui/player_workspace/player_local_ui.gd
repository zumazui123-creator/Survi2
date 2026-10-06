extends Node
class_name PlayerLocalUI

var player: CharacterBody2D

@onready var code_editor: CodeEdit = $CodeLayer/Code/TabContainer/Code/CodeEdit
@onready var code_controller: CodeEditorController = $CodeLayer/Code
@onready var work_task_text: RichTextLabel = $PopupInfo/workTaskText
@onready var difficulty_button: OptionButton = $PopupSettings/VBoxContainer/HBoxContainer/DifModeButton
@onready var settings_popup: PopupPanel = $PopupSettings
@onready var info_popup: PopupPanel = $PopupInfo
@onready var speed_label: Label = $"CodeLayer/Code/TabContainer/KI Playground/VBoxContainer/GameSetContainer/HBoxContainer2/Speed"


func bind_player(value: CharacterBody2D) -> void:
	player = value
	code_controller.bind_code_player(player.code_player)
	player.local_ui = self
	player.code_edit = code_editor
	player.workTaskText = work_task_text
	speed_label.text = str(player.movement.move_speed_factor)
	player.movement.speed_changed.connect(_on_speed_changed)


func show_settings() -> void:
	settings_popup.popup_centered()


func show_info() -> void:
	info_popup.popup_centered()


func get_difficulty_mode() -> int:
	return difficulty_button.get_selected_id()


func _on_speed_changed(value: float) -> void:
	speed_label.text = str(value)


func _on_speed_plus_pressed() -> void:
	player.movement.set_speed(0.2)


func _on_speed_minus_pressed() -> void:
	player.movement.set_speed(-0.2)


func _on_back_to_menu_pressed() -> void:
	var game_scene: PackedScene = load(Constants.PATH_GAME_SCENE)
	get_tree().change_scene_to_packed(game_scene)


func _on_settings_ok_pressed() -> void:
	settings_popup.hide()
