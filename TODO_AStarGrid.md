from pathlib import Path



content = r"""# TODO: AStarGrid2D für Enemy-Navigation in Survi2



> Ziel: `AStarGrid2D` wird \*\*für Enemies\*\* eingeführt.  

> Der Player behält sein bestehendes tile-basiertes Movement. `player\_movement.gd` soll für diese Umstellung nicht auf AStar umgebaut werden.



\## Zielbild



Die Navigation soll am Ende so aufgebaut sein:



```text

MapGenerator

&#x20;   |

&#x20;   v

Map.walkable\_tiles

&#x20;   |

&#x20;   v

Map / Navigation-Core

&#x20;   |

&#x20;   +-- AStarGrid2D

&#x20;   +-- statische/dynamische Blocker

&#x20;   +-- world\_to\_tile()

&#x20;   +-- tile\_to\_world()

&#x20;   +-- get\_navigation\_path()

&#x20;   +-- navigation\_revision

&#x20;   |

&#x20;   v

EnemyNavigation

&#x20;   |

&#x20;   +-- Ziel bestimmen

&#x20;   +-- Pfad nur bei Bedarf neu berechnen

&#x20;   +-- nächsten Tile-Schritt auswählen

&#x20;   +-- Tile reservieren

&#x20;   |

&#x20;   v

Enemy

&#x20;   |

&#x20;   +-- bestehende AI / Combat

&#x20;   +-- Bewegung zum nächsten Tile

&#x20;   +-- Angriff, wenn in Reichweite

```



\### Grundentscheidungen



\- \[ ] `AStarGrid2D` gehört \*\*einmal zentral zur Map\*\*, nicht einmal pro Enemy.

\- \[ ] Enemies teilen sich dasselbe Grid.

\- \[ ] Navigation ist zunächst \*\*4-Wege\*\*: oben, unten, links, rechts.

\- \[ ] `DIAGONAL\_MODE\_NEVER` verwenden.

\- \[ ] Manhattan-Heuristik verwenden.

\- \[ ] Player bleibt unverändert und wird \*\*nicht\*\* auf AStar umgestellt.

\- \[ ] Enemy-AI wird server-authoritativ ausgeführt.

\- \[ ] Enemies dürfen Pfade nicht in jedem Physics-Frame neu berechnen.

\- \[ ] Bäume, Breakables und Gebäude müssen das Grid dynamisch blockieren.

\- \[ ] Andere Enemies werden zunächst nicht als permanente `AStarGrid2D`-Solids eingetragen; für sie wird später ein Reservation-/Occupancy-System verwendet.

\- \[ ] Pfade werden als `Array\[Vector2i]` in Map-Tile-Koordinaten behandelt.

\- \[ ] Die eigentliche Darstellung/Bewegung kann weiterhin weich zwischen Tile-Zentren interpolieren.



\---



\# Phase 0 – Bestand aufnehmen und Enemy-Einstiegspunkt festlegen



\## 0.1 Enemy-Dateien identifizieren



\- \[ ] Alle Enemy-Szenen finden.

\- \[ ] Das gemeinsame Enemy-Basis-Script identifizieren.

\- \[ ] Enemy-Spawner identifizieren.

\- \[ ] Prüfen, ob alle Enemies von derselben Basis-Szene / Klasse erben.

\- \[ ] Prüfen, ob verschiedene Enemy-Typen eigene Movement-Implementierungen besitzen.

\- \[ ] Prüfen, ob Enemies `CharacterBody2D`, `Node2D` oder einen anderen Body-Typ verwenden.

\- \[ ] Prüfen, wie aktuell zum Player gelaufen wird.

\- \[ ] Prüfen, ob bereits eine Enemy-State-Machine existiert.

\- \[ ] Prüfen, wo aktuell `IDLE`, `CHASE`, `ATTACK`, `DEAD` usw. entschieden werden.

\- \[ ] Prüfen, wie der Ziel-Player im Multiplayer bestimmt wird.



\## 0.2 Bestehende Enemy-Bewegung dokumentieren



Vor dem Umbau pro Enemy-Typ festhalten:



\- \[ ] aktuelle Move-Speed

\- \[ ] aktuelle Kollisionsmethode

\- \[ ] aktuelles Chase-Verhalten

\- \[ ] aktuelle Attack-Range

\- \[ ] aktuelle Detection-Range

\- \[ ] vorhandene Animationsrichtungen

\- \[ ] Server-/Client-Verhalten

\- \[ ] Spawnposition

\- \[ ] Death/Despawn-Verhalten



\## 0.3 Scope bestätigen



Für den ersten funktionierenden Stand:



\- \[ ] Ein Enemy kann einen Player auf einer Map finden.

\- \[ ] Der Enemy kann um Wasser/Wände/Bäume herum laufen.

\- \[ ] Der Enemy läuft ausschließlich über gültige Grid-Tiles.

\- \[ ] Der Enemy berechnet den Pfad erneut, wenn der Player das Ziel-Tile ändert.

\- \[ ] Der Enemy stoppt in Angriffsreichweite.

\- \[ ] Mehrere Enemies verursachen keinen Script-Fehler.

\- \[ ] Player-Movement bleibt unverändert.



\---



\# Phase 1 – Zentrales AStarGrid2D in `scenes/map/map.gd`



\## 1.1 Navigationszustand ergänzen



In `scenes/map/map.gd` vorsehen:



```gdscript

var astar\_grid := AStarGrid2D.new()

var astar\_ready := false



var navigation\_blockers: Dictionary = {}

var navigation\_revision: int = 0

```



Optional später:



```gdscript

var navigation\_reservations: Dictionary = {}

```



\## 1.2 Grid initialisieren



Neue Funktion planen:



```gdscript

func rebuild\_navigation\_grid() -> void

```



Aufgaben der Funktion:



\- \[ ] `astar\_ready = false` setzen.

\- \[ ] altes Grid mit `clear()` zurücksetzen.

\- \[ ] `region` aus aktueller Map-Größe erstellen.

\- \[ ] `cell\_size` auf `Constants.TILE\_SIZE` setzen.

\- \[ ] `diagonal\_mode = AStarGrid2D.DIAGONAL\_MODE\_NEVER`.

\- \[ ] Compute-Heuristik auf Manhattan setzen.

\- \[ ] Estimate-Heuristik auf Manhattan setzen.

\- \[ ] `update()` \*\*einmal\*\* nach Konfiguration aufrufen.

\- \[ ] zunächst komplette Region als solid markieren.

\- \[ ] alle Tiles aus `walkable\_tiles` freigeben.

\- \[ ] danach alle registrierten dynamischen Blocker wieder sperren.

\- \[ ] `navigation\_revision += 1`.

\- \[ ] `astar\_ready = true`.



Geplanter Aufbau:



```gdscript

astar\_grid.region = Rect2i(

&#x20;   Vector2i.ZERO,

&#x20;   Vector2i(width, height)

)



astar\_grid.cell\_size = Vector2(

&#x20;   Constants.TILE\_SIZE,

&#x20;   Constants.TILE\_SIZE

)



astar\_grid.diagonal\_mode = AStarGrid2D.DIAGONAL\_MODE\_NEVER

astar\_grid.default\_compute\_heuristic = AStarGrid2D.HEURISTIC\_MANHATTAN

astar\_grid.default\_estimate\_heuristic = AStarGrid2D.HEURISTIC\_MANHATTAN



astar\_grid.update()



astar\_grid.fill\_solid\_region(astar\_grid.region, true)



for tile: Vector2i in walkable\_tiles:

&#x20;   if astar\_grid.is\_in\_boundsv(tile):

&#x20;       astar\_grid.set\_point\_solid(tile, false)

```



\## 1.3 Map-Generierung korrekt mit Navigation verbinden



Aktuell erzeugt `generateMap()` die `walkable\_tiles`.



\- \[ ] `walkable\_tiles` vor jeder neuen Generierung leeren.

\- \[ ] `spawnable\_tiles` vor jeder neuen Generierung leeren.

\- \[ ] `navigation\_blockers` bei komplett neuer Map zurücksetzen.

\- \[ ] AStar \*\*erst nach abgeschlossener Map-Generierung\*\* aufbauen.

\- \[ ] Darauf achten, dass bestehende frühe `return`-Statements den AStar-Aufbau nicht überspringen.

\- \[ ] Für jeden Map-Typ prüfen:

&#x20; - \[ ] `MAP\_MAIN`

&#x20; - \[ ] `MAP\_LABY`

&#x20; - \[ ] `MAP\_TOURMENT`

&#x20; - \[ ] `MAP\_KI`

\- \[ ] `rebuild\_navigation\_grid()` genau einmal pro vollständiger Map-Generierung ausführen.



\### Wichtig



Bei `MAP\_MAIN` gibt es aktuell einen frühen Return nach `set\_level\_options()`.  

Wenn `rebuild\_navigation\_grid()` nur ans Ende von `generateMap()` gesetzt wird, würde die Main-Map das Grid deshalb nicht aufbauen.



Lösung:



\- \[ ] Return entfernen/umbauen, \*\*oder\*\*

\- \[ ] `rebuild\_navigation\_grid()` vor dem Return aufrufen.



\## 1.4 Hilfsfunktionen in `Map`



Folgende zentrale API einführen:



```gdscript

func world\_to\_navigation\_tile(global\_pos: Vector2) -> Vector2i

func navigation\_tile\_to\_world(tile: Vector2i) -> Vector2

func is\_navigation\_tile\_in\_bounds(tile: Vector2i) -> bool

func is\_navigation\_tile\_walkable(tile: Vector2i) -> bool

func get\_navigation\_path(from\_tile: Vector2i, to\_tile: Vector2i) -> Array\[Vector2i]

func add\_navigation\_blocker(tile: Vector2i) -> void

func remove\_navigation\_blocker(tile: Vector2i) -> void

```



\## 1.5 Koordinaten nur an einer Stelle konvertieren



`world\_to\_navigation\_tile()` soll sich ausschließlich an `Map.tile\_map` orientieren.



Beispielkonzept:



```gdscript

func world\_to\_navigation\_tile(global\_pos: Vector2) -> Vector2i:

&#x20;   var local\_pos := tile\_map.to\_local(global\_pos)

&#x20;   return tile\_map.local\_to\_map(local\_pos)

```



`navigation\_tile\_to\_world()`:



```gdscript

func navigation\_tile\_to\_world(tile: Vector2i) -> Vector2:

&#x20;   var local\_pos := tile\_map.map\_to\_local(tile)

&#x20;   return tile\_map.to\_global(local\_pos)

```



\- \[ ] Keine Enemy-Scripte sollen eigene leicht unterschiedliche Tile-Konvertierungen implementieren.

\- \[ ] Player-Positionen immer über diese Map-Helfer in Tile-Koordinaten umwandeln.

\- \[ ] Enemy-Positionen genauso umwandeln.



\## 1.6 `get\_navigation\_path()` absichern



Vor `get\_id\_path()` prüfen:



\- \[ ] Grid ist bereit.

\- \[ ] Start liegt innerhalb der Region.

\- \[ ] Ziel liegt innerhalb der Region.

\- \[ ] Start ist nicht solid.

\- \[ ] Ziel ist nicht solid.

\- \[ ] Leerer Pfad wird sauber behandelt.

\- \[ ] Kein Crash bei Map-Wechsel.



Vorgesehene Signatur:



```gdscript

func get\_navigation\_path(

&#x20;   from\_tile: Vector2i,

&#x20;   to\_tile: Vector2i

) -> Array\[Vector2i]

```



Für MVP:



\- \[ ] `allow\_partial\_path = false`.



Später optional:



\- \[ ] Partial Path nur gezielt für spezielle AI-Zustände evaluieren.



\---



\# Phase 2 – Begehbare Tiles und Hindernisse korrekt modellieren



\## 2.1 `walkable\_tiles` als Terrain-Basis verwenden



Bestehende Generatoren liefern bereits begehbare Map-Zellen.



\- \[ ] `walkable\_tiles` bleibt die Terrain-Grundlage des Navigation-Grids.

\- \[ ] Wasser / unpassierbares Terrain bleibt solid.

\- \[ ] Labyrinth-Wände bleiben solid.

\- \[ ] Außenbereich außerhalb der Grid-Region bleibt automatisch ungültig.



\## 2.2 Baum-Problem beheben



In `main\_level.gd` werden Baum-Zellen aktuell zu `walkable\_tiles` hinzugefügt und anschließend ein Baum-Objekt darauf gespawnt.



Das ist für das Terrain sinnvoll, für aktuelle Navigation aber nicht ausreichend.



Beim Baum-Spawn:



\- \[ ] Terrain-Zelle bleibt grundsätzlich walkable.

\- \[ ] Baum registriert einen dynamischen Navigation-Blocker.

\- \[ ] Baum speichert sein `navigation\_tile`.

\- \[ ] Wird der Baum zerstört, wird der Blocker entfernt.

\- \[ ] Danach können Enemies durch die ehemals blockierte Zelle laufen.



Gewünschtes Verhalten:



```text

Gras unter Baum = walkable

Baum existiert   = AStar solid

Baum zerstört    = wieder walkable

```



\## 2.3 Blocker als Counter speichern



Nicht nur `Dictionary\[tile] = true`, sondern Blocker zählen.



Beispiel:



```gdscript

navigation\_blockers\[tile] = navigation\_blockers.get(tile, 0) + 1

```



Beim Entfernen:



```gdscript

navigation\_blockers\[tile] -= 1

```



Erst bei `<= 0` wird das Tile wieder freigegeben.



Grund:



\- \[ ] Verhindert Fehler, wenn mehrere blockierende Nodes dieselbe Zelle verwenden.

\- \[ ] Ein Objekt kann entfernt werden, ohne versehentlich einen anderen Blocker freizuschalten.



\## 2.4 Breakables integrieren



`scenes/main/objects.gd` spawnt Breakables auf `spawnable\_tiles`.



Beim Spawn:



\- \[ ] ausgewähltes `tile\_pos` separat speichern.

\- \[ ] `navigation\_tile` an Breakable übergeben.

\- \[ ] `Map.add\_navigation\_blocker(tile\_pos)` aufrufen.



Beim Zerstören:



\- \[ ] vor `queue\_free()` `Map.remove\_navigation\_blocker(navigation\_tile)` ausführen.

\- \[ ] doppelte Entfernung verhindern.



\## 2.5 Gebäude integrieren



Alle platzierbaren Gebäude prüfen.



Für jedes Gebäude:



\- \[ ] belegte Tile-Zellen bestimmen.

\- \[ ] bei erfolgreicher Platzierung Blocker registrieren.

\- \[ ] bei Abbau/Zerstörung Blocker entfernen.

\- \[ ] bei mehrteiligen Gebäuden alle belegten Tiles registrieren.

\- \[ ] Platzierung ablehnen, wenn ein benötigtes Tile bereits unpassierbar ist.

\- \[ ] `navigation\_revision` bei Änderungen erhöhen.



\## 2.6 Weitere Hindernisse inventarisieren



Prüfen und bei Bedarf integrieren:



\- \[ ] Türen

\- \[ ] Mauern

\- \[ ] Fallen

\- \[ ] Steine

\- \[ ] Kisten

\- \[ ] temporäre Hindernisse

\- \[ ] platzierbare Türme

\- \[ ] Quest-Objekte

\- \[ ] Map-Objekte mit `StaticBody2D`



\---



\# Phase 3 – `NavHelper.gd` auf die neue Navigation umstellen



\## 3.1 Bestehenden `is\_walkable()`-Fehler entfernen



Aktuell holt `NavHelper.is\_walkable()` mit:



```gdscript

tilemap.get\_cell\_atlas\_coords(tile\_pos)

```



eine Atlas-Koordinate und vergleicht diese mit `map.walkable\_tiles`.



`map.walkable\_tiles` enthält jedoch Map-Zellkoordinaten.



\- \[ ] Diese Logik entfernen.

\- \[ ] Stattdessen zentrale Map-API verwenden:



```gdscript

func is\_walkable(tile\_pos: Vector2i) -> bool:

&#x20;   return map.is\_navigation\_tile\_walkable(tile\_pos)

```



\## 3.2 `get\_neighbors()` korrigieren



Nicht nur prüfen, ob irgendein Tile existiert.



\- \[ ] Nur orthogonale Nachbarn erzeugen.

\- \[ ] `is\_navigation\_tile\_in\_bounds()` prüfen.

\- \[ ] `is\_navigation\_tile\_walkable()` prüfen.

\- \[ ] dynamische Blocker berücksichtigen.



\## 3.3 Spawn-Helfer weiterverwenden



`getNavigableTiles()` und `getNRandomNavigableTileInPlayerRadius()` können als Spawn-Helfer erhalten bleiben.



Aber:



\- \[ ] nur aktuell navigierbare Tiles zurückgeben.

\- \[ ] dynamisch blockierte Tiles ausschließen.

\- \[ ] reservierte Enemy-Tiles optional ausschließen.

\- \[ ] keine Position liefern, von der kein gültiger Pfad in den Spielbereich existiert.



\## 3.4 Verantwortung trennen



`NavHelper` soll künftig primär Helfer für:



\- Spawnpositionen

\- zufällige navigierbare Tiles

\- Radius-Abfragen



sein.



Die eigentliche AStar-Pfadberechnung gehört zu `Map`.



\---



\# Phase 4 – Wiederverwendbare Enemy-Navigation erstellen



\## 4.1 Neue EnemyNavigation-Komponente anlegen



Empfohlen:



```text

scenes/

└── enemy/

&#x20;   └── components/

&#x20;       └── enemy\_navigation.gd

```



Falls die Enemy-Struktur im Projekt anders organisiert ist:



\- \[ ] Komponente in den bestehenden Enemy-Komponentenordner legen.

\- \[ ] Nicht mehrere Kopien desselben Pathfinding-Codes in unterschiedliche Enemy-Typen schreiben.



\## 4.2 Verantwortung der Komponente



`EnemyNavigation` soll ausschließlich Navigation verwalten:



\- \[ ] Referenz auf Owner-Enemy.

\- \[ ] Referenz auf Map.

\- \[ ] aktueller Pfad.

\- \[ ] aktueller Pfadindex.

\- \[ ] aktuelles Start-Tile.

\- \[ ] aktuelles Ziel-Tile.

\- \[ ] nächstes Tile.

\- \[ ] Repath-Timer.

\- \[ ] Navigation-Revision des zuletzt berechneten Pfads.

\- \[ ] Reservation des nächsten Tiles.

\- \[ ] Status, ob aktuell ein gültiger Pfad existiert.



Nicht dort hinein:



\- Damage

\- HP

\- Loot

\- Attack-Logik

\- Animationen

\- Drop-System

\- Player-Input



\## 4.3 Vorgesehene Daten



```gdscript

var current\_path: Array\[Vector2i] = \[]

var path\_index: int = 0



var target\_tile: Vector2i

var last\_target\_tile: Vector2i



var repath\_timer: float = 0.0

var last\_navigation\_revision: int = -1



var path\_active: bool = false

```



Exports:



```gdscript

@export var repath\_interval: float = 0.25

@export var tile\_reached\_distance: float = 2.0

```



\## 4.4 Vorgesehene API



```gdscript

func set\_target(target: Node2D) -> void

func clear\_target() -> void



func request\_path(force: bool = false) -> bool

func needs\_repath() -> bool



func get\_next\_tile() -> Vector2i

func get\_next\_world\_position() -> Vector2



func notify\_tile\_reached(tile: Vector2i) -> void

func cancel\_path() -> void

```



Optional:



```gdscript

signal path\_changed(path: Array\[Vector2i])

signal path\_failed()

signal destination\_reached()

```



\---



\# Phase 5 – Einen Enemy vollständig auf AStar umstellen



\## 5.1 Erst nur einen Enemy-Typ migrieren



\- \[ ] Einen einfachen Enemy als Referenz auswählen.

\- \[ ] Noch nicht alle Enemy-Typen gleichzeitig ändern.

\- \[ ] Bestehende Combat-/HP-Logik unangetastet lassen.

\- \[ ] Nur Chase-/Movement-Teil ersetzen.



\## 5.2 AI-State sauber trennen



Empfohlene Zustände:



```text

IDLE

DETECT

CHASE

ATTACK

BLOCKED

DEAD

```



Minimal:



\- \[ ] `IDLE`: keine Navigation.

\- \[ ] `CHASE`: Pfad zum Player/Attack-Tile verfolgen.

\- \[ ] `ATTACK`: stehen bleiben und bestehende Attack-Logik ausführen.

\- \[ ] `DEAD`: Navigation sofort stoppen und Reservation freigeben.



\## 5.3 Player als Ziel bestimmen



Bei Singleplayer:



\- \[ ] aktiven Player referenzieren.



Bei Multiplayer:



\- \[ ] Server bestimmt den Ziel-Player.

\- \[ ] zunächst den nächstgelegenen lebenden Player verwenden.

\- \[ ] optional nur Player innerhalb Detection-Range berücksichtigen.

\- \[ ] Target nicht auf Clients separat bestimmen.



\## 5.4 Ziel-Tile nicht blind auf Player-Tile setzen



Wenn Enemies Kontakt-Angriffe besitzen, ist es meist besser, auf ein benachbartes Tile zu laufen.



Neue Map-/Enemy-Hilfe planen:



```gdscript

func get\_attack\_destination(

&#x20;   enemy\_tile: Vector2i,

&#x20;   player\_tile: Vector2i

) -> Vector2i

```



Kandidaten:



```text

player + LEFT

player + RIGHT

player + UP

player + DOWN

```



Dann:



\- \[ ] nur walkable Kandidaten berücksichtigen.

\- \[ ] reservierte Kandidaten möglichst vermeiden.

\- \[ ] Kandidat mit kürzestem gültigem Pfad wählen.

\- \[ ] Enemy stoppt auf Attack-Tile.

\- \[ ] Player-Tile bleibt frei für den Player.



Für einen Enemy, der direkt denselben Tile betreten darf:



\- \[ ] Verhalten pro Enemy-Typ konfigurierbar machen.



\## 5.5 AStar nur für Richtungsentscheidung nutzen



Der Pfad sieht z. B. so aus:



```text

\[(5,5), (6,5), (7,5), (7,6), (8,6)]

```



Enemy bewegt sich nur zum aktuellen nächsten Tile:



```text

Enemy World Position

&#x20;       |

&#x20;       v

Tile (5,5)

&#x20;       |

&#x20;       v

next = (6,5)

&#x20;       |

&#x20;       v

map.navigation\_tile\_to\_world((6,5))

&#x20;       |

&#x20;       v

physische Bewegung

```



\## 5.6 Bewegung zwischen Tile-Zentren



Nicht teleportieren.



\- \[ ] `next\_world\_position` bestimmen.

\- \[ ] Enemy mit bestehender Physics-Methode dorthin bewegen.

\- \[ ] bei Erreichen auf exakte Tile-Mitte korrigieren.

\- \[ ] `notify\_tile\_reached()` aufrufen.

\- \[ ] nächsten Pfadpunkt verwenden.



Beispielrichtung:



```gdscript

var direction := (

&#x20;   next\_world\_position - enemy.global\_position

).normalized()

```



\## 5.7 Richtungsanimation ableiten



Aus Differenz:



```gdscript

var tile\_delta := next\_tile - current\_tile

```



Zuordnung:



```text

( 1, 0) -> right

(-1, 0) -> left

( 0, 1) -> down

( 0,-1) -> up

```



\- \[ ] vorhandene Walk-Animationen damit ansteuern.

\- \[ ] beim Stoppen Idle-Animation setzen.

\- \[ ] keine Diagonal-Animation für MVP nötig.



\---



\# Phase 6 – Repathing richtig implementieren



\## 6.1 Nicht jeden Frame `get\_id\_path()` aufrufen



Pfad nur neu berechnen wenn mindestens eine Bedingung erfüllt ist:



\- \[ ] noch kein Pfad vorhanden.

\- \[ ] Player hat das Ziel-Tile geändert.

\- \[ ] `repath\_interval` ist abgelaufen.

\- \[ ] aktueller nächster Schritt wurde blockiert.

\- \[ ] `navigation\_revision` hat sich geändert.

\- \[ ] Enemy wurde verschoben/teleportiert.

\- \[ ] Enemy ist vom erwarteten Pfad abgekommen.

\- \[ ] Reservation schlägt längere Zeit fehl.



\## 6.2 `navigation\_revision` verwenden



In `Map`:



```gdscript

var navigation\_revision: int = 0

```



Erhöhen bei:



\- \[ ] Grid komplett neu gebaut.

\- \[ ] Baum hinzugefügt/entfernt.

\- \[ ] Breakable hinzugefügt/entfernt.

\- \[ ] Gebäude hinzugefügt/entfernt.

\- \[ ] Tür geöffnet/geschlossen.

\- \[ ] sonstigen Laufbarkeitsänderungen.



Enemy speichert beim Pathfinding:



```gdscript

last\_navigation\_revision = map.navigation\_revision

```



Wenn:



```gdscript

last\_navigation\_revision != map.navigation\_revision

```



darf neu geplant werden.



\## 6.3 Repath-Interval staffeln



Startwert:



```text

0.20 bis 0.35 Sekunden

```



\- \[ ] Nicht alle Enemies exakt im selben Frame repathen lassen.

\- \[ ] kleinen zufälligen Offset pro Enemy verwenden.

\- \[ ] Zieländerung um genau ein Tile darf sofortigen Repath auslösen.

\- \[ ] unnötige Repaths bei unverändertem Target vermeiden.



\---



\# Phase 7 – Dynamische Enemy-Belegung / Tile-Reservation



\## 7.1 Enemies nicht dauerhaft als AStar-Solids behandeln



Für den gemeinsamen AStar-Graphen:



\- \[ ] Terrain und echte Hindernisse = AStar solids.

\- \[ ] andere bewegliche Enemies = \*\*keine permanenten AStar solids\*\*.



Grund:



Wenn jeder Enemy bei jedem Schritt das gemeinsame Grid mutiert, beeinflussen sich gleichzeitig laufende Path-Queries unnötig stark.



\## 7.2 Reservation-System in `Map`



Vorbereiten:



```gdscript

var navigation\_reservations: Dictionary = {}

```



API:



```gdscript

func try\_reserve\_navigation\_tile(

&#x20;   tile: Vector2i,

&#x20;   actor\_id: int

) -> bool



func release\_navigation\_tile(

&#x20;   tile: Vector2i,

&#x20;   actor\_id: int

) -> void



func is\_navigation\_tile\_reserved(

&#x20;   tile: Vector2i,

&#x20;   except\_actor\_id: int = -1

) -> bool

```



\## 7.3 Enemy-Step reservieren



Vor Bewegung zum nächsten Tile:



\- \[ ] Enemy fragt Reservation an.

\- \[ ] wenn frei -> reservieren und bewegen.

\- \[ ] wenn belegt -> warten.

\- \[ ] nach Timeout neuen Pfad berechnen.

\- \[ ] vorherige Reservation nach abgeschlossenem Schritt freigeben.

\- \[ ] bei Death/Despawn alle Reservations freigeben.



\## 7.4 Head-on-Swap vermeiden



Fall:



```text

A -> <- B

```



\- \[ ] aktuellen Tile und Next-Tile beider Enemies berücksichtigen.

\- \[ ] direkten Swap im selben Tick verhindern.

\- \[ ] deterministische Priorität verwenden, z. B. kleinere `instance\_id`.

\- \[ ] Verlierer wartet einen Repath-Zyklus.



\## 7.5 Gruppenbildung zulassen



Für viele Gegner am Player:



\- \[ ] mehrere Attack-Tiles um den Player verteilen.

\- \[ ] bereits reservierte Attack-Tiles meiden.

\- \[ ] Enemy darf ein alternatives Nachbar-Tile wählen.

\- \[ ] später optional zweite Ringdistanz für große Gruppen.



\---



\# Phase 8 – Enemy-Spawning an Navigation koppeln



\## 8.1 Spawn nur auf gültigem Tile



Spawner muss prüfen:



\- \[ ] Tile liegt im Navigation-Grid.

\- \[ ] Tile ist nicht solid.

\- \[ ] Tile ist nicht dynamisch blockiert.

\- \[ ] Tile ist nicht bereits von Enemy reserviert.

\- \[ ] Tile liegt nicht direkt auf Player.

\- \[ ] Spawnposition ist Tile-Zentrum.



\## 8.2 Bestehenden `NavHelper` dafür nutzen



`getNRandomNavigableTileInPlayerRadius()` darf weiter als Basis dienen, nachdem Phase 3 abgeschlossen ist.



Zusätzlich:



\- \[ ] bei mehreren Spawnversuchen Duplikate verhindern.

\- \[ ] maximalen Retry-Count einführen.

\- \[ ] bei keiner gültigen Position sauber abbrechen.

\- \[ ] keine Endlosschleife.



\## 8.3 Spawn und AStar-Start synchronisieren



Nach Enemy-Spawn:



\- \[ ] Enemy auf Tile-Mitte setzen.

\- \[ ] aktuelle Tile-Position initialisieren.

\- \[ ] Reservation des Start-Tiles setzen, falls Reservation-System schon aktiv.

\- \[ ] erste Path-Query nicht vor fertiger Map-Navigation ausführen.



\---



\# Phase 9 – Multiplayer / Server Authority



\## 9.1 Pathfinding nur auf dem Server



Enemy-AI:



```gdscript

if not multiplayer.is\_server():

&#x20;   return

```



an geeigneter zentraler Stelle absichern.



\- \[ ] nur Server wählt Targets.

\- \[ ] nur Server berechnet AStar-Pfade.

\- \[ ] nur Server entscheidet über Reservations.

\- \[ ] nur Server löst Enemy-Attacken aus.

\- \[ ] Clients berechnen keine konkurrierende Enemy-AI.



\## 9.2 Nicht komplette Pfade replizieren



Nicht nötig:



```text

Server -> sendet Array\[Vector2i] für jeden Pfad -> Client

```



Stattdessen:



\- \[ ] Server synchronisiert Enemy-Position.

\- \[ ] Server synchronisiert nötigen AI-/Animationszustand.

\- \[ ] vorhandene `MultiplayerSynchronizer`-Struktur prüfen.

\- \[ ] Clients interpolieren/rendern nur.

\- \[ ] Attack/Hit weiterhin server-authoritativ behandeln.



\## 9.3 Dynamische Blocker serverseitig verwalten



\- \[ ] Baum-Zerstörung erfolgt authoritative.

\- \[ ] Breakable-Zerstörung erfolgt authoritative.

\- \[ ] Gebäudeplatzierung erfolgt authoritative.

\- \[ ] Server aktualisiert sein Navigation-Grid sofort.

\- \[ ] Clients müssen AStar-Grid nicht zwingend identisch pflegen, solange nur Server AI berechnet.



Für Debugging optional:



\- \[ ] Clients dürfen lokal dasselbe Grid aufbauen, aber nicht für Gameplay-Entscheidungen verwenden.



\## 9.4 Multiplayer-Tests



Testfälle:



\- \[ ] Host + 1 Client.

\- \[ ] Enemy verfolgt Host.

\- \[ ] Enemy verfolgt Client.

\- \[ ] Target-Wechsel Host -> Client.

\- \[ ] Client fällt Baum; Server-Navigation wird aktualisiert.

\- \[ ] Client baut Hindernis; Enemy plant neu.

\- \[ ] Client verlässt Spiel; Enemy verliert Target sauber.

\- \[ ] keine doppelte Enemy-Bewegung auf Client und Server.



\---



\# Phase 10 – Combat mit Navigation verbinden



\## 10.1 Chase und Attack sauber trennen



Enemy läuft nur solange:



```text

distance / tile distance > attack range

```



Bei erreichter Attack-Position:



\- \[ ] Navigation stoppen.

\- \[ ] Reservation passend halten oder freigeben.

\- \[ ] Enemy zum Player ausrichten.

\- \[ ] vorhandene Attack-Logik ausführen.



\## 10.2 Player bewegt sich während Attack



Wenn Player das Tile wechselt:



\- \[ ] Attack abbrechen, falls außer Reichweite.

\- \[ ] neues Attack-Ziel bestimmen.

\- \[ ] neuen Pfad planen.

\- \[ ] CHASE-State aktivieren.



\## 10.3 Unerreichbarer Player



Wenn kein Pfad existiert:



\- \[ ] kein permanentes Spam-Repath pro Frame.

\- \[ ] Enemy geht in `BLOCKED` oder wartet.

\- \[ ] Retry erst nach Delay oder Navigation-Revision.

\- \[ ] optional nächstes erreichbares Patrouillen-Tile suchen.

\- \[ ] keine Bewegung direkt durch Collision als Fallback.



\---



\# Phase 11 – Debugging-Werkzeuge



\## 11.1 Navigation-Debugmodus



Globale Debug-Option:



```gdscript

var debug\_navigation := false

```



Optional anzeigen:



\- \[ ] aktuelle Enemy-Tile-Position.

\- \[ ] Ziel-Tile.

\- \[ ] vollständigen AStar-Pfad.

\- \[ ] nächsten Schritt.

\- \[ ] solid Tiles.

\- \[ ] dynamische Blocker.

\- \[ ] reservierte Tiles.

\- \[ ] Navigation-Revision.



\## 11.2 Enemy-Pfad zeichnen



Für Entwicklung optional pro ausgewähltem Enemy `Line2D` verwenden.



\- \[ ] Pfad nur im Debugmodus zeichnen.

\- \[ ] Map-Tiles in World-Positionen konvertieren.

\- \[ ] keine Debug-Lines im Release standardmäßig aktiv.



\## 11.3 Sinnvolle Warnungen



Nur bei echten Fehlern loggen:



```text

Enemy start tile outside navigation region

Enemy start tile is solid

Target tile is solid

No path found

Navigation grid not ready

Reservation leak detected

```



\- \[ ] nicht in jedem Physics-Frame denselben Fehler ausgeben.

\- \[ ] Fehlermeldungen throttlen oder nur bei Zustandsänderung schreiben.



\---



\# Phase 12 – Performance



\## 12.1 Shared Grid



\- \[ ] genau ein `AStarGrid2D` pro aktiver Map.

\- \[ ] kein Grid pro Enemy.

\- \[ ] `rebuild\_navigation\_grid()` nicht während normalem Enemy-Chase aufrufen.

\- \[ ] bei einzelnen Hindernissen nur `set\_point\_solid()` verwenden.



\## 12.2 Pathfinding-Frequenz begrenzen



Startwerte evaluieren:



```text

1 Enemy:      0.10–0.20 s Repath möglich

10 Enemies:   \~0.20 s

50 Enemies:   \~0.25–0.40 s

100 Enemies:  stärker staffeln / profilieren

```



Nicht blind übernehmen:



\- \[ ] Godot Profiler verwenden.

\- \[ ] CPU-Zeit für AI messen.

\- \[ ] Path-Query-Anzahl pro Sekunde messen.



\## 12.3 Repath-Trigger statt Polling bevorzugen



Repath möglichst nur bei:



\- Player-Tile geändert

\- Navigation geändert

\- Next-Tile blockiert

\- Path leer

\- Stuck erkannt



\## 12.4 Optionaler Path-Cache



Erst implementieren, wenn Profiling einen Bedarf zeigt.



Möglicher Key:



```text

from\_tile

to\_tile

navigation\_revision

```



\- \[ ] Cache invalidieren, wenn `navigation\_revision` steigt.

\- \[ ] maximale Größe definieren.

\- \[ ] kein Cache als Phase-1-Anforderung.



\## 12.5 Keine Threads für dasselbe Grid einführen



Für MVP:



\- \[ ] Pathfinding auf Main Thread.

\- \[ ] Repaths verteilen.



Threading nur später evaluieren und nicht dasselbe `AStarGrid2D` ungeschützt parallel verwenden.



\---



\# Phase 13 – Testmatrix



\## 13.1 Map-Basistests



\### Main Map



\- \[ ] Enemy kann über Gras laufen.

\- \[ ] Enemy läuft nicht durch Wasser.

\- \[ ] Enemy läuft nicht durch Bäume.

\- \[ ] nach Baumzerstörung kann Enemy durch das freigewordene Tile laufen.

\- \[ ] Breakables werden umgangen.

\- \[ ] nach Breakable-Zerstörung wird Tile freigegeben.

\- \[ ] Gebäude werden umgangen.



\### Labyrinth



\- \[ ] Enemy bleibt innerhalb von Gängen.

\- \[ ] Enemy läuft nicht durch Wände.

\- \[ ] Enemy findet längeren Weg um Sackgassen.

\- \[ ] Enemy erreicht Player am Labyrinth-Ziel.



\### Tourment



\- \[ ] Grid passt zur generierten Map-Größe.

\- \[ ] Seed ändert Navigation nicht inkonsistent.



\### KI Map



\- \[ ] Map-Generierung liefert gültige `walkable\_tiles`.

\- \[ ] AStar wird nach Generierung korrekt aufgebaut.

\- \[ ] bestehende `generateMainMap()`-Parameter/Return-Werte prüfen.



\## 13.2 Pathfinding-Grenzfälle



\- \[ ] Start == Ziel.

\- \[ ] Ziel außerhalb der Map.

\- \[ ] Start außerhalb der Map.

\- \[ ] Start ist solid.

\- \[ ] Ziel ist solid.

\- \[ ] kein Pfad vorhanden.

\- \[ ] nur ein möglicher Weg.

\- \[ ] sehr langer Pfad.

\- \[ ] Hindernis erscheint während Enemy läuft.

\- \[ ] Hindernis verschwindet während Enemy läuft.

\- \[ ] Map-Wechsel während Enemies existieren.

\- \[ ] Enemy stirbt während eines Pfads.

\- \[ ] Ziel-Player despawnt.



\## 13.3 Multi-Enemy-Tests



\- \[ ] 2 Enemies im engen Gang.

\- \[ ] 2 Enemies laufen aufeinander zu.

\- \[ ] 5 Enemies jagen denselben Player.

\- \[ ] 20 Enemies jagen denselben Player.

\- \[ ] Enemies verteilen sich auf Attack-Tiles.

\- \[ ] keine dauerhafte Reservation nach Death.

\- \[ ] keine Reservation nach `queue\_free()`.

\- \[ ] kein Enemy steht dauerhaft in anderem Enemy fest.



\## 13.4 Multiplayer-Tests



\- \[ ] Dedicated/Host-Server verhält sich gleich.

\- \[ ] Client sieht dieselbe Enemy-Position.

\- \[ ] kein Client berechnet eigene autoritative Pfade.

\- \[ ] Player-Wechsel wird korrekt erkannt.

\- \[ ] dynamische Hindernisse replizieren korrekt.

\- \[ ] Enemy-Attacke kommt nur einmal.



\---



\# Phase 14 – Alte Enemy-Navigation entfernen



Erst wenn ein Enemy mit AStar vollständig funktioniert:



\- \[ ] alten Direct-Chase-Code entfernen.

\- \[ ] alte manuelle Hindernis-Umgehung entfernen.

\- \[ ] doppelte Walkability-Prüfungen entfernen.

\- \[ ] doppelte Tile-Konvertierungen entfernen.

\- \[ ] alte experimentelle Navigation in Enemy-Scripten entfernen.

\- \[ ] `NavHelper` nur für seine verbleibende Aufgabe behalten.

\- \[ ] unbenutzte Konstanten wie alte `WALKABLE\_TILES` prüfen/entfernen.

\- \[ ] Kommentare aktualisieren.



\---



\# Phase 15 – Auf alle Enemy-Typen ausrollen



Nach erfolgreichem Referenz-Enemy:



\- \[ ] gemeinsame Navigation in Enemy-Basis integrieren.

\- \[ ] Melee-Enemy migrieren.

\- \[ ] Ranged-Enemy migrieren.

\- \[ ] Spezialgegner migrieren.

\- \[ ] Boss-Gegner nur migrieren, wenn deren Movement Grid-basiert sein soll.

\- \[ ] Tiere/NPCs separat entscheiden; nicht automatisch übernehmen.



Pro Enemy-Typ konfigurieren:



```text

move\_speed

detection\_range

attack\_range

repath\_interval

can\_chase

can\_use\_diagonal = false

preferred\_attack\_distance

```



\---



\# Phase 16 – Optional: gewichtete Tiles



Nicht für MVP nötig.



Später kann `AStarGrid2D.set\_point\_weight\_scale()` verwendet werden.



Mögliche Nutzung:



\- \[ ] Enemy bevorzugt Straße.

\- \[ ] Enemy vermeidet Schlamm.

\- \[ ] Enemy vermeidet gefährliche Fallen.

\- \[ ] unterschiedliche Enemy-Typen brauchen unterschiedliche Kosten.



Achtung:



Ein gemeinsames `AStarGrid2D` hat gemeinsame Weight-Scales.  

Wenn unterschiedliche Enemy-Klassen komplett unterschiedliche Terrainkosten benötigen, Architektur vorher prüfen.



\---



\# Phase 17 – Optional: besseres Gruppenverhalten



Nach funktionierender Basis:



\- \[ ] Attack-Slots um Player.

\- \[ ] Stau-Auflösung.

\- \[ ] lokale Ausweichlogik.

\- \[ ] unterschiedliche Chase-Radien.

\- \[ ] Gegner-Flanking.

\- \[ ] Abstand für Ranged Enemies.

\- \[ ] Flee-/Retreat-Ziele.

\- \[ ] Patrol-Ziele über AStar.

\- \[ ] Return-to-spawn über AStar.

\- \[ ] Noise-/Aggro-Ziele über AStar.



\---



\# Betroffene Dateien



\## Sicher / sehr wahrscheinlich zu ändern



| Datei | Änderung |

|---|---|

| `scenes/map/map.gd` | zentrales `AStarGrid2D`, Path-API, Blocker, Revision, später Reservations |

| `scenes/map/mapGenerator/main\_level.gd` | Bäume als dynamische Blocker registrieren |

| `scenes/main/NavHelper.gd` | Walkability auf zentrale Map-Navigation umstellen |

| `scenes/main/objects.gd` | Breakable-Tiles beim Spawn als Blocker registrieren |

| `scenes/spawn/object/tree.\*` | Navigation-Tile speichern und bei Zerstörung freigeben |

| `scenes/spawn/object/breakable.\*` | Navigation-Tile speichern und bei Zerstörung freigeben |

| Gebäude-Script(s) | belegte Tiles registrieren/freigeben |

| Enemy-Basis-/Movement-Script(s) | Chase auf `EnemyNavigation` umstellen |

| Enemy-Spawner | nur gültige navigierbare Spawn-Tiles verwenden |



\## Neu empfohlen



```text

scenes/enemy/components/enemy\_navigation.gd

```



Falls die bestehende Enemy-Struktur an einer anderen Stelle liegt, dort entsprechend einordnen.



\## Bewusst nicht Teil dieses Umbaus



```text

scenes/character/components/player\_movement.gd

```



Player bleibt bei seinem bestehenden Movement.



\---



\# Empfohlene Implementierungsreihenfolge



\## Commit 1 – Navigation Core



\- \[ ] `AStarGrid2D` in `Map`.

\- \[ ] `rebuild\_navigation\_grid()`.

\- \[ ] Koordinaten-Helfer.

\- \[ ] `get\_navigation\_path()`.

\- \[ ] Debug-Test mit zwei festen Tiles.



\*\*Definition of Done:\*\*  

Ein Pfad kann auf Main Map und Labyrinth per Debug-Code korrekt ausgegeben werden.



\## Commit 2 – Dynamische Hindernisse



\- \[ ] Navigation-Blocker-API.

\- \[ ] Bäume.

\- \[ ] Breakables.

\- \[ ] Gebäude.

\- \[ ] `navigation\_revision`.



\*\*Definition of Done:\*\*  

Ein Debug-Pfad läuft vor Baumzerstörung um den Baum und danach durch das freigewordene Tile.



\## Commit 3 – NavHelper Cleanup



\- \[ ] `is\_walkable()` korrigieren.

\- \[ ] Neighbor-Prüfung korrigieren.

\- \[ ] Spawn-Abfragen mit Map-Navigation verbinden.



\*\*Definition of Done:\*\*  

Enemy-Spawns landen nur auf tatsächlich navigierbaren Tiles.



\## Commit 4 – EnemyNavigation MVP



\- \[ ] neue Komponente.

\- \[ ] Path speichern.

\- \[ ] Next-Tile bestimmen.

\- \[ ] Repath-Interval.

\- \[ ] einen Referenz-Enemy integrieren.



\*\*Definition of Done:\*\*  

Ein Enemy findet einen stillstehenden Player zuverlässig um Hindernisse herum.



\## Commit 5 – Bewegliches Ziel / Combat



\- \[ ] Ziel-Tile-Wechsel erkennen.

\- \[ ] Attack-Destination.

\- \[ ] Chase/Attack-State.

\- \[ ] Blocked-State.



\*\*Definition of Done:\*\*  

Enemy verfolgt einen laufenden Player und stoppt in Attack-Range.



\## Commit 6 – Multi-Enemy Reservation



\- \[ ] Tile-Reservations.

\- \[ ] Freigabe bei Death/Despawn.

\- \[ ] Head-on-Konflikt.

\- \[ ] Attack-Slots.



\*\*Definition of Done:\*\*  

Mehrere Enemies blockieren sich nicht dauerhaft gegenseitig.



\## Commit 7 – Multiplayer



\- \[ ] AI server-only.

\- \[ ] Pathfinding server-only.

\- \[ ] Movement-Synchronisation.

\- \[ ] Target-Auswahl für mehrere Player.



\*\*Definition of Done:\*\*  

Host und Client sehen dieselben Enemy-Bewegungen ohne doppelte AI-Ausführung.



\## Commit 8 – Performance + Debug



\- \[ ] Debug-Overlay/Path.

\- \[ ] Profiler.

\- \[ ] Repath-Takt optimieren.

\- \[ ] 20/50/100 Enemy Test.



\*\*Definition of Done:\*\*  

Keine unnötige `get\_id\_path()`-Berechnung pro Physics-Frame.



\---



\# Wichtige Regeln während der Implementierung



1\. \*\*Kein AStar pro Enemy.\*\* Ein Grid gehört zur Map.

2\. \*\*Kein `update()` nach jedem Blocker.\*\* `set\_point\_solid()` reicht für einzelne Änderungen.

3\. \*\*Kein Pathfinding in jedem Physics-Frame.\*\*

4\. \*\*Player-Movement nicht mit diesem Umbau vermischen.\*\*

5\. \*\*Map-Tile-Koordinaten nicht mit Atlas-Koordinaten verwechseln.\*\*

6\. \*\*Dynamische Objekte müssen Blocker wieder freigeben.\*\*

7\. \*\*Enemy-Occupancy nicht als dauerhafte Map-Geometrie behandeln.\*\*

8\. \*\*Multiplayer-AI nur serverseitig entscheiden.\*\*

9\. \*\*Pathfinding und Combat getrennt halten.\*\*

10\. \*\*Erst einen Enemy komplett zum Laufen bringen, dann alle anderen migrieren.\*\*



\---



\# Bekannte Punkte im aktuellen Repo



\## `map.gd`



Bereits vorhanden:



\- `width`

\- `height`

\- `tile\_map`

\- `walkable\_tiles`

\- `spawnable\_tiles`

\- `enemies`

\- `animals`



Damit ist `Map` der passende Owner für das gemeinsame `AStarGrid2D`.



\## `main\_level.gd`



Aktuell:



\- Gras wird zu `walkable\_tiles` und `spawnable\_tiles` hinzugefügt.

\- Baum-Tiles werden ebenfalls zu `walkable\_tiles` hinzugefügt.

\- Danach wird ein `tree.tscn` gespawnt.



Folge:



Das Terrain unter dem Baum ist grundsätzlich begehbar, der Baum selbst muss als dynamischer Blocker modelliert werden.



\## `objects.gd`



Aktuell:



\- Breakables werden auf `spawnable\_tiles` gespawnt.

\- Das konkrete Tile wird momentan nicht dauerhaft am Objekt als Navigation-Tile gespeichert.



Folge:



Beim Spawn muss das Tile registriert und beim Zerstören wieder freigegeben werden.



\## `NavHelper.gd`



Aktuell:



```gdscript

var atlas\_coord = tilemap.get\_cell\_atlas\_coords(tile\_pos)

return atlas\_coord in map.walkable\_tiles

```



Das vermischt Atlas-Koordinaten mit Map-Zellkoordinaten.



Folge:



`is\_walkable()` muss auf die neue zentrale Navigation-API umgestellt werden.



\---



\# Definition of Done – Gesamtprojekt



Die AStar-Enemy-Navigation gilt als fertig, wenn alle folgenden Punkte erfüllt sind:



\- \[ ] `AStarGrid2D` wird nach jeder Map-Generierung korrekt aufgebaut.

\- \[ ] Enemies verwenden AStar, Player nicht.

\- \[ ] Main Map funktioniert.

\- \[ ] Labyrinth funktioniert.

\- \[ ] Tourment funktioniert.

\- \[ ] KI Map funktioniert oder ist bewusst separat dokumentiert.

\- \[ ] Wasser/Wände werden nie betreten.

\- \[ ] Bäume werden umgangen.

\- \[ ] gefällte Bäume geben Tiles frei.

\- \[ ] Breakables werden umgangen und geben Tiles nach Zerstörung frei.

\- \[ ] Gebäude aktualisieren Navigation.

\- \[ ] Enemy verfolgt beweglichen Player.

\- \[ ] Enemy stoppt in Attack-Range.

\- \[ ] kein Repath in jedem Physics-Frame.

\- \[ ] mehrere Enemies funktionieren gleichzeitig.

\- \[ ] Tile-Reservation verursacht keine Deadlocks.

\- \[ ] Death/Despawn hinterlässt keine Reservation.

\- \[ ] Multiplayer-AI läuft nur auf Server.

\- \[ ] Host und Clients sehen konsistente Enemy-Bewegung.

\- \[ ] Map-Wechsel resetten Navigation korrekt.

\- \[ ] keine Atlas-/Map-Koordinaten-Verwechslung mehr.

\- \[ ] Debugging kann Pfad/Target anzeigen.

\- \[ ] Performance wurde mit realistischen Enemy-Zahlen profiliert.

\- \[ ] alter redundanter Enemy-Chase-Code wurde entfernt.

\- \[ ] alle Enemy-Typen verwenden die gemeinsame Navigation oder sind bewusst davon ausgenommen.



\---



\# Quellen / API-Referenz



Godot 4.7 – `AStarGrid2D`:



https://docs.godotengine.org/en/4.7/classes/class\_astargrid2d.html



Relevante Projektdateien:



https://github.com/zumazui123-creator/Survi2/blob/main/scenes/map/map.gd



https://github.com/zumazui123-creator/Survi2/blob/main/scenes/map/mapGenerator/main\_level.gd



https://github.com/zumazui123-creator/Survi2/blob/main/scenes/main/NavHelper.gd



https://github.com/zumazui123-creator/Survi2/blob/main/scenes/main/objects.gd

"""



path = Path("/mnt/data/TODO.md")

path.write\_text(content, encoding="utf-8")

print(f"Erstellt: {path} ({len(content.splitlines())} Zeilen)")



