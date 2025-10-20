import gymnasium as gym
from gymnasium import spaces
import websocket
import threading
import queue
import time
import json
import numpy as np

class GodotEnv(gym.Env):
    metadata = {"render_modes": []}

    def __init__(self, server_url="ws://localhost:8765", timeout=2.0):
        super().__init__()

        # Action-Space (Beispiel: 4 Bewegungen + Attack)
        self.action_space = spaces.Discrete(4)
        self.action_map = {
            0: "walkUp",
            1: "walkDown",
            2: "walkLeft",
            3: "walkRight",
            #4: "attack",
        }

        # Observation-Space (Beispiel: Position x,y)
        self.observation_space = spaces.Box(
            low=np.array([0, 0, 0, 0, 0, 0, 0, 0], dtype=np.float32),
            high=np.array([256, 256, 256, 256, 1, 1, 1, 1], dtype=np.float32),
            dtype=np.float32
        )

        self.server_url = server_url
        self.ws = None
        self.running = False
        self.timeout = timeout

        self.response_queue = queue.Queue()

        self._connect()

    # -------------------
    # Verbindung
    # -------------------
    def _connect(self):
        self.ws = websocket.create_connection(self.server_url)
        self.running = True
        threading.Thread(target=self._receiver_loop, daemon=True).start()
        print(f"✅ Connected to {self.server_url}")

    def _receiver_loop(self):
        while self.running:
            try:
                msg = self.ws.recv()
                if msg:
                    self.response_queue.put(msg)
            except Exception as e:
                print(f"⚠️ Receiver error: {e}")
                break

    def _send_action(self, action: str):
        self.ws.send(action)
        try:
            reply = self.response_queue.get(timeout=self.timeout)
            return reply
        except queue.Empty:
            return None

    # -------------------
    # Gym API
    # -------------------
    def reset(self, seed=None, options=None):
        super().reset(seed=seed)

        # Neustart der Episode im Spiel
        self._send_action("reset")

        # Beispiel: initiale Observation
        obs = [0.0, 0.0, 256, 256, 1, 1, 1, 1]
        info = {}
        return obs, info

    def step(self, action_idx):
        action_str = self.action_map[action_idx]
        reply = self._send_action(action_str)

        obs = [0.0, 0.0, 256, 256, 1, 1, 1, 1]
        reward = 0.0
        terminated = False
        truncated = False
        info = {}

        if reply:
            try:
                data = json.loads(reply)
                obs = data.get("obs", obs)
                reward = data.get("reward", 0.0)
                terminated = False #data.get("done", False)
                info = data.get("status", {})  # hier hast du PlayerStatus
            except Exception:
                pass
        print(f"obs:{obs}, terminated {terminated}")


        return obs, reward, terminated, truncated, info

    def close(self):
        self.running = False
        if self.ws:
            self.ws.close()
            print("❌ Connection closed")
