# UI / Shop Portal

Purpose
- Provide the shop UI and portal flow between gameplay stages (spawned by StageManager when a boss is cleared).

Key scripts / scenes
- `Systems/ShopPortal.tscn` (portal scene referenced from `StageManager`)
- `Scenes/menu/starter_menu.gd` — starter selection UI that writes to `GlobalGameState`.

Data flow
- Inputs: `StageManager` spawns portal and possibly connects shop menu signals.
- Processing: UI selection in starter menu writes `GlobalGameState.starting_weapons` and `starting_items` and starts the game scene; shop menu connects back to `StageManager` via signal to continue.
- Outputs: triggers `StageManager.start_new_loop()` when player accepts the shop choices.

Dependencies
- `GlobalGameState` autoload (assumed), `ShopMenu` scene, `StageManager` connections.

Known limitations / TODOs
- `starter_menu.gd` reads resources using DirAccess and assumes `.tres` layout; may fail if resources move.
- `GlobalGameState` implementation not found in repository (assumed autoload singleton).
