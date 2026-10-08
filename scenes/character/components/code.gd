extends Node
class_name CodeEditorController

const EXECUTION_LINE_COLOR: Color = Color(0.1, 0.45, 0.75, 0.45)
const ERROR_LINE_COLOR: Color = Color(0.75, 0.12, 0.12, 0.5)

var code_player: CodePlayer
var function_library: FunctionHandler
var highlighter: MyCodeHighLighter
var _highlighted_line: int = -1
var _line_number_pattern: RegEx = RegEx.new()
var _last_runtime_error: String = ""
var _last_error_line: int = 0

@onready var code_edit: CodeEdit = %CodeEdit
@onready var item_list: ItemList = %ItemList
@onready var function_name_input: LineEdit = %InputFuncName
@onready var function_code_edit: CodeEdit = %FunctionCodeEdit
@onready var function_list: ItemList = %FuncList
@onready var function_popup: PopupPanel = %PopupFunction
@onready var function_exit_button: Button = %ExitBtn
@onready var play_button: Button = %PlayButton
@onready var pause_button: Button = %PauseButton
@onready var step_button: Button = %StepButton
@onready var stop_button: Button = %StopButton
@onready var undo_button: Button = %UndoButton
@onready var redo_button: Button = %RedoButton
@onready var example_selector: OptionButton = %ExampleSelector
@onready var load_example_button: Button = %LoadExampleButton
@onready var status_label: Label = %EditorStatus
@onready var command_help_label: Label = %CommandHelp


func _ready() -> void:
	_line_number_pattern.compile("\\(Zeile (\\d+)\\)")
	function_exit_button.pressed.connect(_on_exit_button_pressed)
	highlighter = MyCodeHighLighter.new()
	highlighter.setup_custom_highlighter(code_edit, Strings.current_locale)
	highlighter.setup_custom_highlighter(function_code_edit, Strings.current_locale)
	_setup_editor_assistance()
	_refresh_examples()
	_refresh_function_lists()
	_set_execution_buttons(false)
	_set_status("Bereit – Strg+Leertaste zeigt Befehle.", false)
	if Multihelper.code_player_enabled:
		print("Debug Code Playing enabled.")


func bind_components(value_code_player: CodePlayer, value_function_library: FunctionHandler) -> void:
	_disconnect_components()
	code_player = value_code_player
	function_library = value_function_library
	if is_instance_valid(code_player):
		code_player.execution_started.connect(_on_execution_started)
		code_player.execution_finished.connect(_on_execution_ended)
		code_player.execution_cancelled.connect(_on_execution_cancelled)
		code_player.source_line_started.connect(_on_source_line_started)
		code_player.runtime_error.connect(_on_runtime_error)
		code_player.pause_changed.connect(_on_pause_changed)
	if is_instance_valid(function_library):
		function_library.functions_changed.connect(_refresh_function_lists)
	_refresh_function_lists()
	_set_execution_buttons(is_instance_valid(code_player) and code_player.is_running)


func unbind_components() -> void:
	_disconnect_components()
	code_player = null
	function_library = null
	_set_execution_buttons(false)


func _disconnect_components() -> void:
	if is_instance_valid(code_player):
		if code_player.execution_started.is_connected(_on_execution_started):
			code_player.execution_started.disconnect(_on_execution_started)
		if code_player.execution_finished.is_connected(_on_execution_ended):
			code_player.execution_finished.disconnect(_on_execution_ended)
		if code_player.execution_cancelled.is_connected(_on_execution_cancelled):
			code_player.execution_cancelled.disconnect(_on_execution_cancelled)
		if code_player.source_line_started.is_connected(_on_source_line_started):
			code_player.source_line_started.disconnect(_on_source_line_started)
		if code_player.runtime_error.is_connected(_on_runtime_error):
			code_player.runtime_error.disconnect(_on_runtime_error)
		if code_player.pause_changed.is_connected(_on_pause_changed):
			code_player.pause_changed.disconnect(_on_pause_changed)
	if is_instance_valid(function_library) \
			and function_library.functions_changed.is_connected(_refresh_function_lists):
		function_library.functions_changed.disconnect(_refresh_function_lists)


func _setup_editor_assistance() -> void:
	code_edit.code_completion_enabled = true
	code_edit.code_completion_requested.connect(_on_code_completion_requested)
	code_edit.symbol_hovered.connect(_on_symbol_hovered)
	code_edit.text_changed.connect(_on_code_text_changed)
	function_code_edit.code_completion_enabled = true
	function_code_edit.code_completion_requested.connect(_on_function_completion_requested)


func _on_execution_started(_estimated_command_count: int) -> void:
	_last_runtime_error = ""
	_last_error_line = 0
	_set_execution_buttons(true)
	code_edit.editable = false
	_set_status(
		"Programm gestartet – Laufzeitlimit: %d Schritte." % code_player.max_runtime_commands,
		false
	)


func _on_execution_ended() -> void:
	_set_execution_buttons(false)
	code_edit.editable = true
	if _last_runtime_error.is_empty():
		_clear_line_highlight()
		_set_status("Programm beendet.", false)
	else:
		_highlight_line(_last_error_line, ERROR_LINE_COLOR)
		_set_status(_last_runtime_error, true)


func _on_execution_cancelled() -> void:
	_set_execution_buttons(false)
	code_edit.editable = true
	if _last_runtime_error.is_empty():
		_clear_line_highlight()
		_set_status("Programm abgebrochen.", false)
	else:
		_highlight_line(_last_error_line, ERROR_LINE_COLOR)
		_set_status(_last_runtime_error, true)


func _on_pause_changed(paused: bool) -> void:
	pause_button.text = "Weiter" if paused else "Pause"
	if is_instance_valid(code_player) and code_player.is_running:
		_set_status("Pausiert – Einzelschritt ist aktiv." if paused else "Programm läuft …", false)


func _on_source_line_started(source_line: int, source_text: String) -> void:
	_highlight_line(source_line, EXECUTION_LINE_COLOR)
	_set_status("Zeile %d: %s" % [source_line, source_text], false)


func _on_runtime_error(message: String) -> void:
	_last_runtime_error = message
	var error_line: int = _extract_line_number(message)
	_last_error_line = error_line
	if error_line > 0:
		_highlight_line(error_line, ERROR_LINE_COLOR)
	_set_status(message, true)


func _set_execution_buttons(running: bool) -> void:
	play_button.disabled = running or not is_instance_valid(code_player)
	pause_button.disabled = not running or not is_instance_valid(code_player)
	step_button.disabled = not is_instance_valid(code_player)
	stop_button.disabled = not running or not is_instance_valid(code_player)
	load_example_button.disabled = running
	undo_button.disabled = running
	redo_button.disabled = running
	if not running:
		pause_button.text = "Pause"


func _refresh_function_lists() -> void:
	if not is_instance_valid(item_list) or not is_instance_valid(function_list):
		return
	item_list.clear()
	function_list.clear()
	if not is_instance_valid(function_library):
		return
	var function_names: PackedStringArray = function_library.get_function_names()
	for function_name: String in function_names:
		_add_list_item(function_name, function_name, "Ruft deine Funktion '%s' auf." % function_name)
		function_list.add_item(function_name)
	highlighter.setup_custom_highlighter(code_edit, Strings.current_locale)
	highlighter.apply_function_names(code_edit, function_names)


func _add_list_item(label: String, insert_text: String, description: String) -> void:
	var item_index: int = item_list.item_count
	item_list.add_item(label)
	item_list.set_item_metadata(item_index, insert_text)
	item_list.set_item_tooltip(item_index, description)


func _refresh_examples() -> void:
	example_selector.clear()
	for example: Dictionary in CodeCommandCatalog.get_examples(Strings.current_locale):
		var option_index: int = example_selector.item_count
		example_selector.add_item(String(example.get("name", "Beispiel")))
		example_selector.set_item_metadata(option_index, String(example.get("code", "")))
		example_selector.set_item_tooltip(
			option_index,
			String(example.get("description", "Vollständiges Beispielprogramm"))
		)


func _insert_text(text: String) -> void:
	if not code_edit.editable:
		return
	code_edit.insert_text_at_caret(text + "\n")
	code_edit.grab_focus()


func _on_code_completion_requested() -> void:
	_add_completion_options(code_edit)


func _on_function_completion_requested() -> void:
	_add_completion_options(function_code_edit)


func _add_completion_options(editor: CodeEdit) -> void:
	for entry: Dictionary in CodeCommandCatalog.get_entries(Strings.current_locale):
		var insert_text: String = String(entry.get("insert_text", ""))
		if insert_text == CodeCommandCatalog.FUNCTION_TEMPLATE_ID:
			continue
		editor.add_code_completion_option(
			CodeEdit.KIND_PLAIN_TEXT,
			String(entry.get("trigger", insert_text)),
			insert_text
		)
	if is_instance_valid(function_library):
		for function_name: String in function_library.get_function_names():
			editor.add_code_completion_option(
				CodeEdit.KIND_FUNCTION,
				function_name,
				function_name
			)
	editor.update_code_completion_options(true)


func _on_code_text_changed() -> void:
	if _highlighted_line >= 0 and not (is_instance_valid(code_player) and code_player.is_running):
		_clear_line_highlight()
	code_edit.request_code_completion(false)


func _on_symbol_hovered(symbol: String, _line: int, _column: int) -> void:
	var description: String = CodeCommandCatalog.get_description(symbol, Strings.current_locale)
	if description.is_empty() and is_instance_valid(function_library) \
			and function_library.functions.has(symbol):
		description = "Ruft deine Funktion '%s' auf." % symbol
	command_help_label.text = description if not description.is_empty() else "Befehl auswählen oder mit Strg+Leertaste suchen."


func _highlight_line(source_line: int, color: Color) -> void:
	_clear_line_highlight()
	var line_index: int = source_line - 1
	if line_index < 0 or line_index >= code_edit.get_line_count():
		return
	_highlighted_line = line_index
	code_edit.set_line_background_color(line_index, color)
	code_edit.set_line_as_executing(line_index, color == EXECUTION_LINE_COLOR)
	code_edit.set_caret_line(line_index)
	code_edit.set_caret_column(0)
	code_edit.center_viewport_to_caret()


func _clear_line_highlight() -> void:
	if _highlighted_line >= 0 and _highlighted_line < code_edit.get_line_count():
		code_edit.set_line_background_color(_highlighted_line, Color.TRANSPARENT)
		code_edit.set_line_as_executing(_highlighted_line, false)
	_highlighted_line = -1


func _extract_line_number(message: String) -> int:
	var result: RegExMatch = _line_number_pattern.search(message)
	if result == null:
		return 0
	return int(result.get_string(1))


func _set_status(message: String, is_error: bool) -> void:
	status_label.text = message
	status_label.modulate = Color(1.0, 0.45, 0.45) if is_error else Color.WHITE


func _get_functions() -> Dictionary:
	return function_library.functions if is_instance_valid(function_library) else {}


func _on_exit_button_pressed() -> void:
	function_popup.hide()


func _on_links_button_pressed() -> void:
	_insert_text("links")


func _on_oben_button_pressed() -> void:
	_insert_text("oben")


func _on_rechts_button_pressed() -> void:
	_insert_text("rechts")


func _on_unten_button_pressed() -> void:
	_insert_text("unten")


func _on_attacke_button_pressed() -> void:
	_insert_text("attacke")


func _on_trinke_button_pressed() -> void:
	_insert_text("trinke")


func _on_sage_button_pressed() -> void:
	_insert_text("sage ")


func _on_item_list_item_activated(index: int) -> void:
	var insert_text: String = String(item_list.get_item_metadata(index))
	if insert_text == CodeCommandCatalog.FUNCTION_TEMPLATE_ID:
		_on_create_function_pressed()
		return
	_insert_text(insert_text)


func _on_create_function_pressed() -> void:
	function_popup.popup_centered()
	function_name_input.grab_focus()


func _on_load_function_pressed() -> void:
	function_popup.popup_centered()


func _on_code_delete_button_pressed() -> void:
	if not code_edit.editable:
		return
	code_edit.select_all()
	code_edit.delete_selection()
	_clear_line_highlight()
	_set_status("Editor geleert. Rückgängig ist weiterhin möglich.", false)


func _on_play_button_pressed() -> void:
	if not is_instance_valid(code_player) or not Multihelper.code_player_enabled:
		return
	code_player.play(code_edit.text, _get_functions())


func _on_pause_button_pressed() -> void:
	if not is_instance_valid(code_player) or not code_player.is_running:
		return
	if code_player.is_paused:
		code_player.resume()
	else:
		code_player.pause()


func _on_step_button_pressed() -> void:
	if not is_instance_valid(code_player) or not Multihelper.code_player_enabled:
		return
	if not code_player.is_running:
		code_player.play(code_edit.text, _get_functions(), true)
	if code_player.is_running:
		code_player.step_once()


func _on_stop_button_pressed() -> void:
	if is_instance_valid(code_player):
		code_player.cancel()


func _on_undo_button_pressed() -> void:
	if code_edit.editable and code_edit.has_undo():
		code_edit.undo()


func _on_redo_button_pressed() -> void:
	if code_edit.editable and code_edit.has_redo():
		code_edit.redo()


func _on_load_example_pressed() -> void:
	if not code_edit.editable or example_selector.item_count == 0:
		return
	var example_code: String = String(
		example_selector.get_item_metadata(example_selector.selected)
	)
	_insert_text(example_code)
	_set_status("Beispiel eingefügt – du kannst es direkt verändern.", false)


func _on_create_btn_pressed() -> void:
	if not Multihelper.code_player_enabled or not is_instance_valid(function_library):
		return
	var function_name: String = function_name_input.text.strip_edges()
	if function_name.is_empty():
		_set_status("Die Funktion braucht einen Namen.", true)
		return
	var data: Dictionary = {function_name: function_code_edit.text}
	if function_library.set_func(data):
		function_popup.hide()
		_set_status("Funktion '%s' gespeichert." % function_name, false)


func _on_func_list_item_activated(index: int) -> void:
	if not is_instance_valid(function_library):
		return
	var function_name: String = function_list.get_item_text(index)
	function_name_input.text = function_name
	function_code_edit.text = "\n".join(function_library.get_function_body(function_name))


func _exit_tree() -> void:
	_disconnect_components()
