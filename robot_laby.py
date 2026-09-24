
"""
KI-Campus Reinforcement-Learning-Spiel als Pygame-Version.

Nachbau der Kernmechanik aus der bereitgestellten JavaScript-Datei:
- editierbares Grid mit Tile-IDs 1 (Boden), 2 (Wand), 3 (Ziel)
- Roboter startet unten links
- epsilon-greedy Q-Learning
- alpha=1.0, gamma=1.0, epsilon=0.2
- Reward: normaler Schritt -1, Ziel +50
- Ziel beendet die Episode und setzt den Roboter an den Start zurück
- Run / Turbo / Clear / Reset Map
- Q-Werte und aktuelle greedy Policy können eingeblendet werden

Installation:
    pip install pygame

Start:
    python ki_campus_rl_pygame.py
"""

from __future__ import annotations

import math
import random
import sys
from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple

import pygame


# -----------------------------
# Konfiguration
# -----------------------------

TILE_FLOOR = 1
TILE_WALL = 2
TILE_EXIT = 3

TILE_NAMES = {
    TILE_FLOOR: "Boden",
    TILE_WALL: "Wand",
    TILE_EXIT: "Ziel",
}

# Das konkrete kicampus-basic.json wird in der Web-App extern nachgeladen
# und ist nicht im gepasteten Webpack-Bundle enthalten. Diese 8x8-Karte
# ist deshalb eine editierbare Startkarte im gleichen Stil.
DEFAULT_MAP: List[List[int]] = [
    [1, 1, 1, 1, 1, 1, 1, 3],
    [1, 2, 2, 1, 2, 2, 1, 2],
    [1, 1, 1, 1, 1, 1, 1, 1],
    [2, 2, 1, 2, 2, 1, 2, 1],
    [1, 1, 1, 2, 1, 1, 1, 1],
    [1, 2, 1, 2, 1, 2, 1, 2],
    [1, 2, 1, 1, 1, 2, 1, 1],
    [1, 1, 1, 1, 1, 1, 1, 1],
]

GRID_W = len(DEFAULT_MAP[0])
GRID_H = len(DEFAULT_MAP)

CELL = 72
GRID_X = 28
GRID_Y = 28
PANEL_X = GRID_X + GRID_W * CELL + 28
WINDOW_W = PANEL_X + 315
WINDOW_H = max(GRID_Y * 2 + GRID_H * CELL, 690)

FPS = 60

ALPHA = 1.0
GAMMA = 1.0
EPSILON = 0.2

STEP_REWARD = -1.0
EXIT_REWARD = 50.0

NORMAL_STEP_MS = 165
TURBO_STEP_MS = 22

BG = (245, 247, 250)
GRID_LINE = (35, 39, 47)
FLOOR = (241, 241, 235)
FLOOR_VISITED = (220, 233, 250)
WALL = (86, 92, 102)
EXIT = (102, 194, 116)
START_BORDER = (101, 220, 118)
ROBOT = (49, 100, 210)
ROBOT_INNER = (225, 235, 255)
TEXT = (31, 35, 41)
MUTED = (100, 108, 118)
BUTTON = (225, 229, 236)
BUTTON_ACTIVE = (190, 211, 248)
DANGER = (238, 111, 111)
WHITE = (255, 255, 255)
Q_POS = (42, 133, 76)
Q_NEG = (180, 55, 55)

DIRECTIONS: Dict[str, Tuple[int, int]] = {
    "n": (0, -1),
    "s": (0, 1),
    "e": (1, 0),
    "w": (-1, 0),
}

DIR_LABEL = {"n": "N", "s": "S", "e": "E", "w": "W"}


@dataclass
class Button:
    rect: pygame.Rect
    label: str
    action: str
    toggle: bool = False

    def draw(self, surface: pygame.Surface, font: pygame.font.Font, active: bool = False) -> None:
        color = BUTTON_ACTIVE if active else BUTTON
        pygame.draw.rect(surface, color, self.rect, border_radius=8)
        pygame.draw.rect(surface, GRID_LINE, self.rect, width=2, border_radius=8)
        txt = font.render(self.label, True, TEXT)
        surface.blit(txt, txt.get_rect(center=self.rect.center))


class Maze:
    def __init__(self, cells: List[List[int]]):
        self.original = [row[:] for row in cells]
        self.cells = [row[:] for row in cells]
        self.width = len(cells[0])
        self.height = len(cells)
        self.start = (0, self.height - 1)

    def reset_map(self) -> None:
        self.cells = [row[:] for row in self.original]

    def valid(self, x: int, y: int) -> bool:
        return 0 <= x < self.width and 0 <= y < self.height

    def tile(self, x: int, y: int) -> int:
        return self.cells[y][x]

    def walkable(self, x: int, y: int) -> bool:
        return self.valid(x, y) and self.tile(x, y) != TILE_WALL

    def is_exit(self, x: int, y: int) -> bool:
        return self.valid(x, y) and self.tile(x, y) == TILE_EXIT

    def set_tile(self, x: int, y: int, tile: int) -> bool:
        if not self.valid(x, y):
            return False
        if (x, y) == self.start and tile != TILE_FLOOR:
            return False

        # Nur ein Ziel gleichzeitig, ähnlich einem einfachen Lern-Labyrinth.
        if tile == TILE_EXIT:
            for yy in range(self.height):
                for xx in range(self.width):
                    if self.cells[yy][xx] == TILE_EXIT:
                        self.cells[yy][xx] = TILE_FLOOR

        self.cells[y][x] = tile
        return True


class Robot:
    def __init__(self, maze: Maze):
        self.maze = maze
        self.x, self.y = maze.start
        self.score = 0.0
        self.episodes = 0
        self.steps = 0

    def reset_position(self) -> None:
        self.x, self.y = self.maze.start
        self.score = 0.0

    def available_directions_at(self, x: int, y: int) -> List[str]:
        if self.maze.is_exit(x, y):
            return []
        result = []
        for direction, (dx, dy) in DIRECTIONS.items():
            nx, ny = x + dx, y + dy
            if self.maze.walkable(nx, ny):
                result.append(direction)
        return result

    def available_directions(self) -> List[str]:
        return self.available_directions_at(self.x, self.y)

    def move(self, direction: str) -> Optional[Tuple[int, int, int, int, float, bool]]:
        if direction not in self.available_directions():
            return None

        x1, y1 = self.x, self.y
        dx, dy = DIRECTIONS[direction]
        self.x += dx
        self.y += dy
        self.steps += 1

        reached_exit = self.maze.is_exit(self.x, self.y)
        reward = EXIT_REWARD if reached_exit else STEP_REWARD
        self.score += reward
        return x1, y1, self.x, self.y, reward, reached_exit


class QLearningAI:
    def __init__(self, robot: Robot):
        self.robot = robot
        self.learning_rate = ALPHA
        self.discount_factor = GAMMA
        self.explore_rate = EPSILON
        self.learning = True
        self.clear()

    def clear(self) -> None:
        self.q: List[List[Dict[str, float]]] = [
            [
                {direction: 0.0 for direction in DIRECTIONS}
                for _ in range(self.robot.maze.width)
            ]
            for _ in range(self.robot.maze.height)
        ]
        self.last_reward: List[List[float]] = [
            [0.0 for _ in range(self.robot.maze.width)]
            for _ in range(self.robot.maze.height)
        ]

    def max_q(self, x: int, y: int) -> float:
        dirs = self.robot.available_directions_at(x, y)
        if not dirs:
            return 0.0
        return max(self.q[y][x][d] for d in dirs)

    def greedy_policy_at(self, x: int, y: int) -> Optional[str]:
        """Greedy Policy fuer die KI.

        Bei gleichen Q-Werten wird absichtlich zufaellig entschieden.
        Das entspricht dem Lernverhalten der ursprünglichen JS-Version.
        """
        dirs = self.robot.available_directions_at(x, y)
        if not dirs:
            return None

        best = max(self.q[y][x][d] for d in dirs)
        tied = [d for d in dirs if math.isclose(self.q[y][x][d], best, abs_tol=1e-12)]
        return random.choice(tied)

    def display_policy_at(self, x: int, y: int) -> Optional[str]:
        """Stabile Policy nur fuer die Anzeige.

        Wichtig: Hier KEIN random.choice(). Sonst wird bei gleichen Q-Werten
        in jedem Render-Frame ein anderer Pfeil gezeichnet und die Anzeige
        scheint zu flackern.
        """
        dirs = self.robot.available_directions_at(x, y)
        if not dirs:
            return None

        best = max(self.q[y][x][d] for d in dirs)

        # Stabile Prioritaet fuer Gleichstaende.
        # Die Reihenfolge beeinflusst nur die Anzeige, nicht das Lernen.
        for direction in ("n", "e", "s", "w"):
            if (
                direction in dirs
                and math.isclose(self.q[y][x][direction], best, abs_tol=1e-12)
            ):
                return direction

        return None

    def epsilon_greedy_policy(self) -> Optional[str]:
        dirs = self.robot.available_directions()
        if not dirs:
            return None
        if random.random() >= self.explore_rate:
            return self.greedy_policy_at(self.robot.x, self.robot.y)
        return random.choice(dirs)

    def update(
        self,
        direction: str,
        x1: int,
        y1: int,
        x2: int,
        y2: int,
        reward: float,
    ) -> None:
        old_q = self.q[y1][x1][direction]
        target = reward + self.discount_factor * self.max_q(x2, y2)
        self.q[y1][x1][direction] += self.learning_rate * (target - old_q)
        self.last_reward[y2][x2] = reward

    def step(self) -> bool:
        direction = self.epsilon_greedy_policy()
        if direction is None:
            return False

        result = self.robot.move(direction)
        if result is None:
            return False

        x1, y1, x2, y2, reward, reached_exit = result
        if self.learning:
            self.update(direction, x1, y1, x2, y2, reward)

        if reached_exit:
            self.robot.episodes += 1
            self.robot.reset_position()

        return True


class Game:
    def __init__(self):
        pygame.init()
        pygame.display.set_caption("KI-Campus RL – Pygame-Nachbau")
        self.screen = pygame.display.set_mode((WINDOW_W, WINDOW_H))
        self.clock = pygame.time.Clock()

        self.font = pygame.font.SysFont("arial", 18)
        self.small = pygame.font.SysFont("arial", 14)
        self.tiny = pygame.font.SysFont("arial", 11)
        self.title_font = pygame.font.SysFont("arial", 24, bold=True)

        self.maze = Maze(DEFAULT_MAP)
        self.robot = Robot(self.maze)
        self.ai = QLearningAI(self.robot)

        self.running_ai = False
        self.turbo = False
        self.selected_tile = TILE_FLOOR
        self.show_q = True
        self.show_policy = True
        self.visited = [[False] * self.maze.width for _ in range(self.maze.height)]
        self.visited[self.robot.y][self.robot.x] = True

        self.last_step_at = 0
        self.drag_painting = False

        bx = PANEL_X
        self.buttons = [
            Button(pygame.Rect(bx, 76, 134, 42), "Run", "run", True),
            Button(pygame.Rect(bx + 146, 76, 134, 42), "Turbo", "turbo", True),
            Button(pygame.Rect(bx, 130, 134, 42), "Clear AI", "clear"),
            Button(pygame.Rect(bx + 146, 130, 134, 42), "Reset Map", "reset_map"),
            Button(pygame.Rect(bx, 184, 134, 42), "Q-Werte", "show_q", True),
            Button(pygame.Rect(bx + 146, 184, 134, 42), "Policy", "show_policy", True),
        ]

        self.palette_rects = {
            TILE_FLOOR: pygame.Rect(bx, 292, 86, 60),
            TILE_WALL: pygame.Rect(bx + 97, 292, 86, 60),
            TILE_EXIT: pygame.Rect(bx + 194, 292, 86, 60),
        }

    def clear_ai(self) -> None:
        self.running_ai = False
        self.ai.clear()
        self.robot.reset_position()
        self.robot.episodes = 0
        self.robot.steps = 0
        self.visited = [[False] * self.maze.width for _ in range(self.maze.height)]
        self.visited[self.robot.y][self.robot.x] = True

    def reset_map(self) -> None:
        self.maze.reset_map()
        self.clear_ai()

    def edit_cell_from_mouse(self, pos: Tuple[int, int]) -> None:
        mx, my = pos
        x = (mx - GRID_X) // CELL
        y = (my - GRID_Y) // CELL
        if 0 <= x < self.maze.width and 0 <= y < self.maze.height:
            if self.maze.set_tile(x, y, self.selected_tile):
                self.clear_ai()

    def handle_click(self, pos: Tuple[int, int]) -> None:
        for button in self.buttons:
            if button.rect.collidepoint(pos):
                if button.action == "run":
                    self.running_ai = not self.running_ai
                elif button.action == "turbo":
                    self.turbo = not self.turbo
                elif button.action == "clear":
                    self.clear_ai()
                elif button.action == "reset_map":
                    self.reset_map()
                elif button.action == "show_q":
                    self.show_q = not self.show_q
                elif button.action == "show_policy":
                    self.show_policy = not self.show_policy
                return

        for tile, rect in self.palette_rects.items():
            if rect.collidepoint(pos):
                self.selected_tile = tile
                return

        self.edit_cell_from_mouse(pos)

    def manual_move(self, direction: str) -> None:
        self.running_ai = False
        result = self.robot.move(direction)
        if result is None:
            return
        x1, y1, x2, y2, reward, reached_exit = result
        self.visited[y2][x2] = True
        if self.ai.learning:
            self.ai.update(direction, x1, y1, x2, y2, reward)
        if reached_exit:
            self.robot.episodes += 1
            self.robot.reset_position()
            self.visited[self.robot.y][self.robot.x] = True

    def run_ai_step_if_needed(self) -> None:
        if not self.running_ai:
            return

        now = pygame.time.get_ticks()
        interval = TURBO_STEP_MS if self.turbo else NORMAL_STEP_MS
        if now - self.last_step_at < interval:
            return
        self.last_step_at = now

        old_pos = (self.robot.x, self.robot.y)
        moved = self.ai.step()
        if moved:
            # Falls ein Exit erreicht wurde, ist der Roboter bereits wieder am Start.
            # Das besuchte Zielfeld lässt sich über die Q/Reward-Daten erkennen;
            # wir markieren zumindest Start und aktuelle Position.
            self.visited[old_pos[1]][old_pos[0]] = True
            self.visited[self.robot.y][self.robot.x] = True

    def grid_rect(self, x: int, y: int) -> pygame.Rect:
        return pygame.Rect(GRID_X + x * CELL, GRID_Y + y * CELL, CELL, CELL)

    def draw_arrow(self, center: Tuple[int, int], direction: str, color: Tuple[int, int, int]) -> None:
        cx, cy = center
        dx, dy = DIRECTIONS[direction]
        length = 18
        ex, ey = cx + dx * length, cy + dy * length
        pygame.draw.line(self.screen, color, (cx, cy), (ex, ey), 3)

        # Pfeilspitze
        if direction == "n":
            pts = [(ex, ey), (ex - 5, ey + 8), (ex + 5, ey + 8)]
        elif direction == "s":
            pts = [(ex, ey), (ex - 5, ey - 8), (ex + 5, ey - 8)]
        elif direction == "e":
            pts = [(ex, ey), (ex - 8, ey - 5), (ex - 8, ey + 5)]
        else:
            pts = [(ex, ey), (ex + 8, ey - 5), (ex + 8, ey + 5)]
        pygame.draw.polygon(self.screen, color, pts)

    def draw_grid(self) -> None:
        for y in range(self.maze.height):
            for x in range(self.maze.width):
                rect = self.grid_rect(x, y)
                tile = self.maze.tile(x, y)

                if tile == TILE_WALL:
                    fill = WALL
                elif tile == TILE_EXIT:
                    fill = EXIT
                else:
                    fill = FLOOR_VISITED if self.visited[y][x] else FLOOR

                pygame.draw.rect(self.screen, fill, rect)
                pygame.draw.rect(self.screen, GRID_LINE, rect, width=2)

                if (x, y) == self.maze.start:
                    inner = rect.inflate(-8, -8)
                    pygame.draw.rect(self.screen, START_BORDER, inner, width=5)

                if tile == TILE_EXIT:
                    label = self.font.render("ZIEL", True, WHITE)
                    self.screen.blit(label, label.get_rect(center=rect.center))

                if tile != TILE_WALL and self.show_q:
                    qvals = self.ai.q[y][x]
                    positions = {
                        "n": (rect.centerx, rect.top + 11),
                        "s": (rect.centerx, rect.bottom - 12),
                        "w": (rect.left + 16, rect.centery),
                        "e": (rect.right - 16, rect.centery),
                    }
                    for d in self.robot.available_directions_at(x, y):
                        val = qvals[d]
                        color = Q_POS if val > 0.01 else Q_NEG if val < -0.01 else MUTED
                        txt = self.tiny.render(f"{val:.0f}", True, color)
                        self.screen.blit(txt, txt.get_rect(center=positions[d]))

                if tile != TILE_WALL and self.show_policy and not self.maze.is_exit(x, y):
                    # Fuer die Darstellung die stabile Variante benutzen.
                    # Die echte KI verwendet weiterhin greedy_policy_at() mit
                    # zufaelliger Tie-Break-Entscheidung.
                    direction = self.ai.display_policy_at(x, y)
                    if direction is not None:
                        self.draw_arrow(rect.center, direction, (45, 68, 122))

        # Roboter
        r = self.grid_rect(self.robot.x, self.robot.y)
        center = r.center
        pygame.draw.circle(self.screen, ROBOT, center, 22)
        pygame.draw.circle(self.screen, ROBOT_INNER, center, 12)
        pygame.draw.circle(self.screen, GRID_LINE, center, 22, width=2)

    def draw_panel(self) -> None:
        self.screen.blit(self.title_font.render("Reinforcement Learning", True, TEXT), (PANEL_X, 28))

        for b in self.buttons:
            active = (
                (b.action == "run" and self.running_ai)
                or (b.action == "turbo" and self.turbo)
                or (b.action == "show_q" and self.show_q)
                or (b.action == "show_policy" and self.show_policy)
            )
            b.draw(self.screen, self.font, active)

        y = 246
        self.screen.blit(self.font.render("Map-Editor", True, TEXT), (PANEL_X, y))

        for tile, rect in self.palette_rects.items():
            if tile == TILE_FLOOR:
                fill = FLOOR
            elif tile == TILE_WALL:
                fill = WALL
            else:
                fill = EXIT

            pygame.draw.rect(self.screen, fill, rect, border_radius=7)
            border = ROBOT if tile == self.selected_tile else GRID_LINE
            width = 4 if tile == self.selected_tile else 2
            pygame.draw.rect(self.screen, border, rect, width=width, border_radius=7)

            txt_color = WHITE if tile in (TILE_WALL, TILE_EXIT) else TEXT
            txt = self.small.render(TILE_NAMES[tile], True, txt_color)
            self.screen.blit(txt, txt.get_rect(center=rect.center))

        info_y = 382
        lines = [
            f"epsilon / Exploration: {self.ai.explore_rate:.2f}",
            f"alpha / Lernrate:       {self.ai.learning_rate:.2f}",
            f"gamma / Discount:       {self.ai.discount_factor:.2f}",
            f"Schritte gesamt:        {self.robot.steps}",
            f"Episoden / Ziele:       {self.robot.episodes}",
            f"Aktueller Reward-Score: {self.robot.score:.0f}",
        ]
        for i, line in enumerate(lines):
            self.screen.blit(self.small.render(line, True, TEXT), (PANEL_X, info_y + i * 24))

        help_y = 548
        self.screen.blit(self.font.render("Bedienung", True, TEXT), (PANEL_X, help_y))
        helps = [
            "Maus: Tile auswählen + Feld anklicken/ziehen",
            "Pfeiltasten/WASD: Roboter manuell bewegen",
            "Leertaste: Run an/aus",
            "T: Turbo, C: Clear AI, R: Reset Map",
            "Q: Q-Werte, P: Policy",
        ]
        for i, line in enumerate(helps):
            self.screen.blit(self.small.render(line, True, MUTED), (PANEL_X, help_y + 31 + i * 21))

        note = "Boden = -1 Reward · Ziel = +50 Reward"
        self.screen.blit(self.small.render(note, True, MUTED), (PANEL_X, WINDOW_H - 34))

    def draw(self) -> None:
        self.screen.fill(BG)
        self.draw_grid()
        self.draw_panel()
        pygame.display.flip()

    def loop(self) -> None:
        while True:
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    pygame.quit()
                    sys.exit()

                if event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_ESCAPE:
                        pygame.quit()
                        sys.exit()
                    elif event.key == pygame.K_SPACE:
                        self.running_ai = not self.running_ai
                    elif event.key == pygame.K_t:
                        self.turbo = not self.turbo
                    elif event.key == pygame.K_c:
                        self.clear_ai()
                    elif event.key == pygame.K_r:
                        self.reset_map()
                    elif event.key == pygame.K_q:
                        self.show_q = not self.show_q
                    elif event.key == pygame.K_p:
                        self.show_policy = not self.show_policy
                    elif event.key in (pygame.K_UP, pygame.K_w):
                        self.manual_move("n")
                    elif event.key in (pygame.K_DOWN, pygame.K_s):
                        self.manual_move("s")
                    elif event.key in (pygame.K_LEFT, pygame.K_a):
                        self.manual_move("w")
                    elif event.key in (pygame.K_RIGHT, pygame.K_d):
                        self.manual_move("e")

                elif event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
                    self.drag_painting = True
                    self.handle_click(event.pos)

                elif event.type == pygame.MOUSEBUTTONUP and event.button == 1:
                    self.drag_painting = False

                elif event.type == pygame.MOUSEMOTION and self.drag_painting:
                    # Nur im Grid malen; Buttons sollen beim Ziehen nicht mehrfach feuern.
                    mx, my = event.pos
                    grid_area = pygame.Rect(
                        GRID_X, GRID_Y, self.maze.width * CELL, self.maze.height * CELL
                    )
                    if grid_area.collidepoint(mx, my):
                        self.edit_cell_from_mouse(event.pos)

            self.run_ai_step_if_needed()
            self.draw()
            self.clock.tick(FPS)


if __name__ == "__main__":
    Game().loop()
