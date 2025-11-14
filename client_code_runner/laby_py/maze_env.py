import gymnasium as gym
import numpy as np
from gymnasium import spaces
from labyrinth_generator import LabyrinthGenerator
import os
import random

class MazeEnv(gym.Env):
    """
    Eine benutzerdefinierte Gymnasium-Umgebung für unser Labyrinth.
    """
    metadata = {"render_modes": ["human"], "render_fps": 10}

    def __init__(self, maze_width=37, maze_height=19, render_mode='human'): # Standardgröße erhöht
        super(MazeEnv, self).__init__()

        self.render_mode = render_mode
        self._maze_width = maze_width
        self._maze_height = maze_height

        # Der Generator, der die Labyrinthe erstellt
        self._generator = LabyrinthGenerator(breite=self._maze_width, hoehe=self._maze_height)

        # 4 Aktionen: 0=Hoch, 1=Runter, 2=Links, 3=Rechts
        self.action_space = spaces.Discrete(4)

        # Der Beobachtungsraum ist das Gitter selbst.
        # Wir verwenden einen Kanal (wie bei einem Bild), wie von der CnnPolicy erwartet.
        # Wertebereich 0-255 und uint8 für CnnPolicy
        self.observation_space = spaces.Box(
            low=0, high=255,
            shape=(self._generator.hoehe, self._generator.breite, 1),
            dtype=np.uint8 # Datentyp auf uint8 geändert
        )

        # Mapping von Labyrinth-Symbolen zu numerischen Werten für die KI (im Bereich 0-255)
        self._value_map = {0: 0, 1: 50, 'S': 150, 'G': 255, 'P': 200} # 0=Wand, 50=Weg, 150=Start, 255=Ziel, 200=Player
        self._agent_pos = None
        self._max_steps = self._maze_width * self._maze_height * 2 # Max. Schritte pro Episode

    def _get_obs(self):
        """Erstellt die Beobachtung für das KI-Modell."""
        obs_grid = np.zeros((self._generator.hoehe, self._generator.breite), dtype=np.uint8) # Datentyp angepasst
        for r, row in enumerate(self._generator.labyrinth):
            for c, cell in enumerate(row):
                obs_grid[r, c] = self._value_map.get(cell, 50) # Unbekannte Zellen als Weg behandeln

        # Position des Agenten hinzufügen
        if self._agent_pos:
            obs_grid[self._agent_pos['y'], self._agent_pos['x']] = self._value_map['P']

        # Kanal-Dimension hinzufügen
        return np.expand_dims(obs_grid, axis=-1)

    def reset(self, seed=None, options=None):
        super().reset(seed=seed)
        if seed is not None:
            random.seed(seed)

        # Neues Labyrinth generieren
        self._generator.generieren(seed=seed)

        # Agentenposition auf den Startpunkt setzen
        self._agent_pos = {'x': self._generator.start_x, 'y': self._generator.start_y}
        self._current_step = 0

        observation = self._get_obs()
        info = {'agent_pos': self._agent_pos}

        return observation, info

    def step(self, action):
        # Aktion ausführen
        old_pos = self._agent_pos.copy()
        new_pos = self._agent_pos.copy()

        if action == 0:  # Hoch
            new_pos['y'] -= 1
        elif action == 1:  # Runter
            new_pos['y'] += 1
        elif action == 2:  # Links
            new_pos['x'] -= 1
        elif action == 3:  # Rechts
            new_pos['x'] += 1

        # Distanz vor dem Zug berechnen
        old_dist = abs(old_pos['x'] - self._generator.ziel_x) + abs(old_pos['y'] - self._generator.ziel_y)

        # Prüfen, ob der Zug gültig ist
        target_cell = self._generator.labyrinth[new_pos['y']][new_pos['x']]
        if target_cell == 0:  # Wand getroffen
            reward = -0.1  # Strafe für das Treffen einer Wand
        else:
            self._agent_pos = new_pos
            # Distanz nach dem Zug berechnen
            new_dist = abs(self._agent_pos['x'] - self._generator.ziel_x) + abs(
                self._agent_pos['y'] - self._generator.ziel_y)
            # Belohnung basierend auf der Distanzänderung
            reward = (old_dist - new_dist) * 0.01

        self._current_step += 1

        # Zustand prüfen
        terminated = False
        if self._agent_pos['x'] == self._generator.ziel_x and self._agent_pos['y'] == self._generator.ziel_y:
            reward = 1.0  # Große Belohnung für das Erreichen des Ziels
            terminated = True

        truncated = False
        if self._current_step >= self._max_steps:
            truncated = True

        observation = self._get_obs()
        info = {'agent_pos': self._agent_pos}

        if self.render_mode == "human":
            self.render()

        return observation, reward, terminated, truncated, info

    def render(self):
        """Rendert die Umgebung."""
        # Temporäres Labyrinth für die Darstellung mit Spielerposition
        render_grid = [row[:] for row in self._generator.labyrinth]
        render_grid[self._agent_pos['y']][self._agent_pos['x']] = 'P' # Spieler 'P'

        # Terminal leeren für saubere Animation
        os.system('cls' if os.name == 'nt' else 'clear')

        print(f"Schritt: {self._current_step}")
        for r, row in enumerate(render_grid):
            zeile_str = ""
            for c, cell in enumerate(row):
                zeile_str += {
                    0: "██", 1: "  ", 'S': " S", 'G': " G", 'P': " P"
                }.get(cell, "??")
            print(zeile_str)

    def close(self):
        pass
