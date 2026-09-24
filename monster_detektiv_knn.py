"""
Monster-Detektiv – kNN Lernspiel
================================

Ein kleines Pygame-Spiel für Kinder (ca. 12 Jahre), das k-Nearest Neighbors
visuell erklärt.

Was man sieht:
- Ein 2D-Diagramm mit Trainingsmonstern als Punkten
- Ein neues Monster als blauen Punkt
- Linien zu den k nächsten Nachbarn
- Eine sortierte Nachbarliste mit Abständen
- Die Abstimmung (Voting), aus der das Resultat entsteht

Installation:
    pip install pygame

Start:
    python monster_detektiv_knn.py
"""

from __future__ import annotations

import math
import random
import sys
from dataclasses import dataclass
from typing import List, Optional, Tuple

import pygame


# ---------------------------------------------------------------------------
# Einstellungen
# ---------------------------------------------------------------------------

WIDTH = 1280
HEIGHT = 820
FPS = 60

BG = (244, 247, 251)
PANEL = (255, 255, 255)
PANEL_ALT = (235, 241, 248)
TEXT = (30, 37, 48)
MUTED = (98, 109, 121)
BORDER = (191, 201, 214)

ACCENT = (63, 108, 211)
ACCENT_LIGHT = (220, 231, 255)

GOOD = (58, 154, 90)
GOOD_LIGHT = (226, 244, 231)
BAD = (201, 72, 72)
BAD_LIGHT = (250, 228, 228)

BLUE_MONSTER = (64, 132, 230)
WHITE = (255, 255, 255)
BLACK = (20, 24, 29)
YELLOW = (244, 190, 66)

POINT_RADIUS = 14


# ---------------------------------------------------------------------------
# Datenmodell
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class Monster:
    name: str
    x: float      # Merkmal 1: Größe
    y: float      # Merkmal 2: Magie
    label: str    # freundlich / gefährlich
    color: str    # nur fuer das Aussehen des Monsters

    def distance_to(self, other: "Monster") -> float:
        return math.dist((self.x, self.y), (other.x, other.y))


def m(name: str, x: float, y: float, label: str, color: str) -> Monster:
    return Monster(name, x, y, label, color)


TRAINING: List[Monster] = [
    m("Momo", 1.8, 2.4, "freundlich", "grün"),
    m("Luna", 2.4, 3.1, "freundlich", "blau"),
    m("Bobo", 3.0, 2.2, "freundlich", "grün"),
    m("Nala", 2.2, 4.0, "freundlich", "blau"),
    m("Pico", 3.7, 2.9, "freundlich", "rot"),
    m("Mini", 1.4, 3.8, "freundlich", "rot"),

    m("Rex", 6.8, 7.0, "gefährlich", "rot"),
    m("Drago", 7.8, 6.3, "gefährlich", "grün"),
    m("Zack", 6.3, 8.0, "gefährlich", "rot"),
    m("Fips", 8.4, 7.6, "gefährlich", "blau"),
    m("Nova", 7.2, 5.6, "gefährlich", "blau"),
    m("Kroko", 5.9, 6.5, "gefährlich", "grün"),
]

TEST_MONSTERS: List[Monster] = [
    m("Trixi", 3.8, 4.7, "freundlich", "grün"),
    m("Rudi", 6.1, 6.1, "gefährlich", "rot"),
    m("Sky", 4.8, 5.0, "gefährlich", "blau"),
    m("Pepper", 2.8, 3.5, "freundlich", "grün"),
    m("Wirbel", 5.4, 6.9, "gefährlich", "rot"),
    m("Keks", 4.0, 3.1, "freundlich", "rot"),
    m("Plopp", 5.0, 4.3, "freundlich", "blau"),
]

X_MIN, X_MAX = 0.0, 10.0
Y_MIN, Y_MAX = 0.0, 10.0


# ---------------------------------------------------------------------------
# UI-Bausteine
# ---------------------------------------------------------------------------

@dataclass
class Button:
    rect: pygame.Rect
    text: str
    action: str
    enabled: bool = True
    active: bool = False

    def draw(self, surface: pygame.Surface, font: pygame.font.Font) -> None:
        if not self.enabled:
            fill = (229, 233, 239)
            border = (203, 209, 217)
            text_color = (141, 150, 161)
        elif self.active:
            fill = ACCENT_LIGHT
            border = ACCENT
            text_color = TEXT
        else:
            fill = PANEL
            border = BORDER
            text_color = TEXT

        pygame.draw.rect(surface, fill, self.rect, border_radius=10)
        pygame.draw.rect(surface, border, self.rect, width=2, border_radius=10)

        img = font.render(self.text, True, text_color)
        surface.blit(img, img.get_rect(center=self.rect.center))


def draw_text(surface, font, text, pos, color=TEXT):
    surface.blit(font.render(text, True, color), pos)


def draw_centered(surface, font, text, center, color=TEXT):
    img = font.render(text, True, color)
    surface.blit(img, img.get_rect(center=center))


def wrap_text(font: pygame.font.Font, text: str, max_width: int) -> List[str]:
    words = text.split()
    lines = []
    line = ""
    for word in words:
        candidate = word if not line else line + " " + word
        if font.size(candidate)[0] <= max_width:
            line = candidate
        else:
            if line:
                lines.append(line)
            line = word
    if line:
        lines.append(line)
    return lines


def draw_wrapped(surface, font, text: str, rect: pygame.Rect, color=TEXT, gap=3):
    y = rect.top
    for line in wrap_text(font, text, rect.width):
        img = font.render(line, True, color)
        surface.blit(img, (rect.left, y))
        y += img.get_height() + gap


# ---------------------------------------------------------------------------
# Monster-Darstellung
# ---------------------------------------------------------------------------

def body_color(name: str) -> Tuple[int, int, int]:
    if name == "grün":
        return (89, 177, 95)
    if name == "blau":
        return (78, 132, 208)
    return (211, 91, 91)


def draw_monster(surface: pygame.Surface, monster: Monster, center: Tuple[int, int], scale: float = 1.0) -> None:
    cx, cy = center
    color = body_color(monster.color)

    body_w = int(76 * scale)
    body_h = int(68 * scale)

    body = pygame.Rect(0, 0, body_w, body_h)
    body.center = (cx, cy)
    pygame.draw.ellipse(surface, color, body)
    pygame.draw.ellipse(surface, BLACK, body, width=max(1, int(2 * scale)))

    # kleine Hörner als Stilmittel
    horn_h = int(18 * scale)
    horn_w = int(10 * scale)
    top = body.top + int(6 * scale)
    left_horn = [(cx - 18, top + horn_h), (cx - 11, top - horn_h // 2), (cx - 4, top + horn_h)]
    right_horn = [(cx + 4, top + horn_h), (cx + 11, top - horn_h // 2), (cx + 18, top + horn_h)]
    pygame.draw.polygon(surface, YELLOW, left_horn)
    pygame.draw.polygon(surface, YELLOW, right_horn)
    pygame.draw.polygon(surface, BLACK, left_horn, width=max(1, int(2 * scale)))
    pygame.draw.polygon(surface, BLACK, right_horn, width=max(1, int(2 * scale)))

    # Augen
    eye_y = cy - int(8 * scale)
    eye_r = max(2, int(4 * scale))
    for ex in (cx - int(12 * scale), cx + int(12 * scale)):
        pygame.draw.circle(surface, WHITE, (ex, eye_y), int(8 * scale))
        pygame.draw.circle(surface, BLACK, (ex, eye_y), eye_r)

    # Mund
    pygame.draw.arc(
        surface,
        BLACK,
        pygame.Rect(cx - int(15 * scale), cy + int(8 * scale), int(30 * scale), int(18 * scale)),
        0.2,
        2.94,
        max(1, int(2 * scale)),
    )


# ---------------------------------------------------------------------------
# kNN-Logik
# ---------------------------------------------------------------------------

class KNNModel:
    def __init__(self, training: List[Monster]):
        self.training = list(training)

    def neighbors(self, query: Monster) -> List[Tuple[Monster, float]]:
        data = [(m, m.distance_to(query)) for m in self.training]
        data.sort(key=lambda pair: pair[1])
        return data

    def predict(self, query: Monster, k: int) -> Tuple[str, List[Tuple[Monster, float]], int, int]:
        ranked = self.neighbors(query)
        nearest = ranked[:k]

        friendly = sum(1 for m, _ in nearest if m.label == "freundlich")
        dangerous = k - friendly

        if dangerous > friendly:
            label = "gefährlich"
        elif friendly > dangerous:
            label = "freundlich"
        else:
            # Gleichstand: nächster Nachbar entscheidet
            label = nearest[0][0].label

        return label, nearest, friendly, dangerous


# ---------------------------------------------------------------------------
# Spiel
# ---------------------------------------------------------------------------

class Game:
    def __init__(self):
        pygame.init()
        pygame.display.set_caption("Monster-Detektiv – kNN")
        self.display = pygame.display.set_mode((WIDTH, HEIGHT), pygame.DOUBLEBUF)
        self.canvas = pygame.Surface((WIDTH, HEIGHT)).convert()
        self.clock = pygame.time.Clock()

        self.font_tiny = pygame.font.SysFont("arial", 13)
        self.font_small = pygame.font.SysFont("arial", 16)
        self.font = pygame.font.SysFont("arial", 19)
        self.font_bold = pygame.font.SysFont("arial", 19, bold=True)
        self.font_big = pygame.font.SysFont("arial", 28, bold=True)
        self.font_huge = pygame.font.SysFont("arial", 40, bold=True)

        self.knn = KNNModel(TRAINING)
        self.k = 3

        self.test_index = 0
        self.current = TEST_MONSTERS[self.test_index]
        self.prediction: Optional[str] = None
        self.nearest: List[Tuple[Monster, float]] = []
        self.vote_friendly = 0
        self.vote_dangerous = 0

        self.score_correct = 0
        self.answered_count = 0
        self.current_counted = False

        self.buttons: List[Button] = []

    # ------------------------------------------------------------------
    # Hilfen
    # ------------------------------------------------------------------

    def plot_rect(self) -> pygame.Rect:
        return pygame.Rect(26, 130, 640, 640)

    def to_screen(self, x: float, y: float) -> Tuple[int, int]:
        r = self.plot_rect()
        px = r.left + 55 + int((x - X_MIN) / (X_MAX - X_MIN) * (r.width - 95))
        py = r.bottom - 50 - int((y - Y_MIN) / (Y_MAX - Y_MIN) * (r.height - 95))
        return px, py

    def build_buttons(self):
        self.buttons = [
            Button(pygame.Rect(715, 218, 50, 42), "−", "k_minus", enabled=self.k > 1),
            Button(pygame.Rect(900, 218, 50, 42), "+", "k_plus", enabled=self.k < 7),
            Button(pygame.Rect(700, 610, 250, 48), "kNN entscheiden", "predict", enabled=self.prediction is None),
            Button(pygame.Rect(700, 670, 250, 48), "Nächstes Monster", "next", enabled=self.prediction is not None),
            Button(pygame.Rect(980, 610, 250, 48), "Zufallsmonster", "random_test"),
            Button(pygame.Rect(980, 670, 250, 48), "Alles zurücksetzen", "reset"),
        ]

    def reset_prediction(self):
        self.prediction = None
        self.nearest = []
        self.vote_friendly = 0
        self.vote_dangerous = 0
        self.current_counted = False

    def next_monster(self):
        self.test_index = (self.test_index + 1) % len(TEST_MONSTERS)
        self.current = TEST_MONSTERS[self.test_index]
        self.reset_prediction()

    def random_monster(self):
        idx = random.randrange(len(TEST_MONSTERS))
        self.test_index = idx
        self.current = TEST_MONSTERS[idx]
        self.reset_prediction()

    def reset_all(self):
        self.k = 3
        self.test_index = 0
        self.current = TEST_MONSTERS[0]
        self.score_correct = 0
        self.answered_count = 0
        self.reset_prediction()

    def do_predict(self):
        if self.prediction is not None:
            return

        pred, nearest, friendly, dangerous = self.knn.predict(self.current, self.k)
        self.prediction = pred
        self.nearest = nearest
        self.vote_friendly = friendly
        self.vote_dangerous = dangerous

        if not self.current_counted:
            self.answered_count += 1
            if self.prediction == self.current.label:
                self.score_correct += 1
            self.current_counted = True

    # ------------------------------------------------------------------
    # Zeichnen
    # ------------------------------------------------------------------

    def draw_header(self):
        pygame.draw.rect(self.canvas, PANEL, pygame.Rect(0, 0, WIDTH, 98))
        pygame.draw.line(self.canvas, BORDER, (0, 97), (WIDTH, 97), 2)

        draw_text(self.canvas, self.font_big, "Monster-Detektiv – kNN", (24, 18))
        subtitle = "So findet k-Nearest Neighbors die nächsten Nachbarn und stimmt danach ab."
        draw_text(self.canvas, self.font, subtitle, (26, 58), MUTED)

    def draw_axes(self):
        r = self.plot_rect()
        pygame.draw.rect(self.canvas, PANEL, r, border_radius=14)
        pygame.draw.rect(self.canvas, BORDER, r, width=2, border_radius=14)

        inner = pygame.Rect(r.left + 55, r.top + 25, r.width - 95, r.height - 75)

        # Gitter
        for i in range(0, 11):
            x = inner.left + int(i / 10 * inner.width)
            y = inner.bottom - int(i / 10 * inner.height)
            pygame.draw.line(self.canvas, (229, 235, 242), (x, inner.top), (x, inner.bottom), 1)
            pygame.draw.line(self.canvas, (229, 235, 242), (inner.left, y), (inner.right, y), 1)

        # Achsen
        pygame.draw.line(self.canvas, TEXT, (inner.left, inner.bottom), (inner.right + 10, inner.bottom), 2)
        pygame.draw.line(self.canvas, TEXT, (inner.left, inner.bottom), (inner.left, inner.top - 10), 2)

        # Ticks
        for i in range(0, 11):
            x = inner.left + int(i / 10 * inner.width)
            y = inner.bottom - int(i / 10 * inner.height)
            pygame.draw.line(self.canvas, TEXT, (x, inner.bottom - 4), (x, inner.bottom + 4), 1)
            pygame.draw.line(self.canvas, TEXT, (inner.left - 4, y), (inner.left + 4, y), 1)

            draw_centered(self.canvas, self.font_tiny, str(i), (x, inner.bottom + 18), MUTED)
            draw_centered(self.canvas, self.font_tiny, str(i), (inner.left - 18, y), MUTED)

        draw_centered(self.canvas, self.font_small, "Größe", (inner.centerx, r.bottom - 18), MUTED)
        label = pygame.font.SysFont("arial", 16)
        text_img = label.render("Magie", True, MUTED)
        text_img = pygame.transform.rotate(text_img, 90)
        self.canvas.blit(text_img, text_img.get_rect(center=(r.left + 17, inner.centery)))

        draw_text(self.canvas, self.font_bold, "Nachbarschafts-Diagramm", (r.left + 18, r.top + 10))

    def draw_point(self, monster: Monster, highlight=False, order: Optional[int] = None):
        pos = self.to_screen(monster.x, monster.y)
        color = GOOD if monster.label == "freundlich" else BAD

        pygame.draw.circle(self.canvas, color, pos, POINT_RADIUS + (3 if highlight else 0))
        pygame.draw.circle(self.canvas, WHITE, pos, POINT_RADIUS - 6 + (1 if highlight else 0))
        pygame.draw.circle(self.canvas, color, pos, POINT_RADIUS + (3 if highlight else 0), width=2)

        if order is not None:
            draw_centered(self.canvas, self.font_tiny, str(order), pos, color)
        else:
            draw_centered(self.canvas, self.font_tiny, monster.name[0], pos, color)

    def draw_plot_content(self):
        self.draw_axes()

        # Trainingsdaten
        for monster in TRAINING:
            self.draw_point(monster)

        # Linien und Highlights
        query_pos = self.to_screen(self.current.x, self.current.y)
        if self.prediction is not None:
            for idx, (monster, dist) in enumerate(self.nearest, start=1):
                pos = self.to_screen(monster.x, monster.y)
                pygame.draw.line(self.canvas, ACCENT, query_pos, pos, 3)
                self.draw_point(monster, highlight=True, order=idx)

            if self.nearest:
                max_dist = max(d for _, d in self.nearest)
                if max_dist > 0:
                    # Kreis um das neue Monster: Radius bis zum k-ten Nachbarn
                    edge_point = self.to_screen(self.current.x + max_dist, self.current.y)
                    radius = abs(edge_point[0] - query_pos[0])
                    pygame.draw.circle(self.canvas, ACCENT, query_pos, radius, width=2)

        # Neues Monster
        pygame.draw.circle(self.canvas, BLUE_MONSTER, query_pos, 17)
        pygame.draw.circle(self.canvas, WHITE, query_pos, 9)
        pygame.draw.circle(self.canvas, BLUE_MONSTER, query_pos, 17, width=2)
        draw_centered(self.canvas, self.font_tiny, "N", query_pos, BLUE_MONSTER)

        # Legende
        legend = pygame.Rect(480, 145, 165, 96)
        pygame.draw.rect(self.canvas, PANEL_ALT, legend, border_radius=10)
        pygame.draw.circle(self.canvas, GOOD, (legend.left + 18, legend.top + 24), 8)
        draw_text(self.canvas, self.font_small, "freundlich", (legend.left + 34, legend.top + 15), TEXT)
        pygame.draw.circle(self.canvas, BAD, (legend.left + 18, legend.top + 50), 8)
        draw_text(self.canvas, self.font_small, "gefährlich", (legend.left + 34, legend.top + 41), TEXT)
        pygame.draw.circle(self.canvas, BLUE_MONSTER, (legend.left + 18, legend.top + 76), 8)
        draw_text(self.canvas, self.font_small, "neues Monster", (legend.left + 34, legend.top + 67), TEXT)

    def draw_control_panel(self):
        panel = pygame.Rect(690, 130, 560, 160)
        pygame.draw.rect(self.canvas, PANEL, panel, border_radius=14)
        pygame.draw.rect(self.canvas, BORDER, panel, width=2, border_radius=14)

        draw_text(self.canvas, self.font_bold, "1. Wähle k", (710, 148))
        draw_text(self.canvas, self.font_small, "k = Anzahl der Nachbarn, die mit abstimmen.", (710, 177), MUTED)

        k_box = pygame.Rect(780, 208, 135, 60)
        pygame.draw.rect(self.canvas, ACCENT_LIGHT, k_box, border_radius=12)
        pygame.draw.rect(self.canvas, ACCENT, k_box, width=2, border_radius=12)
        draw_centered(self.canvas, self.font_huge, str(self.k), k_box.center, ACCENT)

        tip = "Kleinere k-Werte hören stärker auf einzelne Nachbarn. Größere k-Werte betrachten mehr Monster."
        draw_wrapped(self.canvas, self.font_small, tip, pygame.Rect(970, 150, 250, 110), MUTED)

    def draw_current_monster_panel(self):
        panel = pygame.Rect(690, 310, 270, 470)
        pygame.draw.rect(self.canvas, PANEL, panel, border_radius=14)
        pygame.draw.rect(self.canvas, BORDER, panel, width=2, border_radius=14)

        draw_centered(self.canvas, self.font_big, "2. Neues Monster", (panel.centerx, panel.top + 34))
        draw_monster(self.canvas, self.current, (panel.centerx, panel.top + 140), 1.25)
        draw_centered(self.canvas, self.font_big, self.current.name, (panel.centerx, panel.top + 232))

        props = [
            f"Größe: {self.current.x:.1f}",
            f"Magie: {self.current.y:.1f}",
        ]
        y = panel.top + 292
        for prop in props:
            draw_centered(self.canvas, self.font, prop, (panel.centerx, y), TEXT)
            y += 34

        if self.prediction is None:
            info = "Die echte Klasse bleibt erst einmal geheim."
            draw_wrapped(self.canvas, self.font_small, info, pygame.Rect(panel.left + 24, panel.top + 370, panel.width - 48, 70), MUTED)
        else:
            correct = self.prediction == self.current.label
            msg = "Richtig!" if correct else "Nicht ganz!"
            msg_color = GOOD if correct else BAD
            draw_centered(self.canvas, self.font_big, msg, (panel.centerx, panel.top + 382), msg_color)
            draw_centered(self.canvas, self.font_small, f"Richtige Klasse: {self.current.label}", (panel.centerx, panel.top + 418), TEXT)

    def draw_neighbor_list(self):
        panel = pygame.Rect(980, 310, 270, 280)
        pygame.draw.rect(self.canvas, PANEL, panel, border_radius=14)
        pygame.draw.rect(self.canvas, BORDER, panel, width=2, border_radius=14)

        draw_centered(self.canvas, self.font_big, "3. Nächste Nachbarn", (panel.centerx, panel.top + 34))

        if self.prediction is None:
            msg = "Nach dem Klick auf „kNN entscheiden“ werden hier die nächsten Nachbarn sortiert angezeigt."
            draw_wrapped(self.canvas, self.font_small, msg, pygame.Rect(panel.left + 22, panel.top + 90, panel.width - 44, 140), MUTED)
            return

        y = panel.top + 80
        for idx, (monster, dist) in enumerate(self.nearest, start=1):
            row = pygame.Rect(panel.left + 16, y, panel.width - 32, 32)
            fill = GOOD_LIGHT if monster.label == "freundlich" else BAD_LIGHT
            border = GOOD if monster.label == "freundlich" else BAD

            pygame.draw.rect(self.canvas, fill, row, border_radius=8)
            pygame.draw.rect(self.canvas, border, row, width=1, border_radius=8)

            draw_text(self.canvas, self.font_small, f"{idx}. {monster.name}", (row.left + 8, row.top + 7), TEXT)
            draw_text(self.canvas, self.font_tiny, monster.label, (row.left + 105, row.top + 10), border)
            draw_text(self.canvas, self.font_tiny, f"Abstand {dist:.2f}", (row.right - 88, row.top + 10), MUTED)
            y += 38

    def draw_vote_panel(self):
        panel = pygame.Rect(980, 610, 270, 170)
        pygame.draw.rect(self.canvas, PANEL, panel, border_radius=14)
        pygame.draw.rect(self.canvas, BORDER, panel, width=2, border_radius=14)

        draw_centered(self.canvas, self.font_big, "4. Abstimmung", (panel.centerx, panel.top + 30))

        if self.prediction is None:
            msg = "Die k Nachbarn stimmen ab. Die Klasse mit den meisten Stimmen gewinnt."
            draw_wrapped(self.canvas, self.font_small, msg, pygame.Rect(panel.left + 22, panel.top + 65, panel.width - 44, 75), MUTED)
            return

        max_votes = max(self.k, 1)
        bar_w = 150

        # freundlich
        draw_text(self.canvas, self.font_small, "freundlich", (panel.left + 18, panel.top + 72), GOOD)
        pygame.draw.rect(self.canvas, GOOD_LIGHT, pygame.Rect(panel.left + 100, panel.top + 70, bar_w, 20), border_radius=10)
        pygame.draw.rect(self.canvas, GOOD, pygame.Rect(panel.left + 100, panel.top + 70, int(bar_w * self.vote_friendly / max_votes), 20), border_radius=10)
        draw_text(self.canvas, self.font_small, str(self.vote_friendly), (panel.left + 255, panel.top + 70), GOOD)

        # gefährlich
        draw_text(self.canvas, self.font_small, "gefährlich", (panel.left + 18, panel.top + 104), BAD)
        pygame.draw.rect(self.canvas, BAD_LIGHT, pygame.Rect(panel.left + 100, panel.top + 102, bar_w, 20), border_radius=10)
        pygame.draw.rect(self.canvas, BAD, pygame.Rect(panel.left + 100, panel.top + 102, int(bar_w * self.vote_dangerous / max_votes), 20), border_radius=10)
        draw_text(self.canvas, self.font_small, str(self.vote_dangerous), (panel.left + 255, panel.top + 102), BAD)

        result_fill = GOOD_LIGHT if self.prediction == "freundlich" else BAD_LIGHT
        result_color = GOOD if self.prediction == "freundlich" else BAD
        box = pygame.Rect(panel.left + 18, panel.top + 135, panel.width - 36, 24)
        pygame.draw.rect(self.canvas, result_fill, box, border_radius=10)
        pygame.draw.rect(self.canvas, result_color, box, width=1, border_radius=10)
        draw_centered(self.canvas, self.font_small, f"Ergebnis: {self.prediction}", box.center, result_color)

    def draw_score_panel(self):
        box = pygame.Rect(700, 550, 250, 46)
        pygame.draw.rect(self.canvas, PANEL_ALT, box, border_radius=10)

        score_text = f"Richtig: {self.score_correct}/{self.answered_count}" if self.answered_count else "Richtig: –"
        draw_centered(self.canvas, self.font_bold, score_text, box.center, TEXT)

    def draw_explanation_panel(self):
        panel = pygame.Rect(690, 130, 560, 650)
        # not used as global background

        if self.prediction is not None:
            explain = (
                "So arbeitet kNN: Zuerst misst der Algorithmus den Abstand vom "
                "neuen Monster zu allen Trainingsmonstern. Dann sortiert er die "
                f"Abstände und nimmt die {self.k} kleinsten. Diese {self.k} Nachbarn "
                "stimmen ab. Die Mehrheitsklasse wird zum Ergebnis."
            )
        else:
            explain = (
                "Beobachte das Diagramm links: Nach dem Start verbindet das Spiel "
                "das neue Monster mit den k nächsten Punkten. In der Nachbarliste "
                "siehst du die Reihenfolge, und in der Abstimmung siehst du, wie "
                "aus den Stimmen das Ergebnis entsteht."
            )

        draw_wrapped(self.canvas, self.font_small, explain, pygame.Rect(700, 720, 530, 54), MUTED)

    def draw(self):
        self.canvas.fill(BG)
        self.draw_header()
        self.draw_plot_content()
        self.draw_control_panel()
        self.draw_current_monster_panel()
        self.draw_neighbor_list()
        self.draw_vote_panel()
        self.draw_score_panel()
        self.draw_explanation_panel()

        self.build_buttons()
        for button in self.buttons:
            button.draw(self.canvas, self.font)

        self.display.blit(self.canvas, (0, 0))
        pygame.display.flip()

    # ------------------------------------------------------------------
    # Events
    # ------------------------------------------------------------------

    def handle_click(self, pos: Tuple[int, int]):
        self.build_buttons()
        for button in self.buttons:
            if button.rect.collidepoint(pos) and button.enabled:
                if button.action == "k_minus":
                    self.k = max(1, self.k - 1)
                    self.reset_prediction()
                elif button.action == "k_plus":
                    self.k = min(7, self.k + 1)
                    self.reset_prediction()
                elif button.action == "predict":
                    self.do_predict()
                elif button.action == "next":
                    self.next_monster()
                elif button.action == "random_test":
                    self.random_monster()
                elif button.action == "reset":
                    self.reset_all()
                return

    def loop(self):
        while True:
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    pygame.quit()
                    sys.exit()

                elif event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_ESCAPE:
                        pygame.quit()
                        sys.exit()
                    elif event.key in (pygame.K_MINUS, pygame.K_KP_MINUS):
                        self.k = max(1, self.k - 1)
                        self.reset_prediction()
                    elif event.key in (pygame.K_PLUS, pygame.K_KP_PLUS, pygame.K_EQUALS):
                        self.k = min(7, self.k + 1)
                        self.reset_prediction()
                    elif event.key == pygame.K_SPACE:
                        if self.prediction is None:
                            self.do_predict()
                        else:
                            self.next_monster()
                    elif event.key == pygame.K_r:
                        self.reset_all()

                elif event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
                    self.handle_click(event.pos)

            self.draw()
            self.clock.tick(FPS)


if __name__ == "__main__":
    Game().loop()
