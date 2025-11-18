extends Node

# This file centralizes all user-facing and command strings
# to facilitate internationalization and prevent hardcoding.


# --- Player Actions ---
const ACTION_WALK_LEFT = "links"
const ACTION_WALK_RIGHT = "rechts"
const ACTION_WALK_UP = "oben"
const ACTION_WALK_DOWN = "unten"
const ACTION_ATTACK = "attacke"
const ACTION_SAY = "sage"

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

# --- Player Actions (extended) ---
const ACTION_USE_ITEM = "use item"

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
