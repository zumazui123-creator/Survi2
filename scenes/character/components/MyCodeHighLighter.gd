extends Object
class_name MyCodeHighLighter

func setup_custom_highlighter(code_edit: CodeEdit, locale: String = "de") -> void:
	assert(code_edit != null, "code_edit darf nicht null sein.")

	var highlighter: CodeHighlighter = code_edit.syntax_highlighter
	if highlighter == null:
		push_error("CodeEdit hat keinen syntax_highlighter. Setze zuerst einen CodeHighlighter im Inspector oder via Script.")
		return

	_clear_existing_highlight_rules(highlighter)
	var groups: Dictionary = CodeCommandCatalog.get_highlight_groups(locale)
	_apply_keywords(highlighter, groups.get("movement", []), Color.AQUAMARINE)
	_apply_keywords(highlighter, groups.get("control", []), Color.YELLOW)
	_apply_keywords(highlighter, groups.get("function", []), Color.CHARTREUSE)
	highlighter.add_color_region("#", "", Color(0.45, 0.6, 0.45), true)
	highlighter.add_color_region("\"", "\"", Color(0.95, 0.65, 0.35), false)


func _clear_existing_highlight_rules(highlighter: CodeHighlighter) -> void:
	if highlighter.has_method("clear_keyword_colors"):
		highlighter.clear_keyword_colors()
	if highlighter.has_method("clear_member_keyword_colors"):
		highlighter.clear_member_keyword_colors()
	if highlighter.has_method("clear_color_regions"):
		highlighter.clear_color_regions()
	if highlighter.has_method("clear_highlighting_cache"):
		highlighter.clear_highlighting_cache()
	highlighter.clear_highlighting_cache()
	highlighter.update_cache()


func apply_function_names(code_edit: CodeEdit, function_names: PackedStringArray) -> void:
	var highlighter: CodeHighlighter = code_edit.syntax_highlighter
	if highlighter == null:
		return
	_apply_keywords(highlighter, function_names, Color.CHARTREUSE)
	highlighter.clear_highlighting_cache()
	highlighter.update_cache()


func _apply_keywords(highlighter: CodeHighlighter, keywords: Array, color: Color) -> void:
	var trimmed: String = ""
	for keyword: String in keywords:
		trimmed = keyword.strip_edges()
		if trimmed == "":
			continue
		highlighter.add_keyword_color(trimmed, color)
