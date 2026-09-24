from __future__ import annotations

import sys
from dataclasses import dataclass
from typing import Dict, List, Optional, Sequence, Tuple

import pygame

WIDTH, HEIGHT, FPS = 1180, 780, 60
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
COLORS = {"grün": (89, 177, 95), "blau": (78, 132, 208), "rot": (211, 91, 91)}


@dataclass(frozen=True)
class Monster:
    name: str
    color: str
    horns: bool
    wings: bool
    big: bool
    label: str


def make_monster(name: str, color: str, horns: bool, wings: bool, big: bool) -> Monster:
    # Bewusst einfache geheime Regel für Kinder:
    # Hörner ODER Flügel => gefährlich.
    label = "gefährlich" if horns or wings else "freundlich"
    return Monster(name, color, horns, wings, big, label)


TRAINING = [
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

TEST_DATA = [
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
FEATURE_SHORT = {"horns": "Hörner", "wings": "Flügel", "big": "Groß", "green": "Grün"}
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
        f = small if len(self.text) > 18 else font
        img = f.render(self.text, True, color)
        surface.blit(img, img.get_rect(center=self.rect.center))


class DecisionTree:
    def __init__(self, data: Sequence[Monster], root: str, yes_child: Optional[str], no_child: Optional[str]):
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
        return "gefährlich" if dangerous > friendly else "freundlich"

    def root_group(self, answer: bool) -> List[Monster]:
        return [m for m in self.data if feature_value(m, self.root) == answer]

    def leaf_label(self, root_answer: bool, child: Optional[str], child_answer: Optional[bool]) -> str:
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
        return sum(self.predict(m)[0] == m.label for m in items) / len(items)


class Game:
    def __init__(self) -> None:
        pygame.init()
        pygame.display.set_caption("Monster-Detektiv – Decision Tree")
        self.display = pygame.display.set_mode((WIDTH, HEIGHT), pygame.DOUBLEBUF)
        self.canvas = pygame.Surface((WIDTH, HEIGHT)).convert()
        self.clock = pygame.time.Clock()
        self.tiny = pygame.font.SysFont("arial", 13)
        self.small = pygame.font.SysFont("arial", 16)
        self.font = pygame.font.SysFont("arial", 19)
        self.bold = pygame.font.SysFont("arial", 19, bold=True)
        self.big = pygame.font.SysFont("arial", 28, bold=True)
        self.huge = pygame.font.SysFont("arial", 40, bold=True)

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
        self.answered: set[int] = set()
        self.buttons: List[Button] = []

    def text(self, font: pygame.font.Font, txt: str, pos: Tuple[int, int], color=TEXT) -> None:
        self.canvas.blit(font.render(txt, True, color), pos)

    def centered(self, font: pygame.font.Font, txt: str, center: Tuple[int, int], color=TEXT) -> None:
        img = font.render(txt, True, color)
        self.canvas.blit(img, img.get_rect(center=center))

    def wrap(self, font: pygame.font.Font, txt: str, rect: pygame.Rect, color=MUTED) -> None:
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
            y += font.get_height() + 4

    def draw_monster(self, monster: Monster, center: Tuple[int, int], scale: float = 1.0) -> None:
        cx, cy = center
        body_w = int((86 if monster.big else 68) * scale)
        body_h = int((82 if monster.big else 66) * scale)
        if monster.wings:
            wing_w, wing_h = int(28 * scale), int(44 * scale)
            left = [(cx - body_w // 2, cy - 8), (cx - body_w // 2 - wing_w, cy - wing_h // 2), (cx - body_w // 2 - wing_w + 5, cy + wing_h // 2)]
            right = [(cx + body_w // 2, cy - 8), (cx + body_w // 2 + wing_w, cy - wing_h // 2), (cx + body_w // 2 + wing_w - 5, cy + wing_h // 2)]
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
                pts = [(cx + offset - horn_w, top + horn_h), (cx + offset, top - horn_h // 2), (cx + offset + horn_w, top + horn_h)]
                pygame.draw.polygon(self.canvas, YELLOW, pts)
                pygame.draw.polygon(self.canvas, BLACK, pts, width=2)
        eye_y, eye_dx = cy - int(12 * scale), int(16 * scale)
        for ex in (cx - eye_dx, cx + eye_dx):
            pygame.draw.circle(self.canvas, WHITE, (ex, eye_y), max(5, int(10 * scale)))
            pygame.draw.circle(self.canvas, BLACK, (ex, eye_y), max(3, int(5 * scale)))
        pygame.draw.arc(self.canvas, BLACK, pygame.Rect(cx - int(18 * scale), cy + int(8 * scale), int(36 * scale), int(22 * scale)), 0.15, 2.95, 2)

    def header(self) -> None:
        pygame.draw.rect(self.canvas, PANEL, (0, 0, WIDTH, 100))
        pygame.draw.line(self.canvas, BORDER, (0, 99), (WIDTH, 99), 2)
        self.text(self.big, "Monster-Detektiv", (28, 18))
        phase_names = ["Trainingsmonster kennenlernen", "Entscheidungsbaum bauen", "Neue Monster testen"]
        self.text(self.font, f"Phase {self.phase}: {phase_names[self.phase - 1]}", (30, 58), MUTED)
        start_x = 720
        for n in (1, 2, 3):
            cx = start_x + (n - 1) * 135
            done, active = n < self.phase, n == self.phase
            color = GOOD if done else ACCENT if active else BORDER
            pygame.draw.circle(self.canvas, color, (cx, 48), 20)
            self.centered(self.bold, str(n), (cx, 48), WHITE if done or active else TEXT)
            if n < 3:
                pygame.draw.line(self.canvas, GOOD if done else BORDER, (cx + 22, 48), (cx + 112, 48), 4)
        for i, lab in enumerate(("Training", "Baum", "Test")):
            self.centered(self.tiny, lab, (start_x + i * 135, 78), MUTED)

    def card_rect(self, i: int) -> pygame.Rect:
        return pygame.Rect(28 + (i % 4) * 196, 150 + (i // 4) * 175, 176, 155)

    def phase1(self) -> None:
        self.text(self.bold, "Klicke die Monster an und entdecke ihre Merkmale.", (28, 115))
        for i, monster in enumerate(TRAINING):
            rect = self.card_rect(i)
            selected = i == self.selected_training
            pygame.draw.rect(self.canvas, ACCENT_LIGHT if selected else PANEL, rect, border_radius=12)
            pygame.draw.rect(self.canvas, ACCENT if selected else BORDER, rect, width=3 if selected else 2, border_radius=12)
            self.draw_monster(monster, (rect.centerx, rect.top + 62), 0.68)
            self.centered(self.bold, monster.name, (rect.centerx, rect.bottom - 38))
            self.centered(self.small, monster.label, (rect.centerx, rect.bottom - 17), BAD if monster.label == "gefährlich" else GOOD)

        info = pygame.Rect(820, 140, 330, 460)
        pygame.draw.rect(self.canvas, PANEL, info, border_radius=14)
        pygame.draw.rect(self.canvas, BORDER, info, width=2, border_radius=14)
        m = TRAINING[self.selected_training]
        self.centered(self.big, m.name, (info.centerx, info.top + 34))
        self.draw_monster(m, (info.centerx, info.top + 150), 1.1)
        props = [("Farbe", m.color), ("Hörner", "ja" if m.horns else "nein"), ("Flügel", "ja" if m.wings else "nein"), ("Größe", "groß" if m.big else "klein")]
        y = info.top + 245
        for k, v in props:
            self.text(self.font, k + ":", (info.left + 30, y), MUTED)
            self.text(self.bold, v, (info.left + 145, y))
            y += 38
        self.text(self.font, "Klasse:", (info.left + 30, y + 8), MUTED)
        self.text(self.bold, m.label, (info.left + 145, y + 8), BAD if m.label == "gefährlich" else GOOD)
        self.wrap(self.small, "Diese Beispiele sind die Trainingsdaten. Aus ihnen soll der Baum lernen.", pygame.Rect(info.left + 25, info.bottom - 76, info.width - 50, 60))

    def rebuild_tree(self) -> None:
        if self.yes_feature == self.root_feature:
            self.yes_feature = None
        if self.no_feature == self.root_feature:
            self.no_feature = None
        self.tree = DecisionTree(TRAINING, self.root_feature, self.yes_feature, self.no_feature)

    def node(self, center: Tuple[int, int], txt: str, kind: str) -> None:
        size = (190, 58) if kind == "q" else (145, 58)
        rect = pygame.Rect(0, 0, *size)
        rect.center = center
        if kind == "q":
            fill, border = ACCENT_LIGHT, ACCENT
        elif kind == "danger":
            fill, border = BAD_LIGHT, BAD
        else:
            fill, border = GOOD_LIGHT, GOOD
        pygame.draw.rect(self.canvas, fill, rect, border_radius=12)
        pygame.draw.rect(self.canvas, border, rect, width=2, border_radius=12)
        self.centered(self.small, txt, center)

    def branch(self, a: Tuple[int, int], b: Tuple[int, int], answer: bool) -> None:
        pygame.draw.line(self.canvas, BORDER, a, b, 3)
        mid = ((a[0] + b[0]) // 2, (a[1] + b[1]) // 2)
        bubble = pygame.Rect(0, 0, 46, 24)
        bubble.center = mid
        color = GOOD if answer else BAD
        pygame.draw.rect(self.canvas, WHITE, bubble, border_radius=10)
        pygame.draw.rect(self.canvas, color, bubble, width=2, border_radius=10)
        self.centered(self.tiny, "JA" if answer else "NEIN", mid, color)

    def tree_branch(self, root: Tuple[int, int], branch_center: Tuple[int, int], root_answer: bool, child: Optional[str]) -> None:
        self.branch((root[0], root[1] + 29), (branch_center[0], branch_center[1] - 29), root_answer)
        if child is None:
            label = self.tree.leaf_label(root_answer, None, None)
            self.node(branch_center, label, "danger" if label == "gefährlich" else "friendly")
            return
        self.node(branch_center, FEATURE_LABELS[child], "q")
        yes_pos = (branch_center[0] - 88, branch_center[1] + 145)
        no_pos = (branch_center[0] + 88, branch_center[1] + 145)
        yes_label = self.tree.leaf_label(root_answer, child, True)
        no_label = self.tree.leaf_label(root_answer, child, False)
        self.branch((branch_center[0] - 18, branch_center[1] + 29), (yes_pos[0], yes_pos[1] - 29), True)
        self.branch((branch_center[0] + 18, branch_center[1] + 29), (no_pos[0], no_pos[1] - 29), False)
        self.node(yes_pos, yes_label, "danger" if yes_label == "gefährlich" else "friendly")
        self.node(no_pos, no_label, "danger" if no_label == "gefährlich" else "friendly")

    def phase2(self) -> None:
        area = pygame.Rect(24, 122, 810, 610)
        pygame.draw.rect(self.canvas, PANEL, area, border_radius=14)
        pygame.draw.rect(self.canvas, BORDER, area, width=2, border_radius=14)
        self.text(self.bold, "Dein Entscheidungsbaum", (area.left + 22, area.top + 18))
        root = (area.centerx, area.top + 115)
        yes_center = (area.left + 225, area.top + 300)
        no_center = (area.right - 225, area.top + 300)
        self.node(root, FEATURE_LABELS[self.root_feature], "q")
        self.tree_branch(root, yes_center, True, self.yes_feature)
        self.tree_branch(root, no_center, False, self.no_feature)
        acc = self.tree.accuracy(TRAINING)
        box = pygame.Rect(area.left + 24, area.bottom - 70, 250, 42)
        pygame.draw.rect(self.canvas, PANEL_ALT, box, border_radius=10)
        self.centered(self.bold, f"Training: {acc * 100:.0f}% richtig", box.center, GOOD if acc >= 0.9 else TEXT)
        self.wrap(self.small, "Die Blätter werden aus der Mehrheitsklasse der Trainingsmonster gebildet, die den jeweiligen Weg erreichen.", pygame.Rect(area.left + 305, area.bottom - 73, 465, 58))
        self.text(self.bold, "1. Erste Frage", (870, 120))
        self.text(self.bold, "2. Zweite Frage", (870, 348))
        self.text(self.tiny, "wenn JA", (890, 368), GOOD)
        self.text(self.tiny, "wenn NEIN", (1024, 368), BAD)
        self.wrap(self.small, "Tipp: Gute Fragen trennen freundliche und gefährliche Monster möglichst sauber.", pygame.Rect(870, 585, 270, 60))

    def reset_test(self) -> None:
        self.test_index = 0
        self.prediction = None
        self.path = []
        self.score = 0
        self.answered.clear()

    def phase3(self) -> None:
        m = TEST_DATA[self.test_index]
        left = pygame.Rect(24, 122, 470, 610)
        center = pygame.Rect(515, 122, 305, 610)
        right = pygame.Rect(840, 122, 316, 610)
        for r in (left, center, right):
            pygame.draw.rect(self.canvas, PANEL, r, border_radius=14)
            pygame.draw.rect(self.canvas, BORDER, r, width=2, border_radius=14)
        self.centered(self.big, f"Testmonster {self.test_index + 1}/{len(TEST_DATA)}", (left.centerx, left.top + 35))
        self.draw_monster(m, (left.centerx, left.top + 200), 1.55)
        self.centered(self.big, m.name, (left.centerx, left.top + 330))
        props = [f"Farbe: {m.color}", f"Hörner: {'ja' if m.horns else 'nein'}", f"Flügel: {'ja' if m.wings else 'nein'}", f"Größe: {'groß' if m.big else 'klein'}"]
        y = left.top + 390
        for p in props:
            self.centered(self.font, p, (left.centerx, y))
            y += 32

        self.centered(self.big, "Weg durch den Baum", (center.centerx, center.top + 35))
        if not self.path:
            self.wrap(self.font, "Drücke „KI entscheiden“. Dann siehst du, welche Fragen der Baum benutzt.", pygame.Rect(center.left + 25, center.top + 110, center.width - 50, 130))
        else:
            y = center.top + 105
            for feature, answer in self.path:
                q = pygame.Rect(center.left + 28, y, center.width - 56, 58)
                pygame.draw.rect(self.canvas, ACCENT_LIGHT, q, border_radius=10)
                pygame.draw.rect(self.canvas, ACCENT, q, width=2, border_radius=10)
                self.centered(self.small, FEATURE_LABELS[feature], (q.centerx, q.centery - 8))
                self.centered(self.bold, "JA" if answer else "NEIN", (q.centerx, q.centery + 14), GOOD if answer else BAD)
                y += 95
            if self.prediction:
                rr = pygame.Rect(center.left + 35, y + 20, center.width - 70, 82)
                color = BAD if self.prediction == "gefährlich" else GOOD
                fill = BAD_LIGHT if self.prediction == "gefährlich" else GOOD_LIGHT
                pygame.draw.rect(self.canvas, fill, rr, border_radius=12)
                pygame.draw.rect(self.canvas, color, rr, width=2, border_radius=12)
                self.centered(self.small, "Der Baum sagt:", (rr.centerx, rr.centery - 16), MUTED)
                self.centered(self.bold, self.prediction, (rr.centerx, rr.centery + 12), color)

        self.centered(self.big, "Auswertung", (right.centerx, right.top + 35))
        score_box = pygame.Rect(right.left + 28, right.top + 90, right.width - 56, 80)
        pygame.draw.rect(self.canvas, PANEL_ALT, score_box, border_radius=12)
        answered = len(self.answered)
        self.centered(self.small, "Bisher richtig", (score_box.centerx, score_box.centery - 18), MUTED)
        self.centered(self.huge, f"{self.score}/{answered}" if answered else "–", (score_box.centerx, score_box.centery + 16))
        if self.prediction:
            correct = self.prediction == m.label
            self.centered(self.big, "Richtig!" if correct else "Nicht ganz!", (right.centerx, right.top + 225), GOOD if correct else BAD)
            self.centered(self.small, f"Richtige Klasse: {m.label}", (right.centerx, right.top + 263))
            self.wrap(self.small, "Der Baum entscheidet nur mit deinen ausgewählten Fragen. Ein anderer Baum kann anders entscheiden.", pygame.Rect(right.left + 28, right.top + 300, right.width - 56, 110))
        else:
            self.wrap(self.small, "Die echte Klasse bleibt versteckt, bis die KI entschieden hat.", pygame.Rect(right.left + 32, right.top + 220, right.width - 64, 90))
        self.text(self.tiny, f"Gesamte Testgenauigkeit: {self.tree.accuracy(TEST_DATA) * 100:.0f}%", (right.left + 28, right.top + 440), MUTED)

    def build_buttons(self) -> None:
        self.buttons = []
        if self.phase == 1:
            self.buttons.append(Button(pygame.Rect(WIDTH - 250, HEIGHT - 72, 215, 46), "Weiter: Baum bauen", "phase2"))
        elif self.phase == 2:
            x, y = 870, 155
            for i, feature in enumerate(FEATURES):
                self.buttons.append(Button(pygame.Rect(x, y + i * 46, 265, 40), FEATURE_LABELS[feature], "root", feature, active=self.root_feature == feature))
            y2 = 385
            for i, feature in enumerate(FEATURES):
                self.buttons.append(Button(pygame.Rect(x, y2 + i * 38, 125, 34), FEATURE_SHORT[feature], "yes", feature, enabled=feature != self.root_feature, active=self.yes_feature == feature))
                self.buttons.append(Button(pygame.Rect(1010, y2 + i * 38, 125, 34), FEATURE_SHORT[feature], "no", feature, enabled=feature != self.root_feature, active=self.no_feature == feature))
            self.buttons.append(Button(pygame.Rect(x, y2 + 4 * 38, 125, 34), "keine", "yes", "none", active=self.yes_feature is None))
            self.buttons.append(Button(pygame.Rect(1010, y2 + 4 * 38, 125, 34), "keine", "no", "none", active=self.no_feature is None))
            self.buttons.append(Button(pygame.Rect(870, HEIGHT - 126, 265, 40), "Baum zurücksetzen", "reset_tree"))
            self.buttons.append(Button(pygame.Rect(870, HEIGHT - 72, 265, 46), "Weiter: Monster testen", "phase3"))
        else:
            self.buttons.append(Button(pygame.Rect(850, 560, 285, 50), "KI entscheiden", "predict", enabled=self.prediction is None))
            self.buttons.append(Button(pygame.Rect(850, 620, 285, 50), "Nächstes Monster", "next", enabled=self.prediction is not None and self.test_index < len(TEST_DATA) - 1))
            self.buttons.append(Button(pygame.Rect(850, 680, 285, 42), "Zurück zum Baum", "phase2"))

    def handle_button(self, b: Button) -> None:
        if not b.enabled:
            return
        if b.action == "phase2":
            self.phase = 2
        elif b.action == "phase3":
            self.rebuild_tree()
            self.phase = 3
            self.reset_test()
        elif b.action == "root" and b.value:
            self.root_feature = b.value
            self.rebuild_tree()
        elif b.action == "yes":
            self.yes_feature = None if b.value == "none" else b.value
            self.rebuild_tree()
        elif b.action == "no":
            self.no_feature = None if b.value == "none" else b.value
            self.rebuild_tree()
        elif b.action == "reset_tree":
            self.root_feature, self.yes_feature, self.no_feature = "horns", None, "wings"
            self.rebuild_tree()
        elif b.action == "predict" and self.prediction is None:
            m = TEST_DATA[self.test_index]
            self.prediction, self.path = self.tree.predict(m)
            if self.test_index not in self.answered:
                self.score += int(self.prediction == m.label)
                self.answered.add(self.test_index)
        elif b.action == "next" and self.prediction is not None and self.test_index < len(TEST_DATA) - 1:
            self.test_index += 1
            self.prediction = None
            self.path = []

    def click(self, pos: Tuple[int, int]) -> None:
        self.build_buttons()
        for b in self.buttons:
            if b.rect.collidepoint(pos):
                self.handle_button(b)
                return
        if self.phase == 1:
            for i in range(len(TRAINING)):
                if self.card_rect(i).collidepoint(pos):
                    self.selected_training = i
                    return

    def draw(self) -> None:
        self.canvas.fill(BG)
        self.header()
        if self.phase == 1:
            self.phase1()
        elif self.phase == 2:
            self.phase2()
        else:
            self.phase3()
        self.build_buttons()
        for b in self.buttons:
            b.draw(self.canvas, self.small, self.tiny)
        self.display.blit(self.canvas, (0, 0))
        pygame.display.flip()

    def loop(self) -> None:
        while True:
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    pygame.quit()
                    sys.exit()
                if event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE:
                    pygame.quit()
                    sys.exit()
                if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
                    self.click(event.pos)
            self.draw()
            self.clock.tick(FPS)


if __name__ == "__main__":
    Game().loop()
