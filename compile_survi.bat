#!/usr/bin/env bash
# =========================================
# Build Script für Stable-Baselines3 + PyInstaller
# =========================================

# Pfade & Variablen
PYTHON="python"                                     # Python-Befehl (z. B. python oder py)
SCRIPT_NAME="gui.py"                                # Dein Python-Script
OUTPUT_NAME="gui.exe"                               # Gewünschter Name der ausführbaren Datei
PACKAGE="stable_baselines3"                         # Python-Paketname

# Hole den Pfad zur version.txt im stable_baselines3-Paket
VERSION_FILE=$($PYTHON -c "import $PACKAGE, os; print(os.path.join(os.path.dirname($PACKAGE.__file__), 'version.txt'))")

# Überprüfe, ob die Datei existiert
if [ ! -f "$VERSION_FILE" ]; then
    echo "Fehler: version.txt wurde nicht gefunden!"
    echo "Pfad: $VERSION_FILE"
    exit 1
fi

# Starte PyInstaller mit den Variablen
echo "Baue PyInstaller-Paket..."
pyinstaller  --add-data "$VERSION_FILE;$PACKAGE" --onefile "$SCRIPT_NAME"

# Ergebnis prüfen
if [ $? -eq 0 ]; then
    echo "✅ Build erfolgreich abgeschlossen!"
    echo "Ergebnis: dist/$OUTPUT_NAME"
else
    echo "❌ Build fehlgeschlagen!"
fi
