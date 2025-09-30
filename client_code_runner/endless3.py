import websocket
import threading
import queue
import time

server_url = "ws://localhost:8765"
ws = None
running = False

# Queue für Antworten
response_queue = queue.Queue()

# -------------------
# Receiver Thread
# -------------------
def receiver_loop():
    global ws, running
    while running:
        try:
            message = ws.recv()
            if not message:
                continue
            print(f"📩 Received: {message}")
            response_queue.put(message)   # Nachricht in Queue ablegen
        except Exception as e:
            print(f"⚠️ Receiver error: {e}")
            break

# -------------------
# Senden von Aktionen
# -------------------
def send_action(action: str, wait_for_reply=True, timeout=2.0):
    """Sende eine Aktion an Godot und warte optional auf Antwort."""
    global ws
    if ws is None:
        raise RuntimeError("Not connected")

    ws.send(action)
    print(f"➡️ Sent: {action}")

    if wait_for_reply:
        try:
            reply = response_queue.get(timeout=timeout)  # blockiert bis Antwort kommt
            print(f"✅ Reply: {reply}")
            return reply
        except queue.Empty:
            print("⏳ Timeout, keine Antwort erhalten")
            return None

# -------------------
# Verbindung starten
# -------------------
def start_client():
    global ws, running
    ws = websocket.create_connection(server_url)
    print(f"✅ Connected to {server_url}")
    running = True
    threading.Thread(target=receiver_loop, daemon=True).start()

def stop_client():
    global ws, running
    running = False
    if ws:
        ws.close()
        print("❌ Connection closed")
