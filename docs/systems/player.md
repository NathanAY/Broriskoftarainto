# Player / Character

Purpose
- Player entity and orchestration of equipment, stats and visuals.

Key scripts / scenes
- `Scripts/character.gd` (`Character` class)
- Scenes: `Scenes/Character.tscn` / children: `Stats`, `EventManager`, `WeaponHolder`, `ItemHolder`, `Hitbox`, `AnimationPlayer` (onready nodes referenced in script).
 - Character selection/data: `Systems/characters/CharacterData.gd`, `Resources/characters/*.tres`, and `Scenes/menu/CharacterSelect.tscn` — the selection UI writes `GlobalGameState.starting_character` and `CharacterInitializer` applies the data to `Stats` on spawn.

Data flow
- Inputs: player input (not fully shown), starting items/weapons from `GlobalGameState`, events from EventManager.
- Processing: equips weapons/items, subscribes to death/damage events, applies visual feedback (flash on damage).
- Outputs: emits `character_died` signal; triggers `on_item_added`/`on_weapon_added` through holders.

Dependencies
- `EventManager`, `Stats`, `WeaponHolder`, `ItemHolder`, `GlobalGameState` (assumed autoload).

Known limitations / TODOs
- Some initialization is hardcoded with many commented example items — indicates prototype code and manual testing artifacts.
- Input handling is minimal in `MainScene` — player input integration may live elsewhere or be incomplete.
