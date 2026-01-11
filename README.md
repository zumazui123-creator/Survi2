# Survi 2

# Game with Godot & Python AI Backend

## Function Summary

This game is developed using **Godot Engine** and relies on a **Python background service** for intelligent decision-making and communication.

The Godot game sends **text-based commands** to the Python service via **WebSocket**.  
The Python service uses **AI logic** to predict the next optimal step and sends the resulting commands back to the Godot game.

This architecture separates game logic and AI processing while maintaining fast, real-time communication.

---

## How to Install

### Godot Game

1. Install **Godot Engine** (recommended version according to the project).
2. Open the project using Godot.
3. Compile or export the game using Godot’s standard build/export tools.

---

### Python Backend

The Python script must run in the background for the game to function correctly.

You can compile the Python script into a standalone executable using **PyInstaller**:

```bash
pyinstaller --onefile gui.py
```


Alternatively, use the provided batch file:

```bash
compile_gui.bat
```

This will generate a .exe file that should be started before launching the game.

Usage
Start the Python backend executable.
Launch the Godot game.
The game automatically connects to the Python service via WebSocket and exchanges commands in real time.


## How is looks like
<img width="3278" height="1822" alt="image" src="https://github.com/user-attachments/assets/731fdfaf-b6f9-4d1d-b018-51aed1cb435a" />


