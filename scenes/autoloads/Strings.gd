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
const KEYWORD_REPEAT = "wiederhole 3 mal"
const KEYWORD_REPEAT_FULL = "wiederhole 3 mal\n\nende"

# --- Network Commands ---
# Sent from Godot to Python
const CMD_LOAD_FUNCTIONS = "load_functions"
const CMD_PLAY_SEQUENCE = "play_it_now"
const CMD_CREATE_FUNCTION = "create_function"

# Sent from Python to Godot (or used internally)
const CMD_STOP_SEQUENCE = "Stop Sequenz"
const CMD_END_SEQUENCE = "End Sequenz"
