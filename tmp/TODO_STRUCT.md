# Plan zur Umstrukturierung: /scenes/character/

Dieses Dokument beschreibt die schrittweise Umstrukturierung des Verzeichnisses `/scenes/character/`.

## Ziel
Bessere Wartbarkeit, klare Trennung von Gameplay-Logik, UI-Interaktionen und Infrastruktur.

---

## Phase 1: Vorbereitung & Sicherung
- [x] Schritt 1.1: Sicherstellen, dass das Projekt in einem sauberen Git-Zustand ist.
- [x] Schritt 1.2: Vollständiges Backup des `scenes/character/` Verzeichnisses erstellen (innerhalb des Workspace).

## Phase 2: Struktur-Setup
- [x] Schritt 2.1: Neue Verzeichnisse erstellen:
    - `/scenes/character/components/` (falls noch nicht voll ausgebaut)
    - `/scenes/character/ui/`
    - `/scenes/character/items/`
- [x] Schritt 2.2: Verschieben der Dateien in die neuen Verzeichnisse laut Plan.

## Phase 3: Pfad-Aktualisierungen (Der "Brüche"-Teil)
- [x] Schritt 3.1: `player.tscn` in einem Texteditor öffnen und alle `ext_resource` Pfade zu den verschobenen Scripts korrigieren.
- [x] Schritt 3.2: `player.tscn` öffnen und die `NodePath` Referenzen innerhalb der Szenenstruktur aktualisieren, wo sie auf Scripts zeigen, die nun in Unterordnern liegen.

## Phase 4: Code-Anpassungen (Dependency Hell Fix)
- [x] Schritt 4.1: `player.gd` refactoren, um die neuen Pfade der Komponenten zu nutzen (`load` oder `preload` Pfade).
- [x] Schritt 4.2: Alle Scripte in `components/`, die sich gegenseitig referenzieren (z.B. Combat -> Animation), auf die neuen Pfade anpassen.
- [x] Schritt 4.3: Alle UI-Scripte in `ui/` auf die neuen Pfade anpassen.

## Phase 5: Validierung & Testing
- [x] Schritt 5.1: Projekt im Editor öffnen, um sicherzustellen, dass Godot keine "Script not found" Fehler meldet.
- [x] Schritt 5.2: Spiel starten und grundlegende Funktionen testen:
    - Bewegung
    - Combat
    - UI-Interaktion (Drag & Drop)
- [x] Schritt 5.3: Ggf. Fehlerbehebung.

## Phase 7: Cyber-Aura Implementierung
- [x] Schritt 7.1: `codeParticles` Node (CPUParticles2D) in `player.tscn` hinzufügen und konfigurieren.
- [x] Schritt 7.2: `CodePlayer.gd` anpassen, um `codeParticles` während der Code-Ausführung zu aktivieren, zu skalieren und danach zu deaktivieren.
- [ ] Schritt 7.3: (Ausblick) Belohnungssystem für Code-Challenges (Placeholder/System-Foundation) erstellen.

---
*Dieser Plan wird strikt sequentiell abgearbeitet.*
