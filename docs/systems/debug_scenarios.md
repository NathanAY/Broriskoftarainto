# Debug scenarios

## Purpose

Six dev-only runs that start in a state a normal run would need several loops to reach, so a build or a balance number can be checked without playing up to it. The **Sandbox** one goes the other way: it starts ordinary and hands you the controls. They are reached from the main menu's **Debug scenarios** button, next to **New game** - the character select → `StarterMenu.tscn` route is still the default way to play, and nothing here is on that path.

None of it ships. The picker, the scenarios and their tests live in `test/scenarios/`, and the only `src/` change is the button in `src/Scenes/menu/Main.tscn` plus the handler in `src/Scenes/menu/main_menu.gd`. That handler checks the picker exists first, so a build without `test/` warns instead of changing to a missing scene.

| Scenario | Scene | What it starts as |
|---|---|---|
| Sandbox | `test/scenarios/scenario_sandbox.tscn` | Plain loop 1 stage 1, plus a **Spawn enemy** panel in the pause menu that puts the enemy type you pick, with a health, movement speed and amount you type in, into the arena |
| Loaded build | `test/scenarios/scenario_loaded_build.tscn` | Loop 1, stage 1, Ranger with 4 weapons and 5 items - three of which carry 3-5 modifiers each |
| First stage boss | `test/scenarios/scenario_first_boss.tscn` | Loop 1 **stage 2**: the enemy stage is skipped and the boss spawns at once |
| Loop 3 | `test/scenarios/scenario_loop_three.tscn` | Loop 3 stage 1: enemies already scaled by `current_loop`, boss spawner scaled to match |
| Cursed enemies | `test/scenarios/scenario_cursed_enemies.tscn` | Loop 1, stage 1, with a **debuff item on every enemy**, so the HUD's debuff row fills. Also picks up a buff item, so both rows show at once |
| Enemy preview | `test/scenarios/scenario_enemy_preview.tscn` | Frozen stage 1 with **one of every enemy type**, boss included, in a ring around the player. The roster chases but cannot hurt you, so the whole set can be walked and watched |

## Sandbox: typing the numbers instead of scaling to them

Every other scenario answers "what does the game look like at loop 3" by moving the run there. The sandbox answers "what does this one number do" by putting it on one enemy, and that is a different job: a balance pass wants an enemy at exactly 100000 health and 0 speed, not a wave scaled to an approximation of it.

`ScenarioSetup.sandbox = true` builds a `SandboxMenu` (`test/scenarios/sandbox_menu.gd`) as a child of itself, and adds a **Spawn enemy** button to the pause menu's `Control/VBoxContainer`. The panel has an enemy picker, three spinboxes - health (0 - 1,000,000, default 100000), movement speed (0 - 20 m/s, default 0) and amount (1 - 100) - and a **Spawn** button, laid out in code rather than as a `.tscn` so a dev panel cannot drift from the script that drives it.

The picker is built from `SandboxMenu.ENEMY_TYPES`, which lists the whole enemy roster, boss included (the same scenes as `DebugScenarioSetup.ENEMY_ROSTER`). Adding a type is one entry in that list - the panel builds its items from it, so a new type cannot be left out of the UI, and `spawn_configured()` instantiates whatever the picker shows.

Three things it has to get right, and each is pinned by `test/scenarios/test_sandbox_scenario.gd`:

- **Stats are written before `add_child()`.** `Health._ready()` reads `max_health` off `Stats` and copies it into `current_health`, so setting the stat afterwards raises the ceiling and leaves a 100000-health enemy already dead.
- **No stage scaling.** `_apply_stage_scaling()` is the spawner's business; the sandbox sets the number and gets it. A sandbox enemy is deliberately not what a loop-3 wave would field.
- **It runs while paused.** The panel is reached from the pause menu, so `setup()` sets `PROCESS_MODE_ALWAYS` before the node enters the tree; an inheriting panel is dead exactly when it is needed. Opening hides the pause menu's button list and closing gives it back, the way `OptionsMenu` does.

Enemies land under `Nodes/Enemies` - the same node `StageManager` watches - on a ring around the player, so a batch does not stack on one pixel. `spawn_configured()` returns what it spawned, which is what makes it checkable without going through the UI.

**The run is held at stage 1.** `ScenarioSetup._freeze_stage()` runs after the panel is installed and sets three things, so the arena holds only what the panel put there - a number read off an enemy is that enemy, not the wave's contribution to it.

The one that matters is `StageManager.stage_active = false`. There are **two clocks**, and silencing the obvious one is not enough:

| Clock | Owner | What silencing it alone achieves |
|---|---|---|
| spawn cadence | `EnemySpawner.spawn_timer`, checked by `_on_spawn_timer_timeout()` | no more enemies are added |
| **stage duration** | `StageManager.stage_time_elapsed`, counted in `_process_enemy_stage()` | **nothing** |

The stage clock is the one that moves the run on: at `stage_duration` (20s) `_process_enemy_stage()` calls `_end_stage()` → `go_to_stage(2)`, which spawns the boss *and* sets `spawn_active = true` on the boss spawner. Stopping only the spawner therefore still gets a boss at 20s. `stage_active = false` short-circuits `StageManager._process()` before any of that.

The other two are `spawn_active = false` (the cadence stops on its own terms rather than relying on the stage being frozen) and `spawn_timer.stop()` (with the stage frozen the timer would otherwise keep ticking and keep re-reading the empty arena through the refill watchdog, `EnemySpawner._process()`). Only the spawner and the manager are touched, so the panel still spawns freely.

There is no way to bring the wave back from the panel. `StageManager.go_to_stage(1)` and `EnemySpawner.start_wave()` are the seams if that is ever wanted.

`test/tools/sandbox_panel_preview.tscn` renders the panel alone, for a layout check with `run_scene_shot.bat`: the real route needs a live pause screen, which a one-shot render cannot reach.

## Cursed enemies: making the debuff row reachable

The HUD's second row shows **debuffs on the player** (`src/ui/buff_ui.gd`). Nothing spawns one in the shipped game: enemies carry no items — the `add_item` line in `src/Scripts/Enemy.gd` is commented out — so the row is correct code over an empty world until an enemy carries a `DebuffSource` item.

Giving every enemy a debuff item in a real run would be a **balance change**, and `docs/systems/balance.md` governs those. So this is a scenario instead: `ScenarioSetup.enemy_item_name` hangs an `EnemyDebuffModifier` off `StageManager/EnemySpawner`.

- It uses the spawner's **own extension point**: `EnemySpawner._ready()` collects every child that has `attach_to_enemy(enemy, character)` into `modifiers`, and both spawn paths call it once per enemy, before the enemy enters the tree.
- That timing is also the trap. `_ready()` builds the list before the scenario's node exists, so `ScenarioSetup` has to `add_child()` **and** append to `enemy_spawner.modifiers` — adding the child alone leaves `attach_to_enemy()` never called and the scenario silently does nothing. `test_debug_scenarios.gd` pins that the modifier is in the list.
- `ItemHolder.hold_owner` is a getter that resolves the moment the holder is parented, so the item wires itself up on an off-tree enemy and only has to run `_ready()` when the enemy joins.

## Enemy preview: the whole roster in one arena

`EnemySpawner.spawn_table` is sampled by weight, so no ordinary run fields every enemy type. `ScenarioSetup.spawn_enemy_roster` puts one of each scene in `ENEMY_ROSTER` - grunt through boss - on a 420px ring around the character, which is the only way to judge a set of sprites against each other.

**It is a gallery, not a fight.** Both halves of an enemy's threat are removed, and the two halves need different timing:

- the **contact weapon** is cleared **before `add_child()`**, because `Enemy._ready()` is what arms it from `contact_weapon`;
- the **ranged weapon** is removed afterwards, out of `WeaponHolder.weapons`, because it is authored into the Gunner's own scene. `remove_weapon()` also frees its visual and stops its firing timer.

They still chase (`set_target_position(character)`), because a still sprite cannot show the one thing a legless enemy has to get right: the walk, and the `flip_h` as it crosses in front of the player. `test_debug_scenarios.gd` pins both halves of the disarm and that every roster scene was fielded exactly once.

## Monster density

One slider under the list, **0.1x - 20x**, defaulting to 1.0x. It is shared by every scenario rather than being a per-scenario field, so a build can be checked against a trickle of monsters or an arena full of them without editing a scene.

The picker reads the slider at press time and writes it to `DebugScenarioSetup.pending_monster_multiplier`, a **static** rather than a node: the scenario scene that reads it is not in the tree yet, and a static is the only thing that survives the scene change. `ScenarioSetup._ready()` applies it to `StageManager.enemy_spawner` after `_apply_start_mode()` — it has to be last, because the stage jump can call `start_wave()`, which re-sizes the wave from `current_loop` and would drop a multiplier applied before it.

`EnemySpawner.spawn_multiplier` (default `1.0`, clamped to `MIN_SPAWN_MULTIPLIER`/`MAX_SPAWN_MULTIPLIER`) scales three things through its `scaled_*` helpers:

| Helper | Scales | At 1.0 |
|---|---|---|
| `scaled_target_enemy_count()` | `base_target_enemy_count + current_loop - 1` | the shipped wave size |
| `scaled_group_size()`, `scaled_groups_per_tick()` | `group_size`, `min_groups_per_spawn`..`max_groups_per_spawn` | the shipped batch |
| `scaled_spawn_interval()`, `scaled_min_spawn_wait()`, `scaled_max_spawn_wait()` | `spawn_interval` and both clamps, divided by the multiplier | the shipped 1s tick |

`max_alive_for_multiplier()` scales `max_alive_enemies` as well, or the ceiling would silently truncate a 20x wave back down to 100. `max_alive_enemies` itself is left as the 1.0 value so turning the multiplier up and down cannot compound.

Two floors, both deliberate:

- **Population and group size never reach 0.** `StageManager` only ends a stage once the arena is empty, so a wave that fields nothing would never end. 0.1x means one enemy at a time, not no enemies.
- **`spawn_budget()` caps a tick at the wave target plus one unscaled batch.** The alive-enemy ceiling is only checked *before* a tick, so at 20x an uncapped tick would dump its entire scaled batch — thousands of monsters — into the arena at once. The `+ unscaled_batch` term is the overshoot an ordinary spawner already allows, which is also why the budget is exactly the shipped batch at 1.0.

**Every value under 1x is a slower trickle, not just a smaller one**, because the cadence is divided by the multiplier along with the population: at 0.1x the tick is 10s and one monster walks in. Without that, everything below 1x would behave identically.

## Key scripts / scenes

- `test/scenarios/debug_scenario_menu.gd` — the picker. `SCENARIOS` is the list; a row (button + description) is generated per entry, so a scenario is one dict here plus one `.tscn`, and the list cannot drift from what is on disk. `scene_path_for(index)` is the routing seam the tests read.
- `test/scenarios/scenario_setup.gd` (`DebugScenarioSetup`) — the whole configuration of one scenario, as exports on a node at the end of the scenario scene.
- `test/scenarios/sandbox_menu.gd` (`SandboxMenu`) — the sandbox panel, built in code by `_install_sandbox_menu()` when a scenario sets `sandbox = true`.
- `test/scenarios/scenario_*.tscn` — each instances `src/Scenes/Game.tscn` and adds one `ScenarioSetup`.

## Data flow

A scenario is the scene, not a set of globals set somewhere earlier:

1. `ScenarioSetup._enter_tree()` picks the character and clears `GlobalGameState.starting_weapons` / `starting_items`. `_enter_tree` rather than `_ready` because `Character` and its `CharacterInitializer` read `GlobalGameState` from *their* `_ready`, which runs before this node's.
2. One frame later `_ready()` equips the loadout through the holder API (`weapon_holder.add_weapon`, `item_holder.add_item`), because those holders only exist once `Character` is built. `stacked_build = true` adds `stacked_items()` on top.
3. Still in that `_ready()`, `_apply_start_mode()` drives `StageManager` through its own seams — `go_to_stage(2)` for the boss, or `current_loop` on the manager and **both** spawners followed by `go_to_stage(1)` for loop 3.
4. `_apply_monster_multiplier()` hands the picker's density to `StageManager.enemy_spawner`, last because of the `start_wave()` ordering above.
5. `_install_sandbox_menu()` builds the sandbox panel and its pause-menu button, but only for a scenario that asked for one.
6. `_freeze_stage()` freezes `StageManager.stage_active` and silences `EnemySpawner`, for the sandbox panel and the roster preview alike, so the arena holds only what the scenario put there and the run stays on stage 1.
7. `_on_stage_applied()` prints one line saying which stage, loop and monster density the run landed on. That print is the thing to read when a scenario did not do what it claims.

`stacked_items()` builds its items with `ItemBuilder` rather than shipping new `.tres` files, because every item in `src/Resources/items/` is a single modifier and the point of this scenario is the multi-modifier stack. The numbers stay next to the scenario that uses them.

## Dependencies

- `src/Scenes/Game.tscn` — the scenario is that scene with one extra child, so `StageManager`, the spawners, the shop and the HUD all behave exactly as in a real run.
- `src/Scripts/stage_manager.gd` — `go_to_stage()`, and the three counters that have to agree (see below).
- `src/Systems/enemy_spawner.gd` — `spawn_multiplier` and its `scaled_*` helpers, which is where a density is actually turned into a wave. The only `src/` change the density feature makes.
- `src/Systems/Items/item_builder.gd`, `src/Resources/weapons`, `src/Resources/items`, `src/Systems/Items/modifiers` — the loadout.
- `src/Assets/character/<id>/<Id>.tres` — `character_path` must be a real resource, because `CharacterInitializer` derives the sprite folder from its path.
- `src/Systems/enemy_spawner.gd` — `modifiers` and the `attach_to_enemy()` hook the `Cursed enemies` scenario plugs into.
- `test/scenarios/enemy_debuff_modifier.gd` (`EnemyDebuffModifier`) — the whole of the cursed-enemies behaviour: it gives one spawned enemy the scenario's item, so nothing in `src/` had to change for the debuff row to be reachable.
- `src/Systems/enemies/Enemy.tscn`, `src/Systems/stats/stats.gd` — what the sandbox spawns, and the `Stats` node it writes the typed numbers into. No `src/` change.
- `src/Systems/enemies/EnemyBoss.tscn` and the rest of `ENEMY_ROSTER` — the roster preview instances those scenes unmodified, so what it shows is what a wave fields.

## Known limitations / TODOs

- **`start_new_loop()` is not used for the loop jump.** It advances the enemy spawner through `_on_next_stage()`, which would leave `StageManager.current_loop` and `EnemySpawner.current_loop` disagreeing by one. A scenario sets all three counters itself; `test/scenarios/test_debug_scenarios.gd` pins that they agree, and that the wave was resized (`target_enemy_count`) rather than left at the loop-1 value.
- **`weapon_names` is a floor, not a total.** `CharacterInitializer` adds the character's own `starting_weapons` on top, so Multitasker (which ships a Fist) ends up with one more weapon than listed. The loaded-build scenario uses Ranger, which ships none, so its four really are four.
- **These scenes are not in `test/`-agnostic tooling.** `test_doc_links.gd` link-checks them like any other path, and gdUnit4 picks up the two `test_*.gd` suites here, but nothing else loads them.
- **The density scales enemy counts, not the boss.** The slider touches `EnemySpawner` only, so `First stage boss` looks identical at 0.1x and 20x.
- **The slider is linear, so the low end is cramped.** 0.1x to 1.0x is 5% of the travel. Worth a log scale if anyone actually works at the bottom of the range.
- **A scenario is not a save.** It builds a starting state; it does not reproduce a specific run, so balance numbers read off it are indicative, not a replay.
- **Sandbox enemies are not stage-scaled.** Deliberate, but it means a sandbox number is not what the same loop would field: the panel is for one enemy, not for a wave.
- **The roster preview crowds.** The enemies chase, so a few seconds after the run starts they clump around the player instead of standing in a readable ring. Walk away to spread them out again; the separation force is what keeps the sprites from overlapping outright.
- No scenario covers the win screen directly, and none reaches the loop-choice portals. The loop-3 scenario clears its boss into the shop; **Go next** there spawns the choice. To reach it from a test without playing the shop, `StageManager.go_to_stage(STAGE_SHOP)` followed by `_on_shop_next_pressed()` is the seam (`test/Systems/test_loop_choice.gd` uses it).
