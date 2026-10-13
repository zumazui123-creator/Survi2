extends RefCounted
class_name FunctionNamePolicy

## Shared naming rules for user-defined CodePlayer functions.
const MINIMUM_NAME_LENGTH: int = 3


static func normalize_name(function_name: String) -> String:
	return function_name.strip_edges().to_lower()


static func get_validation_error(function_name: String) -> String:
	var normalized_name: String = normalize_name(function_name)
	if normalized_name.is_empty():
		return "Die Funktion braucht einen Namen."
	if normalized_name.length() < MINIMUM_NAME_LENGTH:
		return "Der Funktionsname muss mindestens %d Zeichen lang sein." \
			% MINIMUM_NAME_LENGTH
	if not normalized_name.is_valid_unicode_identifier():
		return "Der Name darf Buchstaben, Zahlen, Umlaute und Unterstriche enthalten und nicht mit einer Zahl beginnen."
	if CodeCommandCatalog.is_reserved_symbol(normalized_name):
		return "'%s' ist als Befehl oder Schlüsselwort reserviert." % function_name.strip_edges()
	return ""


static func is_valid_name(function_name: String) -> bool:
	return get_validation_error(function_name).is_empty()
