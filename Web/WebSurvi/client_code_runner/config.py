import json
import os

# --- Default Configuration ---
DEFAULT_CONFIG = {
    "websocket_url": "ws://localhost:8765",
    "reconnect_delay": 3,
    "connection_timeout": 5,
}

# --- Configuration Loading ---
_config = DEFAULT_CONFIG.copy()

_config_path = os.path.join(os.path.dirname(__file__), "config.json")

try:
    if os.path.exists(_config_path):
        with open(_config_path, "r") as f:
            _loaded_config = json.load(f)
            _config.update(_loaded_config)
            print(f"✅ Configuration loaded from {_config_path}")
    else:
        print(f"ℹ️ No config file found at {_config_path}. Using default settings.")
except (json.JSONDecodeError, IOError) as e:
    print(f"⚠️ Error loading config file: {e}. Using default settings.")

# --- Exported Configuration Values ---
WEBSOCKET_URL = _config["websocket_url"]
RECONNECT_DELAY = _config["reconnect_delay"]
CONNECTION_TIMEOUT = _config["connection_timeout"]
