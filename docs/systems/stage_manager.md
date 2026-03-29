# Stage Manager

Purpose
- Orchestrates the high-level flow: enemy waves, boss encounters, and shop stages (loop progression).

Key scripts / scenes
- `Scripts/stage_manager.gd` (`StageManager`)

Data flow
- Inputs: timing (stage_duration), enemy counts (from `Nodes/Enemies`), player actions (shop next), boss/enemy spawner states.
- Processing: advances `current_stage` and `current_loop`, toggles spawners and spawns the shop portal when a boss is cleared.
- Outputs: starts/stops spawners, spawns shop portal and run end screens.

Dependencies
- `EnemySpawner`, `BossSpawner`, `ShopPortal.tscn`, `RunEndScreen` UI, and the `Character` signal `character_died`.

Known limitations / TODOs
- `spawn_shop_portal` uses `get_tree().current_scene.get_node("Nodes").add_child(portal)` — assumes scene node naming conventions.
