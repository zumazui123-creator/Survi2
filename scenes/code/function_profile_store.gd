extends RefCounted
class_name FunctionProfileStore

## Local, profile-scoped persistence for user-created CodePlayer functions.
const SAVE_PATH: String = "user://code_player_functions.cfg"
const FORMAT_VERSION: int = 1
const DEFAULT_PROFILE_ID: String = "local_player"


func load_functions(profile_id: String) -> Dictionary:
	var config: ConfigFile = ConfigFile.new()
	var load_error: Error = config.load(SAVE_PATH)
	if load_error == ERR_FILE_NOT_FOUND:
		return {}
	if load_error != OK:
		push_warning(
			"FunctionProfileStore: could not load '%s' (error %d)"
			% [SAVE_PATH, load_error]
		)
		return {}
	var stored_version: int = int(
		config.get_value("metadata", "format_version", FORMAT_VERSION)
	)
	if stored_version > FORMAT_VERSION:
		push_warning(
			"FunctionProfileStore: save format %d is newer than supported format %d"
			% [stored_version, FORMAT_VERSION]
		)
		return {}

	var section: String = _get_profile_section(profile_id)
	var stored_value: Variant = config.get_value(section, "functions", {})
	if not stored_value is Dictionary:
		push_warning(
			"FunctionProfileStore: invalid function data for profile '%s'"
			% normalize_profile_id(profile_id)
		)
		return {}
	return (stored_value as Dictionary).duplicate(true)


func save_functions(profile_id: String, functions: Dictionary) -> bool:
	var config: ConfigFile = ConfigFile.new()
	var load_error: Error = config.load(SAVE_PATH)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		push_warning(
			"FunctionProfileStore: refusing to overwrite unreadable save file '%s' (error %d)"
			% [SAVE_PATH, load_error]
		)
		return false
	if load_error == OK:
		var stored_version: int = int(
			config.get_value("metadata", "format_version", FORMAT_VERSION)
		)
		if stored_version > FORMAT_VERSION:
			push_warning(
				"FunctionProfileStore: refusing to overwrite newer save format %d"
				% stored_version
			)
			return false

	var normalized_profile_id: String = normalize_profile_id(profile_id)
	var section: String = _get_profile_section(normalized_profile_id)
	config.set_value("metadata", "format_version", FORMAT_VERSION)
	config.set_value(section, "profile_id", normalized_profile_id)
	config.set_value(section, "functions", functions.duplicate(true))
	var save_error: Error = config.save(SAVE_PATH)
	if save_error != OK:
		push_warning(
			"FunctionProfileStore: could not save '%s' (error %d)"
			% [SAVE_PATH, save_error]
		)
		return false
	return true


static func normalize_profile_id(profile_id: String) -> String:
	var normalized_id: String = profile_id.strip_edges().to_lower()
	return DEFAULT_PROFILE_ID if normalized_id.is_empty() else normalized_id


static func _get_profile_section(profile_id: String) -> String:
	return "profile_%s" % normalize_profile_id(profile_id).sha256_text()
