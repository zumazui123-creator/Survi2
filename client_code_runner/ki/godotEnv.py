
from typing import override
import gymnasium as gym
from gymnasium import spaces
import websocket
import threading
import queue
import time
import json
import numpy as np
from collections import defaultdict

class GodotEnv(gym.Env):
    metadata = {"render_modes": []}

    def get_null_obs(self):
        return np.array([0, 0, 0, 0, -1, -1, 0, 0, 0, 0], dtype=np.float32)


    def get_endgoal_obs(self):
        return np.array([0, 0, 0, 0, 1, 1, 0, 0, 0, 0], dtype=np.float32)


    def __init__(self, server_url="ws://localhost:8765", timeout=2.0):
        super().__init__()

        # Action-Space als Box für SAC kompatibel
        # self.action_space = spaces.Box(low=np.array([0.0]), high=np.array([3.0]), dtype=np.float32)
        self.action_space = spaces.Discrete(4)

        self.action_map = {
            0: "walkUp",
            1: "walkDown",
            2: "walkLeft",
            3: "walkRight",
            #4: "attack",
        }

        # Observation-Space
        # self.observation_space = spaces.Dict({
        #     "observation": spaces.Box(low=np.array([0,0,0,0,0,0,0,0]), high=np.array([256,256,256,256,1,1,1,1]), dtype=np.float32),
        #     "achieved_goal": spaces.Box(low=np.array([0,0]), high=np.array([256,256]), dtype=np.float32),
        #     "desired_goal": spaces.Box(low=np.array([0,0]), high=np.array([256,256]), dtype=np.float32)
        # })

        # self.observation_space = spaces.Box(
        #     low=np.array([0, 0, 0, 0, 0, 0, 0, 0], dtype=np.float32),
        #     high=np.array([256, 256, 256, 256, 1, 1, 1, 1], dtype=np.float32),
        # )

        self.observation_space = spaces.Box(
                    low=np.array([0, 0, 0, 0, -1, -1, 0, 0, 0, 0], dtype=np.float32),
                    high=np.array([1, 1, 1, 1, 1, 1, 1, 1, 1, 1], dtype=np.float32),
                )

        # self.observation_space = spaces.Box(
        #     low=np.array([ 0, 0, 0, 0], dtype=np.int32),
        #     high=np.array([ 1, 1, 1, 1], dtype=np.int32),
        # )

        self.server_url = server_url
        self.ws = None
        self.running = False
        self.timeout = timeout
        self.response_queue = queue.Queue()

        # self.visited_ways = set()
        self.visited_ways = defaultdict(int)



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
            # print(f"ws reply:{action}")
            return reply
        except queue.Empty:
            return None

    # -------------------
    # Gym API
    # -------------------
    def reset(self, seed=None, options=None):
        super().reset(seed=seed)
        self._send_action("reset")
        obs = self.get_null_obs()
        info = {}
        # self.visited_ways = set()
        self.visited_ways = defaultdict(int)

        return obs, info

    def _build_observation(self, obs_list, info,):

        player_position = list(info["tile_position"])
        goal_position   = obs_list["goal"]
        free_directions = obs_list["free_directions"]

        player = np.array(player_position, dtype=np.float32)
        goal   = np.array(goal_position, dtype=np.float32)
        free   = np.array(free_directions, dtype=np.float32)

        # Normalisiere Positionen (0–256 → 0–1)
        player_norm = player / 256.0
        goal_norm   = goal / 256.0

        # Relative Distanz
        rel = abs(goal - player) / 256.0  # Wertebereich ca. [-1, +1]
        distants = np.linalg.norm(goal - player) / 256.0
        print(f"distants: {distants}")
        print(f"player_position: {player_position}")

        # Baue Observation zusammen
        obs = np.concatenate([player_norm, goal_norm, rel, free])

        # calc reward
        reward = 0.0

        # visited_move
        pos = tuple(player)
        self.visited_ways[pos] += 1  # Zählt Besuche

        # Bestrafung je häufiger der Agent das Feld besucht
        visits = self.visited_ways[pos]
        if visits > 1:
            reward -= 0.25 * (visits - 1)  # -0.25, -0.5, -0.75, ...

        # self.visited_ways.add(tuple(player))
        # if tuple(player) in self.visited_ways:
        #    reward -= 0.55

        if distants > 0:
            reward += 1 / distants
        else:
            reward += 10  # e.g. bonus for reaching the goal


        return obs, reward

    @override
    def step(self, action):
        print(f"action:{action}")
        action_str = self.action_map[action]

        reply = self._send_action(action_str)
        obs = self.get_null_obs()


        reward = 0.0
        terminated = False
        truncated = False
        info = {}
        obs_list = {}

        if reply:
            # print(f"reply:{reply}")
            try:
                data = json.loads(reply)
                obs_list = data.get("obs", None)
                reward = data.get("reward", 0.0)
                terminated = data.get("done", False)
                info = data.get("status", {})
            except Exception:
                pass
        if obs_list is not None:
            obs, reward2 = self._build_observation(obs_list=obs_list, info=info)
            reward += reward2


            # obs = np.array(obs_list, dtype=np.int32)
        # if obs.shape !=  obs_shape:
        #     terminated = True
        #     obs = np.array(info['tile_position'], dtype=np.int32)

        print(f"obs shape:{obs.shape} obs:{obs}, terminated {terminated}, info: {info["tile_position"]}")

        if terminated:
            reward += 10
            self.reset()

        return obs, reward, terminated, truncated, info

    def close(self):
        self.running = False
        if self.ws:
            self.ws.close()
            print("❌ Connection closed")
