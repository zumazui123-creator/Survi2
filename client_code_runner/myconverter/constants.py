# This file centralizes all keywords and command strings used in the Python client.

# --- Language Keywords ---
KEYWORD_END = "ende"
KEYWORD_FUNC = "func"
KEYWORD_REPEAT = "wiederhole"

# --- Player Actions ---
ACTION_WALK_LEFT = "links"
ACTION_WALK_RIGHT = "rechts"
ACTION_WALK_UP_1 = "hoch"
ACTION_WALK_UP_2 = "oben"
ACTION_WALK_DOWN_1 = "runter"
ACTION_WALK_DOWN_2 = "unten"
ACTION_ATTACK = "attacke"
ACTION_SAY = "sage"
ACTION_GO_BACK = "gehe zurück"
ACTION_USE_ITEM = "nutze item"

# --- Mapped Actions (for translation) ---
MAPPED_WALK_LEFT = "walkLeft"
MAPPED_WALK_RIGHT = "walkRight"
MAPPED_WALK_UP = "walkUp"
MAPPED_WALK_DOWN = "walkDown"
MAPPED_ATTACK = "leftClickAction"
MAPPED_USE_ITEM = "use item "

# --- Network Commands ---
# Received from Godot
CMD_LOAD_FUNCTIONS = "load_functions"
CMD_PLAY_SEQUENCE = "play_it_now"
CMD_CREATE_FUNCTION = "create_function"
CMD_START_KI = "start ki"

# Sent to Godot (or used internally)
CMD_STOP_SEQUENCE = "Stop Sequenz"
CMD_END_SEQUENCE = "End Sequenz"
