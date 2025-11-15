extends Object
class_name MyCodeHighLighter

# ------------------------------
# Keyword-Gruppen
# ------------------------------
const MOVEMENT_KEYWORDS := [
	"oben", "rechts", "unten", "links", "attacke", "sage"
]

const LOOP_KEYWORDS := [
	"wiederhole", "mal", "ende"
]

const END_KEYWORDS := [
	
]

# Farbe für Zahlen
const NUMBER_COLOR := Color(1.0, 0.5, 0.0) # Orange
# ------------------------------
# Public API
# ------------------------------
func setup_custom_highlighter(code_edit: CodeEdit) -> void:
	assert(code_edit != null, "code_edit darf nicht null sein.")

	var highlighter = code_edit.syntax_highlighter
	if highlighter == null:
		push_error("CodeEdit hat keinen syntax_highlighter. Setze zuerst einen CodeHighlighter im Inspector oder via Script.")
		return

	_clear_existing_highlight_rules(highlighter)
	_apply_keywords(highlighter, MOVEMENT_KEYWORDS, Color.AQUAMARINE)
	_apply_keywords(highlighter, LOOP_KEYWORDS, Color.YELLOW)
	_apply_keywords(highlighter, END_KEYWORDS, Color.RED)
	


# ------------------------------
# Private helpers
# ------------------------------
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

func _apply_keywords(highlighter: CodeHighlighter, keywords: Array, color: Color) -> void:
	var trimmed = ""
	for keyword in keywords:
		trimmed = keyword.strip_edges()
		if trimmed == "":
			continue
		highlighter.add_keyword_color(trimmed, color)
