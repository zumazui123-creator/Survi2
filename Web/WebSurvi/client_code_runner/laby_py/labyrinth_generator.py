import random
from collections import deque

class LabyrinthGenerator:
    """
    Generiert ein zufälliges Labyrinth, platziert Start/Ziel und findet den kürzesten Weg.

    Attribute:
        breite (int): Die Breite des Labyrinths.
        hoehe (int): Die Höhe des Labyrinths.
        labyrinth (list): Das 2D-Array, das das Labyrinth darstellt.
        start_x, start_y (int): Koordinaten des Startpunkts 'S'.
        ziel_x, ziel_y (int): Koordinaten des Zielpunkts 'G'.
    """

    def __init__(self, breite: int, hoehe: int):
        self.breite = breite if breite % 2 != 0 else breite + 1
        self.hoehe = hoehe if hoehe % 2 != 0 else hoehe + 1
        self.labyrinth = [[0 for _ in range(self.breite)] for _ in range(self.hoehe)]
        self.start_x, self.start_y = -1, -1
        self.ziel_x, self.ziel_y = -1, -1

    def generieren(self, seed=None):
        if seed is not None:
            random.seed(seed)
        self.labyrinth = [[0 for _ in range(self.breite)] for _ in range(self.hoehe)]
        self.start_x = random.randrange(1, self.breite, 2)
        self.start_y = random.randrange(1, self.hoehe, 2)
        self.labyrinth[self.start_y][self.start_x] = 1
        self._pfade_erstellen(self.start_x, self.start_y)
        self._ziel_setzen()
        self.labyrinth[self.start_y][self.start_x] = 'S'

    def _pfade_erstellen(self, cx: int, cy: int):
        richtungen = [(0, 2), (0, -2), (2, 0), (-2, 0)]
        random.shuffle(richtungen)
        for dx, dy in richtungen:
            nx, ny = cx + dx, cy + dy
            if 0 < ny < self.hoehe - 1 and 0 < nx < self.breite - 1 and self.labyrinth[ny][nx] == 0:
                self.labyrinth[ny - dy // 2][nx - dx // 2] = 1
                self.labyrinth[ny][nx] = 1
                self._pfade_erstellen(nx, ny)

    def _ziel_setzen(self):
        begehbare_felder = []
        for y, zeile in enumerate(self.labyrinth):
            for x, zelle in enumerate(zeile):
                if zelle == 1 and not (x == self.start_x and y == self.start_y):
                    begehbare_felder.append((x, y))
        if begehbare_felder:
            self.ziel_x, self.ziel_y = random.choice(begehbare_felder)
            self.labyrinth[self.ziel_y][self.ziel_x] = 'G'

    def loesen(self):
        """
        Löst das Labyrinth mit Breitensuche (BFS), um den kürzesten Weg zu finden.
        
        Returns:
            list: Eine Liste von Koordinaten-Tupeln, die den Pfad von S nach G darstellen.
                  Gibt eine leere Liste zurück, wenn kein Pfad gefunden wird.
        """
        if self.start_x == -1 or self.ziel_x == -1:
            return []

        queue = deque([(self.start_x, self.start_y)])
        # Speichert für jede Zelle, von welcher Zelle aus sie erreicht wurde
        parent_map = { (self.start_x, self.start_y): None }
        
        while queue:
            cx, cy = queue.popleft()

            if (cx, cy) == (self.ziel_x, self.ziel_y):
                # Pfad gefunden, rekonstruieren und zurückgeben
                pfad = []
                curr = (self.ziel_x, self.ziel_y)
                while curr is not None:
                    pfad.append(curr)
                    curr = parent_map[curr]
                return pfad[::-1] # Umkehren, um den Pfad von S nach G zu erhalten

            # Nachbarn durchsuchen (oben, unten, links, rechts)
            for dx, dy in [(0, 1), (0, -1), (1, 0), (-1, 0)]:
                nx, ny = cx + dx, cy + dy

                if 0 <= nx < self.breite and 0 <= ny < self.hoehe:
                    # Prüfen, ob der Nachbar begehbar und noch nicht besucht ist
                    if self.labyrinth[ny][nx] != 0 and (nx, ny) not in parent_map:
                        parent_map[(nx, ny)] = (cx, cy)
                        queue.append((nx, ny))
        
        return [] # Kein Pfad gefunden

    def visuell_darstellen(self, pfad=None):
        """
        Erstellt eine visuell ansprechendere Darstellung des Labyrinths.
        Wenn ein Pfad angegeben wird, wird dieser ebenfalls eingezeichnet.
        
        Returns:
            list: Eine Liste von Strings, die das Labyrinth repräsentieren.
        """
        if pfad:
            # Eine Kopie des Labyrinths erstellen, um den Pfad einzuzeichnen
            temp_labyrinth = [row[:] for row in self.labyrinth]
            for x, y in pfad:
                if temp_labyrinth[y][x] == 1: # Nur leere Wege markieren
                    temp_labyrinth[y][x] = '·'
            darzustellendes_labyrinth = temp_labyrinth
        else:
            darzustellendes_labyrinth = self.labyrinth

        output_list = []
        for zeile in darzustellendes_labyrinth:
            zeile_str = ""
            for zelle in zeile:
                if zelle == 0: zeile_str += "██"
                elif zelle == 1: zeile_str += "  "
                elif zelle == 'G': zeile_str += " G"
                elif zelle == 'S': zeile_str += " S"
                elif zelle == '·': zeile_str += " ·" # Pfadpunkt
            output_list.append(zeile_str)
        return output_list

    def als_array_ausgeben(self):
        print("\nArray-Darstellung des Labyrinths:")
        for zeile in self.labyrinth:
            print(zeile)


if __name__ == "__main__":
    generator = LabyrinthGenerator(breite=31, hoehe=15)
    generator.generieren()
    
    print("--- Labyrinth wurde generiert ---")
    # Visuelle Darstellung ausgeben
    for line in generator.visuell_darstellen():
        print(line)
    generator.als_array_ausgeben()
    
    print("\n--- Suche nach dem kürzesten Pfad ---")
    loesungspfad = generator.loesen()
    
    if loesungspfad:
        print(f"Pfad gefunden! Länge: {len(loesungspfad)} Schritte.")
        # Visuelle Darstellung mit Pfad ausgeben
        print("Visuelle Darstellung des Labyrinths mit Lösungspfad:")
        for line in generator.visuell_darstellen(pfad=loesungspfad):
            print(line)
    else:
        print("Kein Pfad vom Start zum Ziel gefunden.")
