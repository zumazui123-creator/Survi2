extends Node
class_name PlayerLocalUI

@onready var code_controller: CodeEditorController = $CodeLayer/Code
@onready var function_library: FunctionHandler = $FunctionLibrary
@onready var interactive_input: InteractiveCommandInput = $InteractiveCommandInput
@onready var tab_container: TabContainer = $CodeLayer/Code/TabContainer
@onready var work_task_text: RichTextLabel = %WorkTaskText
@onready var difficulty_button: OptionButton = %DifModeButton
@onready var settings_popup: PopupPanel = %PopupSettings
@onready var info_popup: PopupPanel = %PopupInfo
@onready var ai_playground: RLPlaygroundUI = get_node("%KI") as RLPlaygroundUI
@onready var environment_settings: AIEnvironmentSettingsUI = %Umgebung


func _ready() -> void:
	tab_container.set_tab_title(ai_playground.get_index(), "KI")


func bind_components(
		code_player: CodePlayer,
		rl_agent: RLAgent,
		rl_trainer: RLTrainer,
		environment: Survi2NavigationEnv,
		player_profile_id: String
	) -> void:
	var input_label: Label
	if is_instance_valid(code_player) and is_instance_valid(code_player.player):
		input_label = code_player.player.get_node_or_null("%InteractiveInputLabel") as Label
	function_library.bind_player_profile(player_profile_id)
	interactive_input.bind_components(code_player, function_library, input_label)
	code_controller.bind_components(code_player, function_library, interactive_input)
	ai_playground.bind_components(rl_agent, rl_trainer, environment)
	environment_settings.bind_components(environment, rl_trainer)


func set_work_task_text(value: String) -> void:
	work_task_text.text = value


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
