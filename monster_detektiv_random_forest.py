from __future__ import annotations

import math
import random
import sys
from dataclasses import dataclass
from typing import Dict, List, Optional, Sequence, Set, Tuple

import pygame


# ============================================================
# Monster-Detektiv: Decision Tree + Random Forest
# Für ca. 12-jährige Kinder
# ============================================================

WIDTH, HEIGHT, FPS = 1280, 820, 60

BG = (244, 247, 251)
PANEL = (255, 255, 255)
PANEL_ALT = (235, 241, 248)
TEXT = (30, 37, 48)
MUTED = (96, 108, 124)
BORDER = (190, 200, 214)
ACCENT = (60, 105, 210)
ACCENT_LIGHT = (220, 231, 255)
GOOD = (61, 154, 88)
GOOD_LIGHT = (224, 244, 230)
BAD = (202, 74, 74)
BAD_LIGHT = (251, 227, 227)
WHITE = (255, 255, 255)
BLACK = (20, 24, 29)
YELLOW = (244, 190, 66)
TREE_GREEN = (74, 145, 82)
TREE_TRUNK = (125, 88, 55)

COLORS = {
    "grün": (89, 177, 95),
    "blau": (78, 132, 208),
    "rot": (211, 91, 91),
}


@dataclass(frozen=True)
class Monster:
    name: str
    color: str
    horns: bool
    wings: bool
    big: bool
    label: str


def make_monster(name: str, color: str, horns: bool, wings: bool, big: bool) -> Monster:
    # Bewusst einfache geheime Regel für das Lernspiel:
    # Hörner ODER Flügel => gefährlich.
    label = "gefährlich" if horns or wings else "freundlich"
    return Monster(name, color, horns, wings, big, label)


TRAINING: List[Monster] = [
    make_monster("Momo", "grün", False, False, False),
    make_monster("Rex", "rot", True, False, True),
    make_monster("Luna", "blau", False, True, False),
    make_monster("Bobo", "grün", False, False, True),
    make_monster("Zack", "rot", True, True, False),
    make_monster("Mila", "blau", False, False, False),
    make_monster("Kroko", "grün", True, False, False),
    make_monster("Fips", "rot", False, True, True),
    make_monster("Nala", "blau", False, False, True),
    make_monster("Drago", "grün", True, True, True),
    make_monster("Pico", "rot", False, False, False),
    make_monster("Wuschel", "blau", True, False, False),
]

TEST_DATA: List[Monster] = [
    make_monster("Trixi", "grün", False, True, True),
    make_monster("Keks", "rot", False, False, True),
    make_monster("Nova", "blau", True, False, True),
    make_monster("Plopp", "grün", False, False, False),
    make_monster("Rudi", "rot", True, True, True),
    make_monster("Sky", "blau", False, True, False),
    make_monster("Pepper", "grün", True, False, False),
    make_monster("Mini", "rot", False, False, False),
]

FEATURE_LABELS: Dict[str, str] = {
    "horns": "Hat Hörner?",
    "wings": "Hat Flügel?",
    "big": "Ist es groß?",
    "green": "Ist es grün?",
}
FEATURE_SHORT: Dict[str, str] = {
    "horns": "Hörner",
    "wings": "Flügel",
    "big": "Größe",
    "green": "Grün",
}
FEATURES = list(FEATURE_LABELS)


def feature_value(monster: Monster, feature: str) -> bool:
    if feature == "horns":
        return monster.horns
    if feature == "wings":
        return monster.wings
    if feature == "big":
        return monster.big
    if feature == "green":
        return monster.color == "grün"
    raise ValueError(feature)


@dataclass
class Button:
    rect: pygame.Rect
    text: str
    action: str
    value: Optional[str] = None
    enabled: bool = True
    active: bool = False

    def draw(self, surface: pygame.Surface, font: pygame.font.Font, small: pygame.font.Font) -> None:
        if not self.enabled:
            fill, border, color = (229, 233, 239), (203, 209, 217), (142, 150, 162)
        elif self.active:
            fill, border, color = ACCENT_LIGHT, ACCENT, TEXT
        else:
            fill, border, color = PANEL, BORDER, TEXT

        pygame.draw.rect(surface, fill, self.rect, border_radius=10)
        pygame.draw.rect(surface, border, self.rect, width=2, border_radius=10)
        f = small if len(self.text) > 20 else font
        img = f.render(self.text, True, color)
        surface.blit(img, img.get_rect(center=self.rect.center))


class DecisionTree:
    """Kleiner, bewusst überschaubarer Entscheidungsbaum.

    - eine Wurzelfrage
    - optional eine zweite Frage im JA-Zweig
    - optional eine zweite Frage im NEIN-Zweig
    - Blattklasse = Mehrheitsklasse der Trainingsbeispiele im Blatt
    """

    def __init__(
        self,
        data: Sequence[Monster],
        root: str,
        yes_child: Optional[str],
        no_child: Optional[str],
    ) -> None:
        self.data = list(data)
        self.root = root
        self.yes_child = yes_child
        self.no_child = no_child

    @staticmethod
    def majority(items: Sequence[Monster], fallback: str = "freundlich") -> str:
        if not items:
            return fallback
        dangerous = sum(m.label == "gefährlich" for m in items)
        friendly = len(items) - dangerous
        # Bei Gleichstand bewusst freundlich. So bleibt die Regel deterministisch.
        return "gefährlich" if dangerous > friendly else "freundlich"

    def root_group(self, answer: bool) -> List[Monster]:
        return [m for m in self.data if feature_value(m, self.root) == answer]

    def leaf_label(
        self,
        root_answer: bool,
        child: Optional[str],
        child_answer: Optional[bool],
    ) -> str:
        group = self.root_group(root_answer)
        fallback = self.majority(self.data)

        if child is None or child_answer is None:
            return self.majority(group, fallback)

        subgroup = [m for m in group if feature_value(m, child) == child_answer]
        return self.majority(subgroup, self.majority(group, fallback))

    def predict(self, monster: Monster) -> Tuple[str, List[Tuple[str, bool]]]:
        root_answer = feature_value(monster, self.root)
        path = [(self.root, root_answer)]
        child = self.yes_child if root_answer else self.no_child

        if child is None:
            return self.leaf_label(root_answer, None, None), path

        child_answer = feature_value(monster, child)
        path.append((child, child_answer))
        return self.leaf_label(root_answer, child, child_answer), path

    def accuracy(self, items: Sequence[Monster]) -> float:
        if not items:
            return 0.0
        hits = sum(self.predict(m)[0] == m.label for m in items)
        return hits / len(items)

    def description_lines(self) -> List[str]:
        lines = ["1. " + FEATURE_SHORT[self.root]]
        if self.yes_child:
            lines.append("JA → " + FEATURE_SHORT[self.yes_child])
        else:
            lines.append("JA → Blatt")
        if self.no_child:
            lines.append("NEIN → " + FEATURE_SHORT[self.no_child])
        else:
            lines.append("NEIN → Blatt")
        return lines


@dataclass
class ForestTree:
    number: int
    tree: DecisionTree
    features: Tuple[str, str]
    sample_names: Tuple[str, ...]

    @property
    def unique_training_count(self) -> int:
        return len(set(self.sample_names))


class RandomForest:
    """Didaktisch vereinfachter Random Forest mit fünf kleinen Bäumen.

    Jeder Baum:
    1. zieht eine Bootstrap-Stichprobe aus den Trainingsmonstern
    2. bekommt nur zwei zufällig ausgewählte Merkmale
    3. wählt aus diesen Merkmalen den besten kleinen Baum

    Die Vorhersage des Forest ist die Mehrheitsabstimmung der fünf Bäume.
    """

    def __init__(self, training: Sequence[Monster], rng: random.Random, n_trees: int = 5) -> None:
        self.training = list(training)
        self.rng = rng
        self.n_trees = n_trees
        self.trees: List[ForestTree] = []
        self.rebuild()

    def _bootstrap_sample(self) -> List[Monster]:
        return [self.rng.choice(self.training) for _ in range(len(self.training))]

    def _best_small_tree(self, sample: Sequence[Monster], features: Sequence[str]) -> DecisionTree:
        # Für zwei Merkmale testen wir alle kleinen Kombinationen:
        # Wurzel = Merkmal A oder B; Kind = kein Kind oder das andere Merkmal.
        candidates: List[Tuple[float, DecisionTree]] = []

        for root in features:
            other = next(f for f in features if f != root)
            child_choices: List[Optional[str]] = [None, other]

            for yes_child in child_choices:
                for no_child in child_choices:
                    tree = DecisionTree(sample, root, yes_child, no_child)
                    candidates.append((tree.accuracy(sample), tree))

        best_accuracy = max(acc for acc, _ in candidates)
        best = [tree for acc, tree in candidates if math.isclose(acc, best_accuracy)]
        return self.rng.choice(best)

    def rebuild(self) -> None:
        self.trees = []
        for i in range(self.n_trees):
            sample = self._bootstrap_sample()
            features = tuple(self.rng.sample(FEATURES, 2))
            tree = self._best_small_tree(sample, features)
            self.trees.append(
                ForestTree(
                    number=i + 1,
                    tree=tree,
                    features=(features[0], features[1]),
                    sample_names=tuple(m.name for m in sample),
                )
            )

    def votes(self, monster: Monster) -> List[str]:
        return [ft.tree.predict(monster)[0] for ft in self.trees]

    def predict(self, monster: Monster) -> Tuple[str, List[str]]:
        votes = self.votes(monster)
        dangerous = votes.count("gefährlich")
        friendly = votes.count("freundlich")
        result = "gefährlich" if dangerous > friendly else "freundlich"
        return result, votes

    def accuracy(self, items: Sequence[Monster]) -> float:
        if not items:
            return 0.0
        hits = sum(self.predict(m)[0] == m.label for m in items)
        return hits / len(items)


class Game:
    def __init__(self) -> None:
        pygame.init()
        pygame.display.set_caption("Monster-Detektiv – Decision Tree & Random Forest")
        self.display = pygame.display.set_mode((WIDTH, HEIGHT), pygame.DOUBLEBUF)
        self.canvas = pygame.Surface((WIDTH, HEIGHT)).convert()
        self.clock = pygame.time.Clock()

        self.tiny = pygame.font.SysFont("arial", 13)
        self.small = pygame.font.SysFont("arial", 16)
        self.font = pygame.font.SysFont("arial", 19)
        self.bold = pygame.font.SysFont("arial", 19, bold=True)
        self.big = pygame.font.SysFont("arial", 28, bold=True)
        self.huge = pygame.font.SysFont("arial", 40, bold=True)

        # 1 = Trainingsmonster
        # 2 = eigenen Baum bauen
        # 3 = eigenen Baum testen
        # 4 = Random Forest kennenlernen
        # 5 = Random Forest abstimmen lassen
        self.phase = 1

        self.selected_training = 0

        self.root_feature = "horns"
        self.yes_feature: Optional[str] = None
        self.no_feature: Optional[str] = "wings"
        self.tree = DecisionTree(TRAINING, self.root_feature, self.yes_feature, self.no_feature)

        self.test_index = 0
        self.prediction: Optional[str] = None
        self.path: List[Tuple[str, bool]] = []
        self.score = 0
        self.answered: Set[int] = set()

        self.rng = random.Random()
        self.forest = RandomForest(TRAINING, self.rng, 5)
        self.forest_test_index = 0
        self.forest_prediction: Optional[str] = None
        self.forest_votes: List[str] = []
        self.forest_score = 0
        self.forest_answered: Set[int] = set()

        self.buttons: List[Button] = []

    # ------------------------------------------------------------
    # Text / UI helpers
    # ------------------------------------------------------------

    def text(self, font: pygame.font.Font, txt: str, pos: Tuple[int, int], color=TEXT) -> None:
        self.canvas.blit(font.render(txt, True, color), pos)

    def centered(self, font: pygame.font.Font, txt: str, center: Tuple[int, int], color=TEXT) -> None:
        img = font.render(txt, True, color)
        self.canvas.blit(img, img.get_rect(center=center))

    def wrap(self, font: pygame.font.Font, txt: str, rect: pygame.Rect, color=MUTED, gap: int = 4) -> None:
        words = txt.split()
        lines: List[str] = []
        current = ""
        for word in words:
            test = word if not current else current + " " + word
            if font.size(test)[0] <= rect.width:
                current = test
            else:
                if current:
                    lines.append(current)
                current = word
        if current:
            lines.append(current)

        y = rect.top
        for line in lines:
            self.text(font, line, (rect.left, y), color)
            y += font.get_height() + gap

    def panel(self, rect: pygame.Rect, fill=PANEL, border=BORDER, width: int = 2, radius: int = 14) -> None:
        pygame.draw.rect(self.canvas, fill, rect, border_radius=radius)
        pygame.draw.rect(self.canvas, border, rect, width=width, border_radius=radius)

    def draw_tree_icon(self, center: Tuple[int, int], scale: float = 1.0) -> None:
        cx, cy = center
        trunk = pygame.Rect(0, 0, int(18 * scale), int(44 * scale))
        trunk.center = (cx, cy + int(18 * scale))
        pygame.draw.rect(self.canvas, TREE_TRUNK, trunk, border_radius=max(2, int(4 * scale)))
        pygame.draw.circle(self.canvas, TREE_GREEN, (cx, cy - int(10 * scale)), int(28 * scale))
        pygame.draw.circle(self.canvas, TREE_GREEN, (cx - int(20 * scale), cy + int(2 * scale)), int(20 * scale))
        pygame.draw.circle(self.canvas, TREE_GREEN, (cx + int(20 * scale), cy + int(2 * scale)), int(20 * scale))

    # ------------------------------------------------------------
    # Monster drawing
    # ------------------------------------------------------------

    def draw_monster(self, monster: Monster, center: Tuple[int, int], scale: float = 1.0) -> None:
        cx, cy = center
        body_w = int((86 if monster.big else 68) * scale)
        body_h = int((82 if monster.big else 66) * scale)

        if monster.wings:
            wing_w, wing_h = int(28 * scale), int(44 * scale)
            left = [
                (cx - body_w // 2, cy - 8),
                (cx - body_w // 2 - wing_w, cy - wing_h // 2),
                (cx - body_w // 2 - wing_w + 5, cy + wing_h // 2),
            ]
            right = [
                (cx + body_w // 2, cy - 8),
                (cx + body_w // 2 + wing_w, cy - wing_h // 2),
                (cx + body_w // 2 + wing_w - 5, cy + wing_h // 2),
            ]
            pygame.draw.polygon(self.canvas, (170, 190, 230), left)
            pygame.draw.polygon(self.canvas, (170, 190, 230), right)
            pygame.draw.polygon(self.canvas, BORDER, left, width=2)
            pygame.draw.polygon(self.canvas, BORDER, right, width=2)

        body = pygame.Rect(0, 0, body_w, body_h)
        body.center = center
        pygame.draw.ellipse(self.canvas, COLORS[monster.color], body)
        pygame.draw.ellipse(self.canvas, BLACK, body, width=2)

        if monster.horns:
            top = body.top + int(7 * scale)
            horn_h, horn_w = int(26 * scale), int(13 * scale)
            for offset in (-body_w // 4, body_w // 4):
                pts = [
                    (cx + offset - horn_w, top + horn_h),
                    (cx + offset, top - horn_h // 2),
                    (cx + offset + horn_w, top + horn_h),
                ]
                pygame.draw.polygon(self.canvas, YELLOW, pts)
                pygame.draw.polygon(self.canvas, BLACK, pts, width=2)

        eye_y, eye_dx = cy - int(12 * scale), int(16 * scale)
        for ex in (cx - eye_dx, cx + eye_dx):
            pygame.draw.circle(self.canvas, WHITE, (ex, eye_y), max(5, int(10 * scale)))
            pygame.draw.circle(self.canvas, BLACK, (ex, eye_y), max(3, int(5 * scale)))

        pygame.draw.arc(
            self.canvas,
            BLACK,
            pygame.Rect(
                cx - int(18 * scale),
                cy + int(8 * scale),
                int(36 * scale),
                int(22 * scale),
            ),
            0.15,
            2.95,
            2,
        )

    # ------------------------------------------------------------
    # Header / navigation
    # ------------------------------------------------------------

    def header(self) -> None:
        pygame.draw.rect(self.canvas, PANEL, (0, 0, WIDTH, 104))
        pygame.draw.line(self.canvas, BORDER, (0, 103), (WIDTH, 103), 2)

        self.text(self.big, "Monster-Detektiv", (28, 15))

        if self.phase <= 3:
            subtitle = "Level 1 · Decision Tree"
            labels = ["Training", "Baum", "Test"]
            current = self.phase
        else:
            subtitle = "Level 2 · Random Forest"
            labels = ["Wald bauen", "Abstimmen"]
            current = self.phase - 3

        self.text(self.font, subtitle, (30, 57), ACCENT)

        start_x = 830 if len(labels) == 3 else 960
        gap = 135
        for i, label in enumerate(labels, start=1):
            cx = start_x + (i - 1) * gap
            active = i == current
            done = i < current
            color = ACCENT if active else GOOD if done else BORDER

            pygame.draw.circle(self.canvas, color, (cx, 42), 19)
            self.centered(self.bold, str(i), (cx, 42), WHITE if (active or done) else TEXT)
            self.centered(self.tiny, label, (cx, 75), MUTED)

            if i < len(labels):
                pygame.draw.line(
                    self.canvas,
                    GOOD if done else BORDER,
                    (cx + 22, 42),
                    (cx + gap - 22, 42),
                    4,
                )

    # ------------------------------------------------------------
    # Level 1 - phase 1
    # ------------------------------------------------------------

    def card_rect(self, index: int) -> pygame.Rect:
        col = index % 4
        row = index // 4
        return pygame.Rect(28 + col * 196, 135 + row * 185, 176, 165)

    def phase1(self) -> None:
        self.text(self.bold, "Das sind die Trainingsdaten der KI.", (28, 114))

        for i, monster in enumerate(TRAINING):
            rect = self.card_rect(i)
            selected = i == self.selected_training
            self.panel(
                rect,
                ACCENT_LIGHT if selected else PANEL,
                ACCENT if selected else BORDER,
                3 if selected else 2,
                12,
            )
            self.draw_monster(monster, (rect.centerx, rect.top + 66), 0.72)
            self.centered(self.bold, monster.name, (rect.centerx, rect.bottom - 42))
            label_color = BAD if monster.label == "gefährlich" else GOOD
            self.centered(self.small, monster.label, (rect.centerx, rect.bottom - 18), label_color)

        info = pygame.Rect(835, 135, 415, 510)
        self.panel(info)
        monster = TRAINING[self.selected_training]

        self.centered(self.big, monster.name, (info.centerx, info.top + 38))
        self.draw_monster(monster, (info.centerx, info.top + 150), 1.18)

        props = [
            ("Farbe", monster.color),
            ("Hörner", "ja" if monster.horns else "nein"),
            ("Flügel", "ja" if monster.wings else "nein"),
            ("Größe", "groß" if monster.big else "klein"),
        ]
        y = info.top + 245
        for key, value in props:
            self.text(self.font, key + ":", (info.left + 40, y), MUTED)
            self.text(self.bold, value, (info.left + 175, y), TEXT)
            y += 39

        color = BAD if monster.label == "gefährlich" else GOOD
        self.text(self.font, "Klasse:", (info.left + 40, y + 8), MUTED)
        self.text(self.bold, monster.label, (info.left + 175, y + 8), color)

        self.wrap(
            self.small,
            "Klicke verschiedene Monster an. Genau solche Beispiele bekommt die KI beim Training.",
            pygame.Rect(info.left + 30, info.bottom - 75, info.width - 60, 60),
        )

    # ------------------------------------------------------------
    # Level 1 - phase 2
    # ------------------------------------------------------------

    def rebuild_tree(self) -> None:
        if self.yes_feature == self.root_feature:
            self.yes_feature = None
        if self.no_feature == self.root_feature:
            self.no_feature = None
        self.tree = DecisionTree(TRAINING, self.root_feature, self.yes_feature, self.no_feature)

    def node(self, center: Tuple[int, int], label: str, kind: str) -> pygame.Rect:
        if kind == "q":
            w, h = 190, 58
            fill, border = ACCENT_LIGHT, ACCENT
        else:
            w, h = 145, 58
            danger = kind == "bad"
            fill = BAD_LIGHT if danger else GOOD_LIGHT
            border = BAD if danger else GOOD

        rect = pygame.Rect(0, 0, w, h)
        rect.center = center
        self.panel(rect, fill, border, 2, 12)
        self.centered(self.small, label, rect.center, TEXT)
        return rect

    def branch_label(self, a: Tuple[int, int], b: Tuple[int, int], answer: bool) -> None:
        pygame.draw.line(self.canvas, BORDER, a, b, 3)
        mid = ((a[0] + b[0]) // 2, (a[1] + b[1]) // 2)
        bubble = pygame.Rect(0, 0, 46, 24)
        bubble.center = mid
        color = GOOD if answer else BAD
        self.panel(bubble, WHITE, color, 2, 10)
        self.centered(self.tiny, "JA" if answer else "NEIN", bubble.center, color)

    def tree_branch(
        self,
        root: Tuple[int, int],
        center: Tuple[int, int],
        root_answer: bool,
        child: Optional[str],
    ) -> None:
        self.branch_label((root[0], root[1] + 29), (center[0], center[1] - 29), root_answer)

        if child is None:
            label = self.tree.leaf_label(root_answer, None, None)
            self.node(center, label, "bad" if label == "gefährlich" else "good")
            return

        self.node(center, FEATURE_LABELS[child], "q")
        yes_pos = (center[0] - 88, center[1] + 145)
        no_pos = (center[0] + 88, center[1] + 145)

        self.branch_label((center[0] - 18, center[1] + 29), (yes_pos[0], yes_pos[1] - 29), True)
        self.branch_label((center[0] + 18, center[1] + 29), (no_pos[0], no_pos[1] - 29), False)

        yes_label = self.tree.leaf_label(root_answer, child, True)
        no_label = self.tree.leaf_label(root_answer, child, False)
        self.node(yes_pos, yes_label, "bad" if yes_label == "gefährlich" else "good")
        self.node(no_pos, no_label, "bad" if no_label == "gefährlich" else "good")

    def phase2(self) -> None:
        area = pygame.Rect(24, 124, 835, 650)
        self.panel(area)
        self.text(self.bold, "Dein Entscheidungsbaum", (area.left + 22, area.top + 18))

        root = (area.centerx, area.top + 120)
        yes_center = (area.left + 235, area.top + 310)
        no_center = (area.right - 235, area.top + 310)

        self.node(root, FEATURE_LABELS[self.root_feature], "q")
        self.tree_branch(root, yes_center, True, self.yes_feature)
        self.tree_branch(root, no_center, False, self.no_feature)

        acc = self.tree.accuracy(TRAINING)
        box = pygame.Rect(area.left + 24, area.bottom - 70, 250, 42)
        pygame.draw.rect(self.canvas, PANEL_ALT, box, border_radius=10)
        self.centered(
            self.bold,
            f"Training: {acc * 100:.0f}% richtig",
            box.center,
            GOOD if acc >= 0.9 else TEXT,
        )

        self.wrap(
            self.small,
            "Die Blätter werden aus der Mehrheitsklasse der Trainingsmonster gebildet, die den jeweiligen Weg erreichen.",
            pygame.Rect(area.left + 310, area.bottom - 73, 485, 58),
        )

        self.text(self.bold, "1. Erste Frage", (890, 125))
        self.text(self.bold, "2. Zweite Frage", (890, 360))
        self.text(self.tiny, "wenn JA", (910, 381), GOOD)
        self.text(self.tiny, "wenn NEIN", (1072, 381), BAD)
        self.wrap(
            self.small,
            "Tipp: Gute Fragen trennen freundliche und gefährliche Monster möglichst sauber.",
            pygame.Rect(890, 600, 340, 70),
        )

    # ------------------------------------------------------------
    # Level 1 - phase 3
    # ------------------------------------------------------------

    def reset_test(self) -> None:
        self.test_index = 0
        self.prediction = None
        self.path = []
        self.score = 0
        self.answered.clear()

    def phase3(self) -> None:
        m = TEST_DATA[self.test_index]
        left = pygame.Rect(24, 124, 465, 650)
        center = pygame.Rect(510, 124, 315, 650)
        right = pygame.Rect(846, 124, 410, 650)

        for rect in (left, center, right):
            self.panel(rect)

        self.centered(self.big, f"Testmonster {self.test_index + 1}/{len(TEST_DATA)}", (left.centerx, left.top + 38))
        self.draw_monster(m, (left.centerx, left.top + 205), 1.55)
        self.centered(self.big, m.name, (left.centerx, left.top + 335))

        props = [
            f"Farbe: {m.color}",
            f"Hörner: {'ja' if m.horns else 'nein'}",
            f"Flügel: {'ja' if m.wings else 'nein'}",
            f"Größe: {'groß' if m.big else 'klein'}",
        ]
        y = left.top + 395
        for prop in props:
            self.centered(self.font, prop, (left.centerx, y))
            y += 34

        self.centered(self.big, "Weg durch den Baum", (center.centerx, center.top + 38))
        if not self.path:
            self.wrap(
                self.font,
                "Drücke „KI entscheiden“. Dann siehst du, welche Fragen dein Baum benutzt.",
                pygame.Rect(center.left + 25, center.top + 115, center.width - 50, 140),
            )
        else:
            y = center.top + 105
            for feature, answer in self.path:
                q = pygame.Rect(center.left + 28, y, center.width - 56, 60)
                self.panel(q, ACCENT_LIGHT, ACCENT, 2, 10)
                self.centered(self.small, FEATURE_LABELS[feature], (q.centerx, q.centery - 9))
                self.centered(self.bold, "JA" if answer else "NEIN", (q.centerx, q.centery + 15), GOOD if answer else BAD)
                y += 100

            if self.prediction:
                rr = pygame.Rect(center.left + 35, y + 18, center.width - 70, 85)
                color = BAD if self.prediction == "gefährlich" else GOOD
                fill = BAD_LIGHT if self.prediction == "gefährlich" else GOOD_LIGHT
                self.panel(rr, fill, color, 2, 12)
                self.centered(self.small, "Der Baum sagt:", (rr.centerx, rr.centery - 17), MUTED)
                self.centered(self.bold, self.prediction, (rr.centerx, rr.centery + 13), color)

        self.centered(self.big, "Auswertung", (right.centerx, right.top + 38))
        score_box = pygame.Rect(right.left + 40, right.top + 92, right.width - 80, 84)
        pygame.draw.rect(self.canvas, PANEL_ALT, score_box, border_radius=12)
        answered = len(self.answered)
        self.centered(self.small, "Bisher richtig", (score_box.centerx, score_box.centery - 19), MUTED)
        self.centered(self.huge, f"{self.score}/{answered}" if answered else "–", (score_box.centerx, score_box.centery + 17))

        if self.prediction:
            correct = self.prediction == m.label
            self.centered(self.big, "Richtig!" if correct else "Nicht ganz!", (right.centerx, right.top + 240), GOOD if correct else BAD)
            self.centered(self.small, f"Richtige Klasse: {m.label}", (right.centerx, right.top + 280))
            self.wrap(
                self.small,
                "Ein einzelner Baum entscheidet nur mit seinen Fragen. Im nächsten Level lassen wir mehrere unterschiedliche Bäume gemeinsam abstimmen.",
                pygame.Rect(right.left + 42, right.top + 320, right.width - 84, 110),
            )
        else:
            self.wrap(
                self.small,
                "Die echte Klasse bleibt versteckt, bis die KI entschieden hat.",
                pygame.Rect(right.left + 42, right.top + 230, right.width - 84, 90),
            )

        self.text(
            self.tiny,
            f"Testgenauigkeit deines Baums: {self.tree.accuracy(TEST_DATA) * 100:.0f}%",
            (right.left + 42, right.top + 455),
            MUTED,
        )

        forest_hint = pygame.Rect(right.left + 38, right.top + 500, right.width - 76, 82)
        self.panel(forest_hint, GOOD_LIGHT, GOOD, 2, 12)
        self.centered(self.bold, "Level 2 wartet!", (forest_hint.centerx, forest_hint.top + 23), GOOD)
        self.centered(self.small, "5 Bäume → 5 Stimmen → 1 Entscheidung", (forest_hint.centerx, forest_hint.top + 53), TEXT)

    # ------------------------------------------------------------
    # Level 2 - phase 4: forest overview
    # ------------------------------------------------------------

    def forest_card_rect(self, index: int) -> pygame.Rect:
        gap = 12
        margin = 22
        card_w = (WIDTH - margin * 2 - gap * 4) // 5
        return pygame.Rect(margin + index * (card_w + gap), 180, card_w, 360)

    def draw_forest_tree_card(self, ft: ForestTree, index: int) -> None:
        rect = self.forest_card_rect(index)
        self.panel(rect)
        self.draw_tree_icon((rect.centerx, rect.top + 62), 0.72)
        self.centered(self.bold, f"Baum {ft.number}", (rect.centerx, rect.top + 112))

        feat_text = " + ".join(FEATURE_SHORT[f] for f in ft.features)
        self.centered(self.tiny, "Zufallsmerkmale", (rect.centerx, rect.top + 145), MUTED)
        self.centered(self.small, feat_text, (rect.centerx, rect.top + 169), ACCENT)

        self.centered(self.tiny, "Bootstrap-Training", (rect.centerx, rect.top + 205), MUTED)
        self.centered(
            self.small,
            f"{len(ft.sample_names)} Ziehungen",
            (rect.centerx, rect.top + 228),
            TEXT,
        )
        self.centered(
            self.tiny,
            f"{ft.unique_training_count} verschiedene Monster",
            (rect.centerx, rect.top + 250),
            MUTED,
        )

        lines = ft.tree.description_lines()
        y = rect.top + 285
        for line in lines:
            self.centered(self.tiny, line, (rect.centerx, y), TEXT)
            y += 21

        train_acc = ft.tree.accuracy(ft.tree.data)
        self.centered(
            self.tiny,
            f"Training: {train_acc * 100:.0f}%",
            (rect.centerx, rect.bottom - 22),
            GOOD if train_acc >= 0.8 else MUTED,
        )

    def phase4(self) -> None:
        self.centered(self.big, "Fünf unterschiedliche Bäume bilden einen Random Forest", (WIDTH // 2, 135))

        for i, ft in enumerate(self.forest.trees):
            self.draw_forest_tree_card(ft, i)

        explain = pygame.Rect(32, 565, 790, 165)
        self.panel(explain, PANEL_ALT)
        self.text(self.bold, "Warum sind die Bäume unterschiedlich?", (explain.left + 24, explain.top + 18))

        bullets = [
            "1. Jeder Baum zieht seine Trainingsmonster zufällig (Bootstrap).",
            "2. Jeder Baum darf nur 2 zufällige Merkmale benutzen.",
            "3. Deshalb machen einzelne Bäume unterschiedliche Fehler.",
            "4. Am Ende stimmen alle 5 Bäume gemeinsam ab.",
        ]
        y = explain.top + 55
        for line in bullets:
            self.text(self.small, line, (explain.left + 28, y), TEXT)
            y += 25

        side = pygame.Rect(846, 565, 402, 165)
        self.panel(side, GOOD_LIGHT, GOOD)
        self.centered(self.bold, "Merksatz", (side.centerx, side.top + 28), GOOD)
        self.wrap(
            self.font,
            "Ein Baum ist eine Meinung. Ein Random Forest sammelt viele unterschiedliche Meinungen und nimmt die Mehrheit.",
            pygame.Rect(side.left + 30, side.top + 60, side.width - 60, 90),
            TEXT,
        )

    # ------------------------------------------------------------
    # Level 2 - phase 5: forest voting
    # ------------------------------------------------------------

    def reset_forest_test(self) -> None:
        self.forest_test_index = 0
        self.forest_prediction = None
        self.forest_votes = []
        self.forest_score = 0
        self.forest_answered.clear()

    def current_forest_monster(self) -> Monster:
        return TEST_DATA[self.forest_test_index]

    def forest_vote(self) -> None:
        if self.forest_prediction is not None:
            return

        monster = self.current_forest_monster()
        prediction, votes = self.forest.predict(monster)
        self.forest_prediction = prediction
        self.forest_votes = votes

        if self.forest_test_index not in self.forest_answered:
            self.forest_score += int(prediction == monster.label)
            self.forest_answered.add(self.forest_test_index)

    def next_forest_monster(self) -> None:
        if self.forest_prediction is None:
            return
        if self.forest_test_index < len(TEST_DATA) - 1:
            self.forest_test_index += 1
            self.forest_prediction = None
            self.forest_votes = []

    def draw_vote_bar(self, friendly: int, dangerous: int, rect: pygame.Rect) -> None:
        total = friendly + dangerous
        if total <= 0:
            return

        friend_w = int(rect.width * friendly / total)
        danger_w = rect.width - friend_w

        if friend_w:
            pygame.draw.rect(self.canvas, GOOD, (rect.left, rect.top, friend_w, rect.height), border_radius=8)
        if danger_w:
            danger_rect = pygame.Rect(rect.left + friend_w, rect.top, danger_w, rect.height)
            pygame.draw.rect(self.canvas, BAD, danger_rect, border_radius=8)
        pygame.draw.rect(self.canvas, BORDER, rect, width=2, border_radius=8)

    def phase5(self) -> None:
        m = self.current_forest_monster()

        left = pygame.Rect(24, 124, 350, 650)
        middle = pygame.Rect(395, 124, 500, 650)
        right = pygame.Rect(916, 124, 340, 650)
        for rect in (left, middle, right):
            self.panel(rect)

        # Monster
        self.centered(self.big, f"Monster {self.forest_test_index + 1}/{len(TEST_DATA)}", (left.centerx, left.top + 38))
        self.draw_monster(m, (left.centerx, left.top + 205), 1.5)
        self.centered(self.big, m.name, (left.centerx, left.top + 330))

        props = [
            f"Farbe: {m.color}",
            f"Hörner: {'ja' if m.horns else 'nein'}",
            f"Flügel: {'ja' if m.wings else 'nein'}",
            f"Größe: {'groß' if m.big else 'klein'}",
        ]
        y = left.top + 390
        for prop in props:
            self.centered(self.font, prop, (left.centerx, y))
            y += 34

        # Votes
        self.centered(self.big, "Die 5 Baum-Stimmen", (middle.centerx, middle.top + 38))
        y = middle.top + 88
        for i, ft in enumerate(self.forest.trees):
            vote_rect = pygame.Rect(middle.left + 28, y, middle.width - 56, 82)
            self.panel(vote_rect, PANEL_ALT)

            self.draw_tree_icon((vote_rect.left + 44, vote_rect.centery), 0.48)
            self.text(self.bold, f"Baum {i + 1}", (vote_rect.left + 82, vote_rect.top + 13))

            feat_text = " / ".join(FEATURE_SHORT[f] for f in ft.features)
            self.text(self.tiny, feat_text, (vote_rect.left + 82, vote_rect.top + 44), MUTED)

            if self.forest_votes:
                vote = self.forest_votes[i]
                color = BAD if vote == "gefährlich" else GOOD
                fill = BAD_LIGHT if vote == "gefährlich" else GOOD_LIGHT
                badge = pygame.Rect(vote_rect.right - 148, vote_rect.top + 19, 126, 44)
                pygame.draw.rect(self.canvas, fill, badge, border_radius=10)
                pygame.draw.rect(self.canvas, color, badge, width=2, border_radius=10)
                self.centered(self.small, vote, badge.center, color)
            else:
                self.centered(self.small, "?", (vote_rect.right - 78, vote_rect.centery), MUTED)

            y += 96

        # Result
        self.centered(self.big, "Mehrheit entscheidet", (right.centerx, right.top + 38))

        if not self.forest_votes:
            self.wrap(
                self.font,
                "Drücke „Wald abstimmen“. Jeder Baum gibt dann unabhängig seine Stimme ab.",
                pygame.Rect(right.left + 30, right.top + 100, right.width - 60, 120),
            )
        else:
            friendly = self.forest_votes.count("freundlich")
            dangerous = self.forest_votes.count("gefährlich")

            self.centered(self.small, f"freundlich: {friendly}", (right.centerx, right.top + 120), GOOD)
            self.centered(self.small, f"gefährlich: {dangerous}", (right.centerx, right.top + 150), BAD)
            self.draw_vote_bar(friendly, dangerous, pygame.Rect(right.left + 45, right.top + 180, right.width - 90, 30))

            result_color = BAD if self.forest_prediction == "gefährlich" else GOOD
            result_fill = BAD_LIGHT if self.forest_prediction == "gefährlich" else GOOD_LIGHT
            result_box = pygame.Rect(right.left + 38, right.top + 245, right.width - 76, 100)
            self.panel(result_box, result_fill, result_color, 2, 12)
            self.centered(self.small, "Random Forest sagt:", (result_box.centerx, result_box.top + 28), MUTED)
            self.centered(self.big, self.forest_prediction or "", (result_box.centerx, result_box.top + 65), result_color)

            correct = self.forest_prediction == m.label
            self.centered(
                self.big,
                "Richtig!" if correct else "Nicht ganz!",
                (right.centerx, right.top + 395),
                GOOD if correct else BAD,
            )
            self.centered(self.small, f"Richtige Klasse: {m.label}", (right.centerx, right.top + 430))

        answered = len(self.forest_answered)
        score = f"{self.forest_score}/{answered}" if answered else "–"
        score_box = pygame.Rect(right.left + 52, right.top + 480, right.width - 104, 72)
        pygame.draw.rect(self.canvas, PANEL_ALT, score_box, border_radius=12)
        self.centered(self.tiny, "Forest-Score", (score_box.centerx, score_box.top + 19), MUTED)
        self.centered(self.big, score, (score_box.centerx, score_box.top + 48))

        self.centered(
            self.tiny,
            f"Testgenauigkeit dieses Waldes: {self.forest.accuracy(TEST_DATA) * 100:.0f}%",
            (right.centerx, right.top + 580),
            MUTED,
        )

    # ------------------------------------------------------------
    # Buttons and events
    # ------------------------------------------------------------

    def build_buttons(self) -> None:
        self.buttons = []

        if self.phase == 1:
            self.buttons.append(
                Button(pygame.Rect(WIDTH - 275, HEIGHT - 64, 245, 44), "Weiter: Baum bauen", "phase2")
            )

        elif self.phase == 2:
            x, y = 890, 160
            for i, feature in enumerate(FEATURES):
                self.buttons.append(
                    Button(
                        pygame.Rect(x, y + i * 47, 335, 40),
                        FEATURE_LABELS[feature],
                        "root",
                        feature,
                        active=self.root_feature == feature,
                    )
                )

            y2 = 405
            for i, feature in enumerate(FEATURES):
                self.buttons.append(
                    Button(
                        pygame.Rect(x, y2 + i * 38, 155, 34),
                        FEATURE_SHORT[feature],
                        "yes",
                        feature,
                        enabled=feature != self.root_feature,
                        active=self.yes_feature == feature,
                    )
                )
                self.buttons.append(
                    Button(
                        pygame.Rect(x + 170, y2 + i * 38, 155, 34),
                        FEATURE_SHORT[feature],
                        "no",
                        feature,
                        enabled=feature != self.root_feature,
                        active=self.no_feature == feature,
                    )
                )

            self.buttons.append(
                Button(pygame.Rect(x, y2 + 4 * 38, 155, 34), "keine", "yes", "none", active=self.yes_feature is None)
            )
            self.buttons.append(
                Button(pygame.Rect(x + 170, y2 + 4 * 38, 155, 34), "keine", "no", "none", active=self.no_feature is None)
            )
            self.buttons.append(Button(pygame.Rect(890, 705, 160, 44), "Zurücksetzen", "reset_tree"))
            self.buttons.append(Button(pygame.Rect(1065, 705, 160, 44), "Zum Test", "phase3"))

        elif self.phase == 3:
            # Navigationsleiste unterhalb der drei Inhalts-Panels. So überdecken
            # die Buttons weder Auswertung noch Level-2-Hinweis.
            bottom_y = 780
            self.buttons.append(Button(pygame.Rect(24, bottom_y, 180, 34), "← Zum Baum", "phase2"))
            self.buttons.append(
                Button(pygame.Rect(216, bottom_y, 270, 34), "KI entscheiden", "predict", enabled=self.prediction is None)
            )
            self.buttons.append(
                Button(
                    pygame.Rect(498, bottom_y, 270, 34),
                    "Nächstes Monster",
                    "next",
                    enabled=self.prediction is not None and self.test_index < len(TEST_DATA) - 1,
                )
            )
            self.buttons.append(Button(pygame.Rect(780, bottom_y, 250, 34), "Level 2: Random Forest", "phase4"))

        elif self.phase == 4:
            self.buttons.append(Button(pygame.Rect(858, 750, 185, 44), "Wald neu würfeln", "reroll_forest"))
            self.buttons.append(Button(pygame.Rect(1055, 750, 193, 44), "Monster testen", "phase5"))
            self.buttons.append(Button(pygame.Rect(32, 750, 170, 44), "← Level 1", "phase3"))

        elif self.phase == 5:
            # Auch hier liegen die Steuerungen in einer eigenen unteren Leiste,
            # damit Stimmen, Ergebnis und Score vollständig sichtbar bleiben.
            bottom_y = 780
            self.buttons.append(Button(pygame.Rect(24, bottom_y, 180, 34), "← Zum Wald", "phase4"))
            self.buttons.append(
                Button(
                    pygame.Rect(216, bottom_y, 300, 34),
                    "Wald abstimmen",
                    "forest_vote",
                    enabled=self.forest_prediction is None,
                )
            )
            self.buttons.append(
                Button(
                    pygame.Rect(528, bottom_y, 300, 34),
                    "Nächstes Monster",
                    "forest_next",
                    enabled=self.forest_prediction is not None and self.forest_test_index < len(TEST_DATA) - 1,
                )
            )
            self.buttons.append(Button(pygame.Rect(840, bottom_y, 210, 34), "Wald neu würfeln", "reroll_forest_test"))

    def handle_button(self, button: Button) -> None:
        if not button.enabled:
            return

        action = button.action

        if action == "phase2":
            self.phase = 2

        elif action == "phase3":
            self.rebuild_tree()
            self.phase = 3
            self.reset_test()

        elif action == "phase4":
            self.phase = 4

        elif action == "phase5":
            self.phase = 5
            self.reset_forest_test()

        elif action == "root" and button.value:
            self.root_feature = button.value
            self.rebuild_tree()

        elif action == "yes":
            self.yes_feature = None if button.value == "none" else button.value
            self.rebuild_tree()

        elif action == "no":
            self.no_feature = None if button.value == "none" else button.value
            self.rebuild_tree()

        elif action == "reset_tree":
            self.root_feature = "horns"
            self.yes_feature = None
            self.no_feature = "wings"
            self.rebuild_tree()

        elif action == "predict" and self.prediction is None:
            monster = TEST_DATA[self.test_index]
            self.prediction, self.path = self.tree.predict(monster)
            if self.test_index not in self.answered:
                self.score += int(self.prediction == monster.label)
                self.answered.add(self.test_index)

        elif action == "next":
            if self.prediction is not None and self.test_index < len(TEST_DATA) - 1:
                self.test_index += 1
                self.prediction = None
                self.path = []

        elif action == "reroll_forest":
            self.forest.rebuild()
            self.reset_forest_test()

        elif action == "forest_vote":
            self.forest_vote()

        elif action == "forest_next":
            self.next_forest_monster()

        elif action == "reroll_forest_test":
            self.forest.rebuild()
            self.reset_forest_test()

    def click(self, pos: Tuple[int, int]) -> None:
        self.build_buttons()
        for button in self.buttons:
            if button.rect.collidepoint(pos):
                self.handle_button(button)
                return

        if self.phase == 1:
            for i in range(len(TRAINING)):
                if self.card_rect(i).collidepoint(pos):
                    self.selected_training = i
                    return

    # ------------------------------------------------------------
    # Main loop
    # ------------------------------------------------------------

    def draw(self) -> None:
        self.canvas.fill(BG)
        self.header()

        if self.phase == 1:
            self.phase1()
        elif self.phase == 2:
            self.phase2()
        elif self.phase == 3:
            self.phase3()
        elif self.phase == 4:
            self.phase4()
        else:
            self.phase5()

        self.build_buttons()
        for button in self.buttons:
            button.draw(self.canvas, self.small, self.tiny)

        self.display.blit(self.canvas, (0, 0))
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
                    elif event.key == pygame.K_1:
                        self.phase = 1
                    elif event.key == pygame.K_2:
                        self.phase = 2
                    elif event.key == pygame.K_3:
                        self.rebuild_tree()
                        self.phase = 3
                        self.reset_test()
                    elif event.key == pygame.K_4:
                        self.phase = 4
                    elif event.key == pygame.K_5:
                        self.phase = 5
                        self.reset_forest_test()

                elif event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
                    self.click(event.pos)

            self.draw()
            self.clock.tick(FPS)


if __name__ == "__main__":
    Game().loop()
