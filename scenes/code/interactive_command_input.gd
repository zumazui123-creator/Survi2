extends Node
class_name InteractiveCommandInput

const SUCCESS_COLOR: Color = Color(0.32, 1.0, 0.42, 1.0)
const ERROR_COLOR: Color = Color(1.0, 0.28, 0.28, 1.0)
const INPUT_COLOR: Color = Color.WHITE

signal mode_changed(enabled: bool)
signal word_changed(word: String)
signal command_accepted(command: String)
signal command_execution_started(command: String)
signal command_rejected(command: String, reason: String)

@export_range(3, 64, 1) var maximum_word_length: int = 30
@export_range(0.25, 5.0, 0.05) var feedback_duration: float = 1.5

var code_player: CodePlayer
var function_library: FunctionHandler
var display_label: Label
var enabled: bool = false

var _word_buffer: String = ""
var _pending_commands: Array[String] = []
var _waiting_for_execution: bool = false
var _active_command: String = ""
var _parser: CodeParser = CodeParser.new()
var _feedback_timer: Timer


func _ready() -> void:
	_feedback_timer = Timer.new()
	_feedback_timer.name = "FeedbackTimer"
	_feedback_timer.one_shot = true
	_feedback_timer.timeout.connect(_clear_feedback)
	add_child(_feedback_timer)
	set_process_input(false)


func bind_components(
		value_code_player: CodePlayer,
		value_function_library: FunctionHandler,
		value_display_label: Label
	) -> void:
	_disconnect_code_player()
	code_player = value_code_player
	function_library = value_function_library
	display_label = value_display_label
	_word_buffer = ""
	_pending_commands.clear()
	_waiting_for_execution = false
	_active_command = ""
	_clear_feedback()
	if is_instance_valid(code_player):
		code_player.execution_finished.connect(_on_execution_ended)
		code_player.execution_cancelled.connect(_on_execution_ended)
		code_player.runtime_error.connect(_on_runtime_error)
	_update_display()


func unbind_components() -> void:
	set_enabled(false)
	_disconnect_code_player()
	_waiting_for_execution = false
	code_player = null
	function_library = null
	display_label = null


func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	_word_buffer = ""
	_pending_commands.clear()
	_active_command = ""
	_clear_feedback()
	set_process_input(enabled)
	_update_display()
	mode_changed.emit(enabled)


func _input(event: InputEvent) -> void:
	if not enabled or not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.ctrl_pressed or key_event.alt_pressed or key_event.meta_pressed:
		return

	if key_event.keycode == KEY_SPACE \
			or key_event.physical_keycode == KEY_SPACE \
			or key_event.unicode == 32:
		_submit_word()
		get_viewport().set_input_as_handled()
		return

	if key_event.keycode == KEY_BACKSPACE or key_event.physical_keycode == KEY_BACKSPACE:
		_clear_feedback()
		_remove_last_character()
		get_viewport().set_input_as_handled()
		return

	if key_event.unicode <= 0 or _word_buffer.length() >= maximum_word_length:
		return
	_clear_feedback()
	var character: String = String.chr(key_event.unicode)
	if character.strip_edges().is_empty():
		return
	_word_buffer += character
	_update_display()
	word_changed.emit(_word_buffer)
	get_viewport().set_input_as_handled()


func _remove_last_character() -> void:
	if _word_buffer.is_empty():
		return
	_word_buffer = _word_buffer.left(_word_buffer.length() - 1)
	_update_display()
	word_changed.emit(_word_buffer)


func _submit_word() -> void:
	var submitted_word: String = _word_buffer.strip_edges()
	_word_buffer = ""
	_update_display()
	word_changed.emit("")
	if submitted_word.is_empty():
		return

	var validation: Dictionary = _validate_word(submitted_word)
	if not bool(validation.get("valid", false)):
		var error_message: String = String(validation.get("error", ""))
		_show_error_feedback(submitted_word, error_message)
		command_rejected.emit(submitted_word, error_message)
		return
	var executable_command: String = String(validation.get("command", submitted_word))
	_pending_commands.append(executable_command)
	command_accepted.emit(executable_command)
	_run_next_command()


func _validate_word(word: String) -> Dictionary:
	if not is_instance_valid(code_player):
		return {"valid": false, "error": "Der CodePlayer ist nicht verbunden."}
	if not Multihelper.code_player_enabled:
		return {"valid": false, "error": "Der CodePlayer ist derzeit deaktiviert."}

	var functions: Dictionary = _get_functions()
	var command: String = FunctionNamePolicy.normalize_name(word)
	var parse_result: CodeParser.ParseResult = _parser.parse(
		command,
		functions,
		Strings.current_locale
	)
	if parse_result.has_error():
		return {"valid": false, "error": parse_result.error_message}
	if parse_result.commands.is_empty():
		return {"valid": false, "error": "Das Wort enthält keinen ausführbaren Befehl."}
	return {"valid": true, "command": command}


func _run_next_command() -> void:
	if _waiting_for_execution or _pending_commands.is_empty():
		return
	if not is_instance_valid(code_player) or not Multihelper.code_player_enabled:
		_pending_commands.clear()
		return
	_waiting_for_execution = true
	var command: String = _pending_commands.pop_front()
	_active_command = command
	_show_success_feedback(command)
	command_execution_started.emit(command)
	code_player.play(command, _get_functions())


func _get_functions() -> Dictionary:
	return function_library.functions if is_instance_valid(function_library) else {}


func _update_display() -> void:
	if not is_instance_valid(display_label):
		return
	display_label.text = _word_buffer
	display_label.modulate = INPUT_COLOR
	display_label.visible = enabled and not _word_buffer.is_empty()


func _show_success_feedback(command: String) -> void:
	if not enabled or not _word_buffer.is_empty():
		return
	var is_function: bool = is_instance_valid(function_library) \
		and function_library.has_function(command)
	var message: String = "%s – Funktion gestartet" % command \
		if is_function else "%s ✓" % command
	_show_feedback(message, SUCCESS_COLOR)


func _show_error_feedback(command: String, reason: String) -> void:
	var feedback_reason: String = _get_short_error_reason(reason)
	_show_feedback("%s ✗ – %s" % [command, feedback_reason], ERROR_COLOR)


func _show_feedback(message: String, color: Color) -> void:
	if not enabled or not _word_buffer.is_empty() or not is_instance_valid(display_label):
		return
	display_label.text = message
	display_label.modulate = color
	display_label.visible = true
	if is_instance_valid(_feedback_timer):
		_feedback_timer.start(feedback_duration)


func _clear_feedback() -> void:
	if is_instance_valid(_feedback_timer):
		_feedback_timer.stop()
	if not is_instance_valid(display_label):
		return
	display_label.modulate = INPUT_COLOR
	display_label.visible = enabled and not _word_buffer.is_empty()
	if not display_label.visible:
		display_label.text = ""


func _get_short_error_reason(reason: String) -> String:
	var normalized_reason: String = reason.strip_edges().trim_suffix(".")
	var lower_reason: String = normalized_reason.to_lower()
	if lower_reason.contains("benötigt") or lower_reason.contains("braucht"):
		return "benötigt weitere Wörter"
	if lower_reason.contains("unbekannter befehl"):
		return "kein einzelner Befehl"
	return normalized_reason if not normalized_reason.is_empty() else "ungültiger Befehl"


func _disconnect_code_player() -> void:
	if not is_instance_valid(code_player):
		return
	if code_player.execution_finished.is_connected(_on_execution_ended):
		code_player.execution_finished.disconnect(_on_execution_ended)
	if code_player.execution_cancelled.is_connected(_on_execution_ended):
		code_player.execution_cancelled.disconnect(_on_execution_ended)
	if code_player.runtime_error.is_connected(_on_runtime_error):
		code_player.runtime_error.disconnect(_on_runtime_error)


func _on_execution_ended() -> void:
	if not _waiting_for_execution:
		return
	_waiting_for_execution = false
	_active_command = ""
	call_deferred("_run_next_command")


func _on_runtime_error(_message: String) -> void:
	if not _waiting_for_execution:
		return
	_show_error_feedback(_active_command, _message)
	if is_instance_valid(code_player) and code_player.is_running:
		return
	_waiting_for_execution = false
	_active_command = ""
	call_deferred("_run_next_command")


func _exit_tree() -> void:
	unbind_components()
