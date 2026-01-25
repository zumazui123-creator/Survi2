extends Node

# This file centralizes all user-facing and command strings
# to facilitate internationalization and prevent hardcoding.


# --- Player Actions ---
const ACTION_WALK_LEFT  = "walkLeft"
const ACTION_WALK_RIGHT = "walkRight"
const ACTION_WALK_UP    = "walkUp"
const ACTION_WALK_DOWN  = "walkDown"
const ACTION_ATTACK     = "attack"
const ACTION_SAY        = "say"
const ACTION_BUILD      = "build"
const ACTION_PAINT      = "paint"
const ACTION_USE_ITEM   = "use item"

const direction_map = {
	Strings.ACTION_WALK_LEFT: Vector2i.LEFT,
	Strings.ACTION_WALK_RIGHT: Vector2i.RIGHT,
	Strings.ACTION_WALK_UP: Vector2i.UP,
	Strings.ACTION_WALK_DOWN: Vector2i.DOWN
}



const ACTION_NAMES = {
	"de": {
		"links":  ACTION_WALK_LEFT,
		"rechts": ACTION_WALK_RIGHT,
		"oben":   ACTION_WALK_UP,
		"unten":  ACTION_WALK_DOWN,
		"attacke": ACTION_ATTACK,
		"sage":   ACTION_SAY,
		"nutze item" : ACTION_USE_ITEM,
		"baue":   ACTION_BUILD,
		"male":   ACTION_PAINT,
	},
	"en": {
		"left":   ACTION_WALK_LEFT,
		"right":  ACTION_WALK_RIGHT,
		"up":     ACTION_WALK_UP,
		"down":   ACTION_WALK_DOWN,
		"attack": ACTION_ATTACK,
		"speak":  ACTION_SAY,
		"use item" : ACTION_USE_ITEM,
		"build":  ACTION_BUILD,
		"paint":  ACTION_PAINT,
	}
}



# --- Code Keywords ---
const KEYWORD_FUNC = "func"
const KEYWORD_END = "ende"
const KEYWORD_END_FUNC = "end_func"
const KEYWORD_REPEAT = "wiederhole 3 mal"
const KEYWORD_REPEAT_FULL = "wiederhole 3 mal\n\nende"

# --- Network Commands ---
# Sent from Godot to Python
const RPC_METHOD_LOAD_FUNCTIONS = "load_functions"
const RPC_METHOD_CREATE_FUNCTION = "create_function"
const RPC_METHOD_START_KI = "start_ki"
const RPC_METHOD_PLAY_SEQUENCE = "play_sequence"

# Sent from Python to Godot (or used internally)
const CMD_STOP_SEQUENCE = "Stop Sequenz"
const CMD_END_SEQUENCE = "End Sequenz"
const CMD_RESET = "reset"

# --- RPC Result Keys ---
const RPC_RESULT_KEY_FUNCTIONS = "functions"



# --- Animation Names ---
const ANIM_WALKING = "walking"
const ANIM_PUNCHING = "punching"
const ANIM_SWING = "slash"
const ANIM_STAB = "projectile"

# --- Group Names ---
const GROUP_DAMAGEABLE = "damageable"
const GROUP_PLAYER = "player"

# --- Tool Types ---
const TOOL_AXE = "axe"
const TOOL_PICKAXE = "pickaxe"
const TOOL_SWORD = "sword"

# --- Damage Types ---
const DAMAGE_NORMAL = "normal"
const DAMAGE_AXE = "axe"
const DAMAGE_PICKAXE = "pickaxe"
const DAMAGE_MAGIC = "magic"



func remap_code_cmd_to_action(lang:String, code_cmd : String) -> String:
	if code_cmd in Strings.ACTION_NAMES[lang].keys():
		return Strings.ACTION_NAMES[lang][code_cmd];
	return "";
