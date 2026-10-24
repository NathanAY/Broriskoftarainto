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
- **`fallback_enemy_scene`** — what is spawned when the table is empty, or when every row is still locked behind its loop. It defaults to `src/Systems/Enemy.tscn`, so a scene that forgot to fill the table still spawns.
- **`pick_enemy_scene()`** — the draw. Rows whose `min_loop` the current loop has not reached are closed; the open rows are drawn by weight.

A row is a `Resource` rather than one of two parallel exported arrays, because the inspector cannot check that two arrays are the same length, and hand-synchronised parallel arrays rot the first time someone adds a row.

The table itself lives in the **gameplay scene**, not in `src/Systems/EnemySpawner.tscn`: `src/Scenes/Game.tscn` fills the `EnemySpawner` node's `spawn_table` with one row per enemy type. The spawner scene stays a generic spawner, and a scene that instantiates it without a table still spawns the fallback enemy. The current rows are the grunt, the Bulwark and the Gunner; see `docs/systems/enemies.md` for what each one is.

## Spawn pacing (see glossary: Wave, Stage, Loop, Spawn pacing)
- Base `spawn_interval = 1s`; each Wave entry calls `start_wave()` so the first tick lands ~1s (no stale stopped/long timer).
- Dynamic rate: speeds up when below `target_enemy_count`, slows down when above (protects weak builds + perf). Ticks clamped to `[0.4s, 4.0s]`.
- Empty arena: refill delay `max(0.3, 1.0 - 0.15*(Loop-1))` + `_process` watchdog shortens any long pending wait.
- Alive cap `max_alive_enemies = 100`: ticks above cap are skipped (wait = max).

## Dependencies
- `StageManager` to control `spawn_active` flags; `Enemy` scenes expect `Stats`, `WeaponHolder`, `ItemHolder` children.

## Known limitations / TODOs
- `BossSpawner._apply_scaling` contains loop-based logic that iterates `for i in current_loop` which is suspicious (iterating an int); likely a bug/placeholder.
- The spawn table is filled in by `src/Scenes/Game.tscn` only, so a scene that instances `src/Systems/EnemySpawner.tscn` directly gets the fallback enemy rather than the roster.
