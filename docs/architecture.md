# Architecture

Paths are repo-root-relative and checked by `test/test_doc_links.gd`. Terms follow `CONTEXT.md`.

## Scene structure

The gameplay scene is `src/Scenes/Game.tscn`. Its root is named `Main` (a `Node2D`), and its children are the runtime container for everything:

| Node under `Game.tscn` | Role |
|---|---|
| `Arena` | Playfield geometry and walls |
| `StageManager` | Owns the `EnemySpawner` and `BossSpawner` children and drives the stage loop |
| `Character` | An instance of `src/Systems/Character.tscn` — the runtime **Player** |
| `ItemFactory` | An instance the factory uses to read stats and generate items |
| `Nodes/` | Plain-node runtime containers. `Nodes/Enemies` is where the spawners add enemies and where `StageManager` counts them to decide a stage is over; siblings are `pickups`, `altars`, `death_marks`. |
| `InteractionManager` | Pickup/altar interaction |
| `UI/` | `CanvasLayer/CharacterUi`, plus `ShopMenu` and `PauseMenu` |

Everything else is a reusable piece instanced into that tree:

| Path | Role |
|---|---|
| `src/Systems/Character.tscn` | The Player scene — see `docs/systems/player.md` for its child contract |
| `src/Systems/Enemy.tscn`, `src/Systems/EnemyBoss.tscn` | Enemy and boss scenes; both take `Stats`, `Health`, `WeaponHolder`, `ItemHolder`, `EventManager` as children |
| `src/Systems/ShopPortal.tscn` | The shop entry portal spawned after a boss dies |
| `src/Systems/SpawnerModifier.tscn` | Death rewards (money, drops, explosion, death mark). Attached to spawners, despite the name — it is not a spawner. |
| `src/Systems/stats/`, `src/Systems/weapon/`, `src/Systems/Items/` | Reusable subsystems |
| `src/ui/` | Reusable UI scenes and scripts: cards, panels, tooltips, icon generator |
| `src/Scenes/effects/`, `src/Scenes/particles/` | Hit flash, death texture burst, particle effects — instanced as children of actors |
| `src/Scripts/autoload/` | Autoloads: `GlobalGameState`, `SoundManager`, `MusicManager` |
| `src/Assets/character/<id>/` | One folder per character: its `CharacterData` `.tres` plus its art |

There is no separate `MainScene`; `Game.tscn` is the gameplay entry, and the menus are separate scenes in `src/Scenes/menu/`.

## Script responsibilities

- `src/Scripts/LocalEventManager.gd` (`EventManager`): the lightweight pub/sub bus every system talks through.
- `src/Scripts/character.gd` (`Character`): player logic, equipment (`WeaponHolder`, `ItemHolder`), event subscriptions.
- `src/Scripts/Enemy.gd`: enemy behaviour wrapper — health, weapons, movement.
- `src/Systems/stats/stats.gd` (`Stats`): base stats, modifiers, conditions, and modifier-owned (provided) stats.
- `src/Systems/weapon/*`: weapon resources (`BaseWeapon`) plus the runtime firing/aiming scripts.
- `src/Systems/Items/*`: the `Item` resource, `ItemHolder`, `item_pickup`, `ItemBuilder`, and `ItemFactory`.
- `src/Systems/Items/modifiers/*`: **effects** — Node behaviour modules an item attaches to an actor. See `docs/systems/modifiers.md`; this is the one naming inversion in the project.
- `src/Systems/enemy_spawner.gd`, `src/Systems/boss_spawner.gd`: spawn logic and scaling. Both reach the enemy container with a relative `get_node("../../Nodes/Enemies")`, so their position in the `Game.tscn` tree is part of their contract.
- `src/Scripts/stage_manager.gd`: stage transitions (enemy → boss → shop) and loop progression. A stage ends when `Nodes/Enemies.get_child_count() == 0`, which is why a corpse mid-death-animation still holds its stage open.

## How systems communicate

1. **The event bus** (`EventManager`) is the primary decoupling mechanism — `on_attack`, `on_hit`, `on_kill`, `on_stat_changes`, `on_item_added`, `on_condition_change`, and the damage-phase events. In debug builds every emit and subscribe is validated against a schema registry (`src/Scripts/event_contract.gd`), so an unknown event name or a malformed payload is rejected at the call site rather than surfacing as a silent no-op.
2. **Godot signals** for scene-local flow, e.g. `character_died` in `Character`.
3. **Direct node references** — exported variables and `@onready` lookups. Many modules reach for a sibling by name, e.g. `holder.get_node("Stats")`.
4. **`GlobalGameState`** (`src/Scripts/autoload/global_game_state.gd`), an autoload singleton, carries selections across scenes: `starting_character`, `starting_items`, `starting_weapons`.

Every event payload is a single `Dictionary`. That is what makes the contract checker possible, and it is why handlers bail out early on a missing key.

## Design patterns

- **Component/holder** — `WeaponHolder` and `ItemHolder` attach resources to an actor and apply their stat modifiers. Adding a weapon or an item never touches the actor's own script.
- **Resource-driven content** — weapons, items and characters are `.tres` `Resource`s and `PackedScene`s, so content ships as data.
- **Modifier stack** — `Stats` holds modifier dictionaries and computes final values from them; effects hold their own `stacks: Array[bool]` on `BaseModifier`.
- **Event bus** — `EventManager` is a dictionary of callables keyed by event name.

## Where the behaviour lives, in one line each

The three subsystems that generate behaviour all work the same way — attach a `Node`, subscribe to the bus, read the holder's stats — so a change in one is usually a change in all three:

| | Attaches | Contract |
|---|---|---|
| Stat modifier | nothing; a `Dictionary` | `docs/systems/stats.md` |
| Effect (modifier) | `BaseModifier` node under the `ItemHolder` | `docs/systems/modifiers.md` |
| Weapon built-in effect | `BaseModifier` node, scoped to one weapon via `bound_weapon` | `docs/systems/weapons.md` |

Two rules that the code enforces and that are easy to break by accident:

- **Spawned things get tagged.** A projectile spawned by a chain projectile carries metadata so the chain handler can early-return; otherwise effects recurse into each other. See "Anti-recursion" in `docs/systems/modifiers.md`.
- **Detach unsubscribes before freeing.** `EventManager` calls listeners without checking whether they are still valid, so a modifier that frees itself without unsubscribing crashes the next event.
