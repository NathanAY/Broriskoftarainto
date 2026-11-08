# Spawners

## Purpose
- Manage spawning of regular enemies and bosses, plus apply stage-based scaling and attach death-reward handlers (<code>src/Systems/SpawnerModifier.tscn</code>, misnamed — see glossary).

## Key scripts / scenes
- `src/Systems/enemy_spawner.gd` (`EnemySpawner`)
- `src/Systems/boss_spawner.gd` (`BossSpawner`)
- `src/Systems/enemies/enemy_spawn_entry.gd` (`EnemySpawnEntry`) — one row of the spawn table: a scene, a weight, and the loop it unlocks on.
- `src/Systems/SpawnerModifier.tscn` (+ `src/Scripts/spawner_modifier.gd`) — death rewards (money, drops, explosion, death mark)

## Data flow
- Inputs: `character` reference, spawn timers, `spawn_active` flags, optional death-reward handler children.
- Processing: `EnemySpawner` spawns enemies around the character and attaches death-reward handlers and stage scaling; `BossSpawner` spawns a single boss instance and scales by loop.
- Outputs: instantiated enemy/boss nodes added to runtime `Nodes/Enemies` container.

## The spawn table
The regular spawner used to spawn one hardcoded scene — `src/Systems/Enemy.tscn` — for every wave of every run. It now spawns from a table:

- **`spawn_table`** — an array of `EnemySpawnEntry` rows. A row names the enemy scene, how likely it is to come up (`weight`), and the loop it unlocks on (`min_loop`). A row with no weight never comes up.
- **`pack_size`** — how many bodies one draw of a row spawns. A pack enemy arrives as a group; an ordinary row is a pack of one. The Swarmer row uses 8.
- **`elite_min_loop`** — from that loop on the row spawns the same scene as an elite: `elite_health_multiplier` and `elite_damage_multiplier` scale its base stats and `elite_tint` multiplies its `Node2D` container. `0` means the row never turns elite. Every shipped row uses 3.
- **`fallback_enemy_scene`** — what is spawned when the table is empty, or when every row is still locked behind its loop. It defaults to `src/Systems/Enemy.tscn`, so a scene that forgot to fill the table still spawns.
- **`pick_spawn_entry()`** — the draw. Rows whose `min_loop` the current loop has not reached are closed; the open rows are drawn by weight. `pick_enemy_scene()` is the scene-only wrapper for callers that do not need the pack or elite fields.

A row is a `Resource` rather than one of two parallel exported arrays, because the inspector cannot check that two arrays are the same length, and hand-synchronised parallel arrays rot the first time someone adds a row.

A group is drawn from **one row**, so a pack arrives together. That also means an ordinary row's group is a small group of the same type rather than a mixed handful; the variety comes from the next tick's draw.

The table itself lives in the **gameplay scene**, not in `src/Systems/EnemySpawner.tscn`: `src/Scenes/Game.tscn` fills the `EnemySpawner` node's `spawn_table` with one row per enemy type. The spawner scene stays a generic spawner, and a scene that instantiates it without a table still spawns the fallback enemy. The current rows are the grunt, the Bulwark, the Gunner, the Slimeling, the Lancer, the Toadstinker, the Blink, the Shieldbearer and the Swarmer; see `docs/systems/enemies.md` for what each one is.

## Spawn pacing (see glossary: Wave, Stage, Loop, Spawn pacing)
- Base `spawn_interval = 1s`; each Wave entry calls `start_wave()` so the first tick lands ~1s (no stale stopped/long timer).
- Dynamic rate: speeds up when below `target_enemy_count`, slows down when above (protects weak builds + perf). Ticks clamped to `[0.4s, 4.0s]`.
- Empty arena: refill delay `max(0.3, 1.0 - 0.15*(Loop-1))` + `_process` watchdog shortens any long pending wait.
- Alive cap `max_alive_enemies = 100`: ticks above cap are skipped (wait = max).

## Dependencies
- `StageManager` to control `spawn_active` flags; `Enemy` scenes expect `Stats`, `WeaponHolder`, `ItemHolder` children.

## Boss scaling
- `spawn_boss()` spawns the loop's boss; `spawn_final_boss()` spawns the same scene scaled `final_boss_extra_loops` (2) loops past `current_loop`. `StageManager` calls the second only from its `STAGE_FINAL_BOSS` stage. Both go through one private `_spawn_boss(loop)`, so the guard against a double spawn and the arena clamp cannot drift between them.
- `_apply_scaling(loop)` takes the loop to scale as an argument rather than reading `current_loop`, because the final boss is scaled as a *later* loop than the run is on.
- Health and damage grow `health_growth_per_loop` / `damage_growth_per_loop` per loop value. The weapon ramp (2 boss shotguns per loop, 2 Pistols at iteration 2, a `SpreadShot` at iteration 3) stops at `LOADOUT_LOOP_CAP` (4), so a boss scaled far past a normal run carries a budgeted loadout instead of a pair of shotguns per loop. The shipped ramp is untouched through loop 4; only loops past it are affected.

## Known limitations / TODOs
- The spawn table is filled in by `src/Scenes/Game.tscn` only, so a scene that instances `src/Systems/EnemySpawner.tscn` directly gets the fallback enemy rather than the roster.
