# Debug scenarios

## Purpose

Three dev-only runs that start in a state a normal run would need several loops to reach, so a build or a balance number can be checked without playing up to it. They are reached from the main menu's **Debug scenarios** button, next to **New game** - the character select → `StarterMenu.tscn` route is still the default way to play, and nothing here is on that path.

None of it ships. The picker, the scenarios and their tests live in `test/scenarios/`, and the only `src/` change is the button in `src/Scenes/menu/Main.tscn` plus the handler in `src/Scenes/menu/main_menu.gd`. That handler checks the picker exists first, so a build without `test/` warns instead of changing to a missing scene.

| Scenario | Scene | What it starts as |
|---|---|---|
| Loaded build | `test/scenarios/scenario_loaded_build.tscn` | Loop 1, stage 1, Ranger with 4 weapons and 5 items - three of which carry 3-5 modifiers each |
| First stage boss | `test/scenarios/scenario_first_boss.tscn` | Loop 1 **stage 2**: the enemy stage is skipped and the boss spawns at once |
| Loop 3 | `test/scenarios/scenario_loop_three.tscn` | Loop 3 stage 1: enemies already scaled by `current_loop`, boss spawner scaled to match |

## Key scripts / scenes

- `test/scenarios/debug_scenario_menu.gd` — the picker. `SCENARIOS` is the list; a row (button + description) is generated per entry, so a scenario is one dict here plus one `.tscn`, and the list cannot drift from what is on disk. `scene_path_for(index)` is the routing seam the tests read.
- `test/scenarios/scenario_setup.gd` (`DebugScenarioSetup`) — the whole configuration of one scenario, as exports on a node at the end of the scenario scene.
- `test/scenarios/scenario_*.tscn` — each instances `src/Scenes/Game.tscn` and adds one `ScenarioSetup`.

## Data flow

A scenario is the scene, not a set of globals set somewhere earlier:

1. `ScenarioSetup._enter_tree()` picks the character and clears `GlobalGameState.starting_weapons` / `starting_items`. `_enter_tree` rather than `_ready` because `Character` and its `CharacterInitializer` read `GlobalGameState` from *their* `_ready`, which runs before this node's.
2. One frame later `_ready()` equips the loadout through the holder API (`weapon_holder.add_weapon`, `item_holder.add_item`), because those holders only exist once `Character` is built. `stacked_build = true` adds `stacked_items()` on top.
3. Still in that `_ready()`, `_apply_start_mode()` drives `StageManager` through its own seams — `go_to_stage(2)` for the boss, or `current_loop` on the manager and **both** spawners followed by `go_to_stage(1)` for loop 3.
4. `_on_stage_applied()` prints one line saying which stage and loop the run landed on. That print is the thing to read when a scenario did not do what it claims.

`stacked_items()` builds its items with `ItemBuilder` rather than shipping new `.tres` files, because every item in `src/Resources/items/` is a single modifier and the point of this scenario is the multi-modifier stack. The numbers stay next to the scenario that uses them.

## Dependencies

- `src/Scenes/Game.tscn` — the scenario is that scene with one extra child, so `StageManager`, the spawners, the shop and the HUD all behave exactly as in a real run.
- `src/Scripts/stage_manager.gd` — `go_to_stage()`, and the three counters that have to agree (see below).
- `src/Systems/Items/item_builder.gd`, `src/Resources/weapons`, `src/Resources/items`, `src/Systems/Items/modifiers` — the loadout.
- `src/Assets/character/<id>/<Id>.tres` — `character_path` must be a real resource, because `CharacterInitializer` derives the sprite folder from its path.

## Known limitations / TODOs

- **`start_new_loop()` is not used for the loop jump.** It advances the enemy spawner through `_on_next_stage()`, which would leave `StageManager.current_loop` and `EnemySpawner.current_loop` disagreeing by one. A scenario sets all three counters itself; `test/scenarios/test_debug_scenarios.gd` pins that they agree, and that the wave was resized (`target_enemy_count`) rather than left at the loop-1 value.
- **`weapon_names` is a floor, not a total.** `CharacterInitializer` adds the character's own `starting_weapons` on top, so Multitasker (which ships a Fist) ends up with one more weapon than listed. The loaded-build scenario uses Ranger, which ships none, so its four really are four.
- **These scenes are not in `test/`-agnostic tooling.** `test_doc_links.gd` link-checks them like any other path, and gdUnit4 picks up the two `test_*.gd` suites here, but nothing else loads them.
- **A scenario is not a save.** It builds a starting state; it does not reproduce a specific run, so balance numbers read off it are indicative, not a replay.
- No scenario covers the shop phase (stage 3) or the win screen directly - loop 3 reaches the win screen by beating its boss.
