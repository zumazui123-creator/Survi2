

Asking:
Shadow-Clone for simulating ?

Möglich:
- Tower u. Hero defense 

TODO:
- ad stop flag
- implement "function erstellen"
- easy and ahrd mode for laby
- food und water aufüllen

- Animals:
    - Hasen die weg laufen -> abgabe
    - Pig 

- Eine Task Menu (oben links):
    - Task generate Kekse die man ohne zu viel schritte einsammeln muss:
        - level 2 mint wenig codezeilen als bei level 1


- Funktionen:
  - weg frei
  - wennn weg frei dann links sonst rechts 

Labyrinth:
  - Labyrinth Level richtig einornden entweder mit int oder string
  - evtl kleine Rätsel einbauen
  - zeitliche Fallen ähnlich wie bei Tomb raider z.B.: Tiles mit Stacheln
  - Learning:
    - merken und lernen von coden
    - einen Algo. bauen, der meisten zum Ziel führt

Power Ups:
  - Oben recht  zwischen zeit und AufgabenUI kann man wie bei Lineage Power ups icon reinbauen.

- Konstruiere Mauern und Türme mit einem Code einzigen Code durchlaufen

KI:
  - Umbauen Py script und Godot: wie gpt umsetzten ... main pc arbeiten
  - UI links Player Character und recht Code-UI
  - UI so implementieren das
    - bei paar Buttons oder eingetippen Code, viel optisches "passiert" sagen wir ähnlich wie bei "pacman -S vim"
      - KI wird initialsiert, Spiel Umgebung wird Eingeladen etc.
  - BelohnungsSystem und StrafSys: drag and drop von yellow and red button to a slot or tile??

Beim Realease:
  - dayNight speed 20
  - move speed


import websocket
import threading
import tkinter as tk
import time

# --- GUI Setup ---
root = tk.Tk()
root.title("Godot WebSocket Client")
root.geometry("500x500")

log_box = tk.Text(root, state="disabled", wrap="word", height=20)
log_box.pack(expand=True, fill="both", padx=5, pady=5)

button_frame = tk.Frame(root)
button_frame.pack(fill="x", pady=5)

# --- Globals ---
server_url = "ws://localhost:8765"
ws = None
receiver_thread = None
reconnect_thread = None
running = False
should_reconnect = False


def log(msg: str):
    log_box.config(state="normal")
    log_box.insert("end", msg + "\n")
    log_box.see("end")
    log_box.config(state="disabled")


# --- Receiver Loop ---
def receiver_loop():
    global ws, running
    while running:
        try:
            message = ws.recv()
            if not message:
                continue
            log(f"📩 Received: {message}")
        except Exception as e:
            log(f"⚠️ Receiver error: {e}")
            running = False
            break


# --- Reconnect Loop ---
def reconnect_loop():
    global ws, running, should_reconnect
    while should_reconnect:
        if not running:
            try:
                log("🔄 Trying to connect...")
                ws = websocket.create_connection(server_url, timeout=5)
                log(f"✅ Connected to {server_url}")
                running = True
                # Startet den Empfangs-Thread
                threading.Thread(target=receiver_loop, daemon=True).start()
            except Exception as e:
                log(f"⚠️ Connection failed: {e}")
        time.sleep(5)  # 5 Sekunden warten, dann erneut versuchen


# --- Buttons ---
def start_client():
    global reconnect_thread, should_reconnect
    if reconnect_thread is None or not reconnect_thread.is_alive():
        should_reconnect = True
        reconnect_thread = threading.Thread(target=reconnect_loop, daemon=True)
        reconnect_thread.start()
        log("🚀 Auto-Reconnect gestartet")


def stop_client():
    global ws, running, should_reconnect
    should_reconnect = False
    running = False
    try:
        if ws:
            ws.close()
            log("❌ Connection closed")
    except Exception as e:
        log(f"⚠️ Error while closing: {e}")


start_btn = tk.Button(button_frame, text="Start", command=start_client, bg="lightgreen")
start_btn.pack(side="left", padx=10)

stop_btn = tk.Button(button_frame, text="Stop", command=stop_client, bg="lightcoral")
stop_btn.pack(side="left", padx=10)

exit_btn = tk.Button(button_frame, text="Exit", command=root.destroy)
exit_btn.pack(side="right", padx=10)

# --- Tkinter Loop ---
root.mainloop()
