from numpy import add
import websocket
import threading
import tkinter as tk
import queue
import gymnasium as gym
from stable_baselines3 import PPO
from stable_baselines3.common.callbacks import BaseCallback
import torch
import torch as th
import torch.nn as nn
import matplotlib.pyplot as plt
import networkx as nx

from myconverter.parser import Parser
from ki import GodotEnv
from ki import StepLogger
from ki import init_model
conv_action = Parser()

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
running = False


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
            message = ws.recv()   # blockiert, bis was kommt
            if not message:
                continue

            log(f"📩 Received: {message}")

            converted_msg = conv_action.parse(message)
            log(f"🔄 Converted message: {converted_msg}")

            if "start ki" in message:
            	print("Start Ki")
            	init_model()


            if "play_it_now" in message:
                for msg in converted_msg:
                    payload = msg #f"{msg[0]} , {msg[1]}"
                    ws.send(payload)
                    log(f"➡️ Sent action: {payload}")

                    # warte auf Antwort BEVOR die nächste Aktion gesendet wird
                    reply = ws.recv()
                    log(f"✅ Received reply: {reply}")

                    if "Stop Sequenz" in reply:
                    	break

                ws.send("End Sequenz")
                reply = ws.recv()
                log(f"✅ Received End reply: {reply}")

        except Exception as e:
            log(f"⚠️ Error in receiver loop: {e}")
            break

# --- Buttons ---
def start_client():
    global ws, receiver_thread, running
    try:
        ws = websocket.create_connection(server_url)
        log(f"✅ Connected to {server_url}")
        running = True
        receiver_thread = threading.Thread(target=receiver_loop, daemon=True)
        receiver_thread.start()
    except Exception as e:
        log(f"⚠️ Connection error: {e}")

def stop_client():
    global ws, running
    running = False
    try:
        if ws:
            ws.close()
            log("❌ Connection closed")
    except Exception:
        pass

start_btn = tk.Button(button_frame, text="Start", command=start_client, bg="lightgreen")
start_btn.pack(side="left", padx=10)

stop_btn = tk.Button(button_frame, text="Stop", command=stop_client, bg="lightcoral")
stop_btn.pack(side="left", padx=10)

exit_btn = tk.Button(button_frame, text="Exit", command=root.destroy)
exit_btn.pack(side="right", padx=10)

# --- Tkinter Loop ---
root.mainloop()
