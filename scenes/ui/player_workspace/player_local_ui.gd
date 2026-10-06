extends Node
class_name PlayerLocalUI

var player: CharacterBody2D

@onready var code_editor: CodeEdit = $CodeLayer/Code/TabContainer/Code/CodeEdit
@onready var code_controller: CodeEditorController = $CodeLayer/Code
@onready var work_task_text: RichTextLabel = $PopupInfo/workTaskText
@onready var difficulty_button: OptionButton = $PopupSettings/VBoxContainer/HBoxContainer/DifModeButton
@onready var settings_popup: PopupPanel = $PopupSettings
@onready var info_popup: PopupPanel = $PopupInfo
@onready var ai_playground: RLPlaygroundUI = $"CodeLayer/Code/TabContainer/KI Playground"


func bind_player(value: CharacterBody2D) -> void:
	player = value
	code_controller.bind_code_player(player.code_player)
	player.local_ui = self
	player.code_edit = code_editor
	player.workTaskText = work_task_text
	ai_playground.bind_components(player.rl_agent, player.rl_trainer, player.environment)


func show_settings() -> void:
	settings_popup.popup_centered()


func show_info() -> void:
	info_popup.popup_centered()


func get_difficulty_mode() -> int:
	return difficulty_button.get_selected_id()


func _on_back_to_menu_pressed() -> void:
	var game_scene: PackedScene = load(Constants.PATH_GAME_SCENE)
	get_tree().change_scene_to_packed(game_scene)


func _on_settings_ok_pressed() -> void:
	settings_popup.hide()
