import json
import websocket
import time
import threading
import tkinter as tk
from myconverter.parser import Parser 

conv_action = Parser()

# --- GUI Setup ---
root = tk.Tk()
root.title("Godot WebSocket Client")
root.geometry("500x400")

log_box = tk.Text(root, state="disabled", wrap="word", height=20)
log_box.pack(expand=True, fill="both", padx=5, pady=5)

button_frame = tk.Frame(root)
button_frame.pack(fill="x", pady=5)

# --- Globals ---
ws_app = None
ws_thread = None
connected = False
server_url = "ws://localhost:8765"

def log(msg: str):
    log_box.config(state="normal")
    log_box.insert("end", msg + "\n")
    log_box.see("end")
    log_box.config(state="disabled")

# --- WebSocket Callbacks ---
def on_message(ws, message):
    log(f"Observation from Godot: {message}")
    converted_msg = conv_action.parse(message)
    log(f"Converted message: {converted_msg}")
    if "play_it_now" in message:
        for msg in converted_msg:
            ws.send(f"{msg[0]} , {msg[1]}")
            
            # time.sleep(1.2)
        log(f"Sent action: {converted_msg}")

def on_open(ws):
    global connected
    connected = True
    ws.send(json.dumps("walkLeft, 1"))
    log("✅ Connected to server, sent initial action")

def on_close(ws, close_status_code, close_msg):
    global connected
    connected = False
    log("❌ Disconnected from server")

def on_error(ws, error):
    log(f"⚠️ Error: {error}")

# --- Connect / Reconnect Logic ---
def start_ws():
    global ws_app, ws_thread
    ws_app = websocket.WebSocketApp(
        server_url,
        on_message=on_message,
        on_open=on_open,
        on_close=on_close,
        on_error=on_error
    )
    ws_thread = threading.Thread(target=ws_app.run_forever, daemon=True)
    ws_thread.start()
    log("🔄 Trying to connect...")

def reconnect():
    global ws_app, connected
    if ws_app:
        try:
            ws_app.close()
        except Exception:
            pass
    connected = False
    log("🔁 Reconnecting...")
    start_ws()

# --- Buttons ---
reconnect_btn = tk.Button(button_frame, text="Reconnect", command=reconnect)
reconnect_btn.pack(side="left", padx=10)

exit_btn = tk.Button(button_frame, text="Exit", command=root.destroy)
exit_btn.pack(side="right", padx=10)

# --- Start First Connection ---
start_ws()

# --- Tkinter Loop ---
root.mainloop()
