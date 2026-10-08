extends RefCounted
class_name CodeExecutionContext

var _variables: Dictionary = {}


func clear() -> void:
	_variables.clear()


func set_variable(variable_name: String, value: Variant) -> void:
	_variables[variable_name.to_lower()] = value


func has_variable(variable_name: String) -> bool:
	return _variables.has(variable_name.to_lower())


func get_variable(variable_name: String) -> Variant:
	return _variables.get(variable_name.to_lower())


func get_variables() -> Dictionary:
	return _variables.duplicate()


func find_similar_variable(variable_name: String) -> String:
	var normalized_name: String = variable_name.to_lower()
	var best_match: String = ""
	var best_similarity: float = 0.0
	for existing_name_value: Variant in _variables.keys():
		var existing_name: String = String(existing_name_value)
		var similarity: float = normalized_name.similarity(existing_name)
		if similarity > best_similarity:
			best_similarity = similarity
			best_match = existing_name
	return best_match if best_similarity >= 0.5 else ""
