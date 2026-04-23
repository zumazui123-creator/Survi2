# Survi2 Project Context

## Project Overview
Survi2 (also referred to as "Survivor IO" in config) is a 2D survival game built with **Godot 4.6 (GL Compatibility)**. It features a top-down perspective, crafting mechanics, day/night cycles, and is designed with LAN multiplayer capabilities.

## Key Configuration
- **Engine:** Godot 4.x (GDScript)
- **Main Scene:** `res://scenes/game/Game.tscn`
- **Resolution:** 1280x720 (Viewport stretch mode)
- **Physics Layers:** 
	- Layer 1: Tiles
	- Layer 2: Attacks

## Critical Rules
- **DO NOT MODIFY:** `net_control.gd`. This script is critical for networking and must remain unchanged unless explicitly instructed otherwise.
- **Autoloads:** Many core systems (Inventory, Items, Constants) are handled via Autoloads. Always check `project.godot` or the `scenes/autoloads/` directory before implementing global logic.

## Project Structure
The project is organized into clear functional directories:

### `/scenes` - Game Logic & Scenes
- `animal/`: Animal entities and logic.
- `attacks/`: Projectile and melee attack scenes.
- `autoloads/`: Global singleton scripts (Constants, Inventory, Items, etc.).
- `character/`: Player and NPC/AI components, including equipment and builder logic.
- `enemy/`: Enemy AI and entities.
- `game/`: Main game loop and top-level scenes.
- `item/`: Item pickups and world interactions.
- `main/`: Core systems like Day/Night cycle, HUD, spawning logic, and navigation.
- `map/`: TileMap, map generation, and environmental puzzles.
- `spawn/`: Logic for spawning buildings and objects.
- `ui/`: User interface components (Chat, Inventory, Minimap, Menus).

### `/assets` - Visual & Audio Resources
- `characters/`: Sprite sheets for players, enemies, and weapons.
- `daynight/`: Textures and shaders for the lighting system.
- `fonts/`: UI typography.
- `items/`: Icons for inventory items.
- `objects/`: Environmental sprites (trees, rocks, ores).
- `sfx/`: Audio files for steps, swings, etc.
- `tileset/`: Tile sheets and `.tres` resources for the environment.
- `ui/`: Generic UI textures like item slots.

### `/Web` - Web Export Artifacts
- Contains exported files for web builds and `WebSurvi` specific sub-project context.
- **DO NOT MODIFY:** /Web and everything in the folder.

### Root Files
- `project.godot`: Main engine configuration.
- `export_presets.cfg`: Build configurations.
- `PLAYER_COMMANDS.md`: Documentation for player-facing commands (in `/docs`).

## Global Singletons (Autoloads)
- `Constants`: Global game constants.
- `Multihelper`: Multiplayer utility functions.
- `Inventory`: Player inventory management.
- `Items`: Item database and metadata.
- `GameTime`: Manages the day/night cycle logic.
- `workTask`: Management of AI/player tasks.
- `Levels`: Leveling and progression logic.
- `Strings`: Localization or global string constants.

## Multiplayer
The game is built with a focus on LAN multiplayer. Networking logic should be centralized or follow existing patterns in `Multihelper` and the `net_control` architecture.
