import tkinter as tk
from tkinter import scrolledtext, messagebox
import threading
import sys
import io
import time
import asyncio
import websocket
import json

def on_open(ws):
    print("Connected! Sending message...")
    ws.send("Hello from Python!")  # Send immediately on connection
    ws.send("links")  # Example command for movement

def on_message(ws, message):
    print("Received from Godot:", message)

ws = websocket.WebSocketApp(
    "ws://localhost:8765",
    on_open=on_open,
    on_message=on_message
)
ws.run_forever()