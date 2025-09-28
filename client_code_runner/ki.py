import gymnasium as gym
from gymnasium import spaces
import numpy as np

class MyGameEnv(gym.Env):
    def __init__(self):
        super(MyGameEnv, self).__init__()
        # Beispiel: 4 Beobachtungswerte (x, y, Geschwindigkeit, Score)
        self.observation_space = spaces.Box(low=-np.inf, high=np.inf, shape=(4,), dtype=np.float32)
        # Beispiel: 2 Aktionen (links, rechts, oben, unten, attacke)
        self.action_space = spaces.Discrete(5)
        self.reset()

    def reset(self, seed=None, options=None):
        # Starte dein Spiel neu
        self.state = np.zeros(4, dtype=np.float32)
        return self.state, {}

    def step(self, action):
        # Aktion ins Spiel schicken (z. B. Taste drücken)
        # Spiel updaten → neue state-Werte holen
        self.state = np.random.randn(4).astype(np.float32)  # hier deine Spiellogik einbauen
        reward = 1.0  # z. B. +1 pro überlebten Frame
        terminated = False  # True wenn Game Over
        truncated = False
        return self.state, reward, terminated, truncated, {}

    def render(self):
        # Hier kannst du dein Spiel-Fenster aufrufen
        pass
