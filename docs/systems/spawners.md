# Spawners

Purpose
- Manage spawning of regular enemies and bosses, plus apply stage-based scaling and spawn modifiers.

Key scripts / scenes
- `Systems/enemy_spawner.gd` (`EnemySpawner`)
- `Systems/boss_spawner.gd` (`BossSpawner`)

Data flow
- Inputs: `character` reference, spawn timers, `spawn_active` flags, optional modifier children.
- Processing: `EnemySpawner` spawns enemies around the character and applies modifiers and stage scaling; `BossSpawner` spawns a single boss instance and scales by loop.
- Outputs: instantiated enemy/boss nodes added to runtime `Nodes/Enemies` container.

Dependencies
- `StageManager` to control `spawn_active` flags; `Enemy` scenes expect `Stats`, `WeaponHolder`, `ItemHolder` children.

Known limitations / TODOs
- `BossSpawner._apply_scaling` contains loop-based logic that iterates `for i in current_loop` which is suspicious (iterating an int); likely a bug/placeholder.
