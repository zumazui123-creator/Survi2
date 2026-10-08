extends RefCounted
class_name CodeExpressionEvaluator


func evaluate(
		expression: CodeParser.CodeExpression,
		context: CodeExecutionContext,
		player: CharacterBody2D
	) -> Dictionary:
	if expression == null:
		return _error("Der Ausdruck fehlt.")

	match expression.kind:
		CodeParser.CodeExpression.Kind.LITERAL:
			return _value(expression.literal_value)
		CodeParser.CodeExpression.Kind.VARIABLE:
			return _evaluate_variable(expression.variable_name, context)
		CodeParser.CodeExpression.Kind.BINARY:
			return _evaluate_binary(expression, context, player)
		CodeParser.CodeExpression.Kind.DISTANCE_QUERY:
			return _evaluate_distance(expression.subject, player)
		CodeParser.CodeExpression.Kind.PLAYER_STAT:
			return _evaluate_player_stat(expression.stat_name, player)
	return _error("Unbekannter Ausdruck.")


func _evaluate_variable(variable_name: String, context: CodeExecutionContext) -> Dictionary:
	if context.has_variable(variable_name):
		return _value(context.get_variable(variable_name))
	var suggestion: String = context.find_similar_variable(variable_name)
	var message: String = "Die Variable '%s' existiert nicht." % variable_name
	if not suggestion.is_empty():
		message += " Meintest du '%s'?" % suggestion
	return _error(message)


func _evaluate_binary(
		expression: CodeParser.CodeExpression,
		context: CodeExecutionContext,
		player: CharacterBody2D
	) -> Dictionary:
	var left_result: Dictionary = evaluate(expression.left, context, player)
	if not bool(left_result.get("ok", false)):
		return left_result
	var right_result: Dictionary = evaluate(expression.right, context, player)
	if not bool(right_result.get("ok", false)):
		return right_result

	var left_value: Variant = left_result.get("value")
	var right_value: Variant = right_result.get("value")
	if not _is_number(left_value) or not _is_number(right_value):
		return _error("Für '+' und '-' werden zwei Zahlen benötigt.")

	var both_integers: bool = left_value is int and right_value is int
	if expression.binary_operator == &"add":
		if both_integers:
			return _value(int(left_value) + int(right_value))
		return _value(float(left_value) + float(right_value))
	if expression.binary_operator == &"subtract":
		if both_integers:
			return _value(int(left_value) - int(right_value))
		return _value(float(left_value) - float(right_value))
	return _error("Unbekannter Rechenoperator.")


func _evaluate_distance(subject: StringName, player: CharacterBody2D) -> Dictionary:
	if not is_instance_valid(player):
		return _error("Der Player ist nicht verfügbar.")
	var sensor: PlayerSensor = player.get("sensor") as PlayerSensor
	if not is_instance_valid(sensor):
		return _error("Der Sensor ist nicht verfügbar.")
	var distance_tiles: int = sensor.get_nearest_code_condition_distance(subject)
	if distance_tiles < 0:
		return _error("Im Sensorbereich wurde kein passendes Ziel gefunden.")
	return _value(distance_tiles)


func _evaluate_player_stat(stat_name: StringName, player: CharacterBody2D) -> Dictionary:
	if not is_instance_valid(player):
		return _error("Der Player ist nicht verfügbar.")
	var stats: PlayerStats = player.get("status") as PlayerStats
	if not is_instance_valid(stats):
		return _error("Die Spielerwerte sind nicht verfügbar.")
	match stat_name:
		Strings.PLAYER_STAT_MANA:
			return _value(stats.mana)
		Strings.PLAYER_STAT_HEALTH:
			return _value(stats.hp)
		Strings.PLAYER_STAT_HYDRATION:
			return _value(stats.hydration)
		Strings.PLAYER_STAT_FOOD:
			return _value(stats.food)
	return _error("Unbekannter Spielerwert: %s" % stat_name)


func _is_number(value: Variant) -> bool:
	return value is int or value is float


func _value(value: Variant) -> Dictionary:
	return {"ok": true, "value": value}


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
