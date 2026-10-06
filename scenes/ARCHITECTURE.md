# Scene and asset architecture

## Runtime ownership

- `game/Game.tscn` owns scene transitions.
- `main/main.tscn` is the world composition root. It wires maps, entity
  containers, navigation, spawning, buildings, and HUD nodes.
- World services are discovered through narrowly scoped groups such as
  `world_root`, `world_map`, `world_entity_spawner`, and `players_root`.
- Autoloads keep cross-scene session state. They do not instantiate world
  entities or own presentation nodes.

## Player composition

- `player.gd` coordinates the player components.
- `PlayerStats` owns gameplay state and emits changes.
- `PlayerStatusView` only renders stats and opens local UI.
- Movement, combat, inventory, and building remain independent components.
- `CodeParser` only turns source text into validated commands; `CodePlayer`
  executes those commands against the player components.
- `PlayerSensor` produces the fixed AI observation directly. Its flattened
  `8 x 21 x 21` byte tensor contains visibility, walkability, water, objects,
  items, animals, enemies, and the level goal. Stats, goal delta, and the
  four-action mask are returned beside that tensor.
- Sensor groups keep entity discovery independent from scene-tree containers.
- `Survi2NavigationEnv` mirrors the relevant Gymnasium concepts in GDScript:
  `action_space`, `observation_space`, `observe()`, and asynchronous `step()`.
  It has no reset yet; goal, death, or the step limit finish its only episode.
- Manual input, `CodePlayer`, and AI movement share one tile-step API and use
  mutually exclusive movement control modes. Code speed and particles remain
  owned exclusively by `CodePlayer`.
- Code editor and settings nodes are local-only and are removed from remote
  player instances during `_enter_tree`.

## Player AI contract

- Actions are `0 = up`, `1 = down`, `2 = left`, and `3 = right`.
- `Player/AI` contains sibling `Sensor`, `Environment`, `RLAgent`, and
  `RLTrainer` nodes. The environment does not own the agent or trainer.
- `EnvStepResult` carries `observation`, `reward`, `terminated`, `truncated`,
  and diagnostic `info` fields.
- Navigation rewards are `+10` for the goal, `-10` for death, `-0.2` for a
  blocked tile, and `-0.01` for a successful ordinary step.
- `terminated` means goal or death. `truncated` means the configured maximum
  number of steps was reached. A finished environment rejects further steps.

## Content data

- Authorable content lives under `assets/data` as typed Godot resources.
- Resource schema scripts live in `scenes/gameplay/definitions`.
- `Items.gd` is a read-only content registry. Its compatibility dictionaries
  allow older callers to migrate incrementally.
- Textures and packed scenes are referenced directly by resources; gameplay
  code must not construct asset paths from IDs.

## Conventions

- New files and directories use `snake_case`.
- Scene-tree dependencies are exported and wired in `.tscn` files, or resolved
  through a specific group when the node is spawned dynamically.
- UI observes gameplay state through signals. Gameplay components do not reach
  through HUD node paths.
- Entity creation belongs to world services, never to content registries.
