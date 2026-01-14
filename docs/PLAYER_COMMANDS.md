# Player Commands & Building Documentation

This document outlines the usage of `DebugCodePlayer` for parsing text-based commands and `PlayerBuilding` for world modification. Commands uses strings from Strings autoload.

## Debug Code Parser (`DebugCodePlayer.gd`)

Interprets line-separated string commands to control the player.

### Movement
Moves the player in cardinal directions.
- **Commands**: `links`, `rechts`, `oben`, `unten` (defined in `Strings.gd`)
- **Syntax**: `[command] [optional: steps]`
- **Examples**: 
  - `links` (Step left once)
  - `rechts 3` (Step right 3 times)

### Actions
- **Attack**: `attacke`
  - Trigger player combat hit.

### Construction Commands
Interacts with the `PlayerBuilding` component based on relative direction.
- **Syntax**: `[command] [type] [direction]`
- **Directions**: `links`, `rechts`, `oben`, `unten`

#### 1. Build
Instantiates a building/object scene.
- **Command**: `build`
- **Example**: `build wall oben` (Places "wall" type object one tile above)

#### 2. Paint
Changes the floor/terrain tile.
- **Command**: `paint`
- **Example**: `paint water links` (Changes tile to left to water)

---

## Player Building Component (`player_building.gd`)

Handles the execution of map modifications, these functions can be further moved to `map_buildings.gd` map component for calling server side.

### Functional Modes

1.  **Painting (`paint`)**
    - Directly modifies the `TileMap`.
    - **Supported Types**:
        - `grass`: (Atlas Coords: 0, 0)
        - `water`: (Atlas Coords: 18, 0)

2.  **Building (`build`)**
    - Places instances of scenes via `Multihelper.map.buildings`.
    - **Configuration**: Depends on `building_scenes` dictionary exported variable (configured in Godot Editor Inspector).
