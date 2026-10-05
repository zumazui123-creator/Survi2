# AStarGrid2D-Enemy-Navigation

Stand: Implementiert, statisch geprüft, Laufzeittests im Godot-Editor stehen noch aus.

## Zielbild

Die Map besitzt genau ein gemeinsames `AStarGrid2D`. Terrain und dauerhafte
Hindernisse werden dort als begehbar beziehungsweise solid abgebildet. Enemies
verwenden eine gemeinsame `EnemyNavigation`-Komponente und reservieren ihre
nächsten Tiles außerhalb des AStar-Grids. Das Player-Movement bleibt unverändert.

```text
Map-Generator
  -> Map.walkable_tiles
  -> Map.AStarGrid2D + dynamische Blocker
  -> EnemyNavigation + Occupancy/Reservations
  -> Enemy Chase/Attack
```

## Umgesetzt

### Navigation-Core

- [x] Ein zentrales `AStarGrid2D` in `scenes/map/map.gd`.
- [x] Vier-Wege-Navigation mit Manhattan-Heuristik.
- [x] Grid-Aufbau nach Main-, Labyrinth-, Tournament- und KI-Map-Generierung.
- [x] Sichere World-/Tile-Konvertierung über die aktive `TileMapLayer`.
- [x] Abgesicherte Pfadabfrage ohne Partial Paths.
- [x] `navigation_revision` für Laufbarkeitsänderungen.
- [x] Grid-Region berücksichtigt Map-Größe und tatsächlich generierte Tiles.
- [x] Map-Wechsel setzen Navigation, Belegung und Reservations zurück.
- [x] Der fehlerhafte KI-Aufruf `generateMainMap(0)` verwendet nun Leveldaten.
- [x] Breite/Höhe der Map-Ränder und Tournament-Dimensionen korrigiert.

### Dynamische Hindernisse

- [x] Wiederverwendbare Komponente `NavigationBlocker`.
- [x] Blocker werden pro Tile gezählt, damit überlappende Objekte sicher sind.
- [x] Bäume registrieren ihr Tile und geben es beim Fällen frei.
- [x] Breakables registrieren ihren 3x3-Footprint und geben ihn beim Abbau frei.
- [x] Gebäude prüfen und registrieren ihren 3x3-Footprint.
- [x] Gebäudeplatzierung auf solid, belegten oder reservierten Tiles wird abgelehnt.
- [x] Terrain-Painting aktualisiert die Navigation.
- [x] Alte dynamische Weltobjekte werden beim Map-Wechsel entfernt.

### Spawn-Helfer

- [x] `NavHelper` verwendet Map-Tile- statt Atlas-Koordinaten.
- [x] Spawn-Tiles berücksichtigen Blocker, Occupancy und Reservations.
- [x] Zufallspositionen sind eindeutig und besitzen einen Pfad zum Ziel-Player.
- [x] Enemies und World-Objekte werden auf Tile-Zentren gespawnt.
- [x] Object- und Building-`MultiplayerSpawner` zeigen auf die richtigen Container.

### EnemyNavigation

- [x] Gemeinsame Komponente unter `scenes/enemy/components/`.
- [x] Pfad, Pfadindex, Ziel-Tile, Repath-Timer und Navigation-Revision.
- [x] Repath bei Ziel-Tile-Wechsel, Grid-Änderung, blockiertem Schritt oder Stuck.
- [x] Kein Pathfinding in jedem Physics-Frame.
- [x] Gestaffeltes Repath-Intervall pro Enemy.
- [x] Weiche Bewegung zwischen Tile-Zentren.
- [x] Attack-Destinationen abhängig von der Attack-Range.
- [x] Alternative Attack-Slots werden über Destination-Claims verteilt.
- [x] `IDLE`, `CHASE`, `ATTACK`, `BLOCKED` und `DEAD`.
- [x] Alte direkte Gerade-zum-Player-Bewegung entfernt.
- [x] Nicht mehr verwendeten `NavigationAgent2D` entfernt.

### Multi-Enemy und Multiplayer

- [x] Separate Occupancy-, Step-Reservation- und Destination-Tabellen.
- [x] Keine beweglichen Enemies als permanente AStar-Solids.
- [x] Head-on-Swaps werden durch belegte Start-/Ziel-Tiles verhindert.
- [x] Reservations werden nach Schritt, Repath, Tod und Despawn freigegeben.
- [x] Target-Auswahl, Pathfinding, Bewegung und Angriff laufen nur auf dem Server.
- [x] Position, Target-ID, HP, Rotation, Enemy-ID und AI-State werden repliziert.
- [x] Fallback auf den nächsten vorhandenen Player, wenn das Ziel despawnt.

### Debugging

- [x] `Map.debug_navigation` schaltet Pfadlinien und Zielpunkte ein.
- [x] `Map.navigation_path_queries` zählt Pfadabfragen seit Map-Aufbau.
- [x] `Map.debug_print_path(from_tile, to_tile)` für feste Testpfade.

## Noch im Godot-Editor testen

Ein Godot-Executable war in der Implementierungsumgebung nicht verfügbar. Diese
Checks müssen deshalb vor dem nächsten Release manuell ausgeführt werden.

### Map- und Hindernistests

- [ ] Main Map: Wasser wird gemieden, Bäume und Breakables werden umlaufen.
- [ ] Baum/Breakable zerstören: Das freigegebene Tile wird beim nächsten Repath genutzt.
- [ ] Gebäude platzieren/zerstören: kompletter 3x3-Footprint wird aktualisiert.
- [ ] Labyrinth: Enemy bleibt in Gängen und findet Wege um Sackgassen.
- [ ] Tournament und KI Map: Grid wird mit der erwarteten Größe aufgebaut.
- [ ] Map-Wechsel: keine alten Enemies, Blocker oder Reservations bleiben zurück.

### Enemy- und Gruppentests

- [ ] Stillstehenden und laufenden Player verfolgen.
- [ ] Melee- und Ranged-Enemy stoppen in ihrer jeweiligen Attack-Range.
- [ ] Zwei Enemies im engen Gang verursachen keinen dauerhaften Deadlock.
- [ ] Fünf Enemies verteilen sich auf verschiedene Attack-Slots.
- [ ] Tod/Despawn während eines Schritts hinterlässt keine Reservation.
- [ ] Unerreichbares Ziel erzeugt kein Repath-/Log-Spam.

### Multiplayer- und Performancetests

- [ ] Host plus ein Client: nur der Server bewegt und attackiert mit Enemies.
- [ ] Enemy kann Host und Client als Ziel verfolgen und nach Despawn wechseln.
- [ ] Client-Aktion an Baum/Gebäude aktualisiert das serverseitige Grid.
- [ ] Position und AI-State stimmen auf Host und Client überein.
- [ ] Profiler-Läufe mit 20, 50 und 100 Enemies.
- [ ] `navigation_path_queries` beobachten und Repath-Intervall bei Bedarf justieren.

## Bewusst nicht Teil des Umbaus

- Player-Movement auf AStar umstellen.
- Tiere/NPCs automatisch auf EnemyNavigation migrieren.
- Gewichtete Tiles oder unterschiedliche Terrainkosten pro Enemy-Klasse.
- Threaded Pathfinding oder ein Path-Cache ohne vorheriges Profiling.

## Relevante Dateien

- `scenes/map/map.gd`
- `scenes/map/mapGenerator/main_level.gd`
- `scenes/map/mapGenerator/labyrinth.gd`
- `scenes/navigation/navigation_blocker.gd`
- `scenes/enemy/components/enemy_navigation.gd`
- `scenes/enemy/enemy.gd`
- `scenes/main/NavHelper.gd`
- `scenes/main/spawn_enemies.gd`
- `scenes/main/objects.gd`
- `scenes/main/buildings.gd`

API-Referenz: <https://docs.godotengine.org/en/4.7/classes/class_astargrid2d.html>
