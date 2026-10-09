extends Object
class_name MyCodeHighLighter

const TEXT_COLOR: Color = Color(0.92, 0.94, 0.98)
const MOVEMENT_COLOR: Color = Color(0.3, 0.82, 1.0)
const ACTION_COLOR: Color = Color(1.0, 0.55, 0.3)
const CONTROL_COLOR: Color = Color(1.0, 0.82, 0.3)
const CONDITION_COLOR: Color = Color(0.82, 0.58, 1.0)
const VALUE_COLOR: Color = Color(0.4, 0.9, 0.7)
const FUNCTION_COLOR: Color = Color(0.6, 1.0, 0.42)
const VARIABLE_COLOR: Color = Color(0.55, 0.75, 1.0)
const NUMBER_COLOR: Color = Color(0.45, 0.9, 0.55)
const SYMBOL_COLOR: Color = Color.WHITE
const COMMENT_COLOR: Color = Color(0.48, 0.65, 0.5)
const STRING_COLOR: Color = Color(1.0, 0.67, 0.38)


func setup_custom_highlighter(code_edit: CodeEdit, locale: String = "de") -> void:
	assert(code_edit != null, "code_edit darf nicht null sein.")

	var highlighter: CodeHighlighter = code_edit.syntax_highlighter
	if highlighter == null:
		highlighter = CodeHighlighter.new()
		code_edit.syntax_highlighter = highlighter

	_clear_existing_highlight_rules(highlighter)
	highlighter.number_color = NUMBER_COLOR
	highlighter.symbol_color = SYMBOL_COLOR
	var groups: Dictionary = CodeCommandCatalog.get_highlight_groups(locale)
	_apply_keywords(highlighter, groups.get("movement", []), MOVEMENT_COLOR)
	_apply_keywords(highlighter, groups.get("action", []), ACTION_COLOR)
	_apply_keywords(highlighter, groups.get("control", []), CONTROL_COLOR)
	_apply_keywords(highlighter, groups.get("condition", []), CONDITION_COLOR)
	_apply_keywords(highlighter, groups.get("value", []), VALUE_COLOR)
	_apply_keywords(highlighter, groups.get("function", []), FUNCTION_COLOR)
	highlighter.add_color_region("#", "", COMMENT_COLOR, true)
	highlighter.add_color_region("\"", "\"", STRING_COLOR, false)
	_apply_editor_theme(code_edit)


func _clear_existing_highlight_rules(highlighter: CodeHighlighter) -> void:
	if highlighter.has_method("clear_keyword_colors"):
		highlighter.clear_keyword_colors()
	if highlighter.has_method("clear_member_keyword_colors"):
		highlighter.clear_member_keyword_colors()
	if highlighter.has_method("clear_color_regions"):
		highlighter.clear_color_regions()
	if highlighter.has_method("clear_highlighting_cache"):
		highlighter.clear_highlighting_cache()
	highlighter.update_cache()


func apply_document_symbols(
		code_edit: CodeEdit,
		function_names: PackedStringArray,
		variable_names: PackedStringArray
	) -> void:
	var highlighter: CodeHighlighter = code_edit.syntax_highlighter
	if highlighter == null:
		return
	_apply_keywords(highlighter, function_names, FUNCTION_COLOR)
	_apply_keywords(highlighter, variable_names, VARIABLE_COLOR)
	highlighter.clear_highlighting_cache()
	highlighter.update_cache()


func collect_variable_names(sources: Array[String]) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for source: String in sources:
		for source_line: String in source.split("\n"):
			var line_without_comment: String = source_line.get_slice("#", 0).strip_edges()
			if line_without_comment.count("=") == 1:
				var variable_name: String = line_without_comment.get_slice("=", 0).strip_edges().to_lower()
				if _is_valid_identifier(variable_name) and variable_name not in result:
					result.append(variable_name)
			var parts: PackedStringArray = line_without_comment.to_lower().split(" ", false)
			var loop_variable: String = ""
			if parts.size() == 6 and parts[0] in ["für", "for"]:
				loop_variable = parts[1]
			elif parts.size() == 5 and parts[0] in ["für", "for"] \
					and parts[1] in ["jedes", "each"]:
				loop_variable = parts[2]
			if _is_valid_identifier(loop_variable) and loop_variable not in result:
				result.append(loop_variable)
	return result


func _apply_editor_theme(code_edit: CodeEdit) -> void:
	code_edit.add_theme_color_override("font_color", TEXT_COLOR)
	code_edit.add_theme_color_override("font_readonly_color", TEXT_COLOR.darkened(0.15))
	code_edit.add_theme_color_override("font_placeholder_color", TEXT_COLOR.darkened(0.4))
	code_edit.add_theme_color_override("caret_color", Color.WHITE)
	code_edit.add_theme_color_override("selection_color", Color(0.2, 0.45, 0.75, 0.55))
	code_edit.add_theme_color_override("current_line_color", Color(0.16, 0.2, 0.28, 0.65))
	code_edit.add_theme_color_override("line_number_color", Color(0.55, 0.6, 0.7))


func _is_valid_identifier(value: String) -> bool:
	if value.is_empty():
		return false
	var first_character: String = value.substr(0, 1)
	if not "abcdefghijklmnopqrstuvwxyz_".contains(first_character):
		return false
	for character_index: int in range(1, value.length()):
		var character: String = value.substr(character_index, 1)
		if not "abcdefghijklmnopqrstuvwxyz_0123456789".contains(character):
			return false
	return true


func _apply_keywords(highlighter: CodeHighlighter, keywords: Variant, color: Color) -> void:
	for keyword_value: Variant in keywords:
		var keyword: String = String(keyword_value).strip_edges().to_lower()
		if keyword.is_empty():
			continue
		highlighter.add_keyword_color(keyword, color)
