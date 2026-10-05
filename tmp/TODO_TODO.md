1. Mechanische Belohnungen ("Code = Power")
   * Automatisierung (Dronen/Bots): Erlaube es, Code zu schreiben, der nicht nur den Spieler steuert, sondern Objekte sammelt oder Ressourcen
     abbaut, während der Spieler woanders ist.
   * Kampf-Combos: Wenn der Code "effizient" ist (z.B. wenig Zeilen, aber präzise Befehle), löst das spezielle Kampf-Combos aus, die mehr
     Schaden verursachen oder Gegner betäuben.
   * Sichtweite: Code könnte die Sichtweite oder die Reichweite von Interaktionen (Sammeln/Baumfällen) erhöhen.
   * "Super-Move": Ein spezieller Befehl (z. B. teleport oder aoe_attack), der nur verfügbar wird, wenn eine bestimmte Code-Länge oder
     Komplexität erreicht wurde.

  2. Visuelle Belohnungen ("Zeig es allen")
   * "Cyber-Aura": Der Spielercharakter bekommt einen visuellen Effekt (Partikel, Leuchten), der sich verändert, je mehr oder komplexeren
     Code er gerade ausführt. (Du hast schon bloodParticles, vielleicht kannst du codeParticles hinzufügen).
   * Spezielle Skins: Wenn ein Spieler eine bestimmte Anzahl an "Code-Challenges" gelöst hat, schaltet er einen einzigartigen
     "Programmierer-Skin" frei (z.B. einen Roboter-Look).
   * Visuelle Pfad-Projektion: Bevor der Code ausgeführt wird, zeichnet das Spiel eine schwache Linie auf den Boden, die zeigt, wohin die
     Spielfigur laufen wird. Das nimmt die Angst vor Fehlern.

  3. UX & Lernkurve ("Erfolgserlebnisse")
   * Auto-Completion & Snippets: Programmieren ist frustrierend, wenn man Tippfehler macht. Eine einfache Auto-Vervollständigung oder
     Drag-and-Drop-Bausteine (wie bei Scratch) machen den Einstieg viel einfacher.
   * Tutorial-Level: Kleine Inseln oder Rätsel, die man nur lösen kann, wenn man einen bestimmten Befehl lernt. Das führt den Code
     spielerisch ein, statt ihn als zusätzliche Hürde aufzubauen.
   * Funktions-Marktplatz: Im Multiplayer können Spieler ihre "besten Funktionen" in einer Datenbank speichern, die andere Spieler laden und
     nutzen können (Social Motivation).

  4. Herausforderungen & Story
   * Coding-Quests: "Rette das Dorf vor den Spinnen, indem du eine Verteidigungslinie aus Mauern programmierst."
   * Leaderboards: "Wer schafft es, den kürzesten Code für diese Strecke zu schreiben?" (Code-Golf für Kinder).
   * Wettstreit: Programmiere einen NPC, der gegen den NPC eines anderen Spielers kämpft (Auto-Battler).

  Mein Vorschlag für den nächsten Schritt:
  Die "Cyber-Aura" ist technisch am einfachsten umzusetzen und erzeugt ein starkes, sofortiges Feedback:

   1. Füge eine CPUParticles2D-Node zum Player hinzu (z. B. blaue, digitale Partikel).
   2. Aktiviere diese in CodePlayer.gd, wenn der Code läuft.
   3. Ändere die scale_amount oder color basierend auf der Zeilenanzahl.

