# Programmrätsel-Architektur

`ProgramPuzzleManager` ist der gemeinsame Coordinator. Er übernimmt genau einmal:

- Spielerscan und Tile-Wechsel
- Late-Join-Synchronisation
- HUD-Erzeugung und Multiplayer-Nachrichten
- Laden und Bereinigen aller Rätsel-Handler

Ein konkreter Rätseltyp erbt von `ProgramPuzzleHandler` und implementiert nur die benötigten Hooks:

- `load_landmarks(plans)` erzeugt seine Instanzen aus passenden Landmark-Plänen.
- `clear_handler()` entfernt Zustand, Visuals und Reservierungen.
- `server_tick(delta)` wird nur für zeitabhängige Rätsel benötigt.
- `server_observe_player(...)` reagiert auf Nähe oder Tile-Wechsel.
- `sync_peer(peer_id)` überträgt den Zustand an später beitretende Spieler.

Gemeinsame Definitionen erben von `ProgramPuzzleDefinitionBase`. Konkrete Definitionen enthalten ausschließlich Daten ihres Rätseltyps. Visuals zeigen Zustand an, entscheiden aber niemals über Erfolg oder Belohnungen.

## Vorhandene Handler

- `SequencePuzzleHandler`: nummerierte Schalter in einer Reihenfolge
- `TimedMazePuzzleHandler`: zeitbegrenztes, pro Seed erzeugtes Labyrinth
- `ItemOfferingPuzzleHandler`: Spieler-Drops in einer vorgegebenen Item-Reihenfolge

## Neuen Rätseltyp ergänzen

1. Eine Definition auf Basis von `ProgramPuzzleDefinitionBase` erstellen.
2. Falls nötig eine kleine Runtime-Instanz für veränderlichen Zustand erstellen.
3. Einen `ProgramPuzzleHandler` implementieren.
4. Den Handler als Kind von `ProgramPuzzleManager` in `map.tscn` eintragen.
5. Erfolg und Belohnungen ausschließlich auf dem Server auswerten.
6. Anzeigen über `request_peer_message(...)` an den Coordinator melden.

Ein neuer Typ benötigt dadurch keinen eigenen Spielerscan, kein eigenes HUD und keinen weiteren Eintrag im `ObjectManager`.
