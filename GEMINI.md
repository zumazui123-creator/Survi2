# Survi2 Project Context

## Project Overview
This is a survival game built with Godot Engine.

## Critical Rules
- **DO NOT MODIFY:** `net_control.gd`. This script is critical and must remain unchanged unless explicitly instructed otherwise by a senior developer.

## Architecture & Conventions
- **Engine:** Godot 4.x (GDScript)
- **Style:** Follow standard GDScript style guide.
- **Structure:**
    - `scenes/`: Contains all game scenes (.tscn) and their attached scripts (.gd).
    - `assets/`: Contains raw assets like images, sounds, fonts.
    - `client_code_runner/`: Python scripts, likely for external logic or testing.

## Multiplayer
- The game is intended to have LAN multiplayer capabilities.
