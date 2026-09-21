# Player

Purpose
- The Player (the runtime combat entity the human controls) and orchestration of its equipment, stats and visuals.

Key scripts / scenes
- `Scripts/character.gd` (`Character` class — the Player entity, see ADR-0001)
- Scenes: `Scenes/Character.tscn` / children: `Stats`, `EventManager`, `WeaponHolder`, `ItemHolder`, `Hitbox`, `AnimationPlayer` (onready nodes referenced in script).
- Visual managers live as children (see `Scenes/effects/`): `HitFlashManager` (damage flash via `before_take_damage`), `TextureBurstManager` (death burst via `on_death`), `Scenes/particles/ParticleEffectManager` (hit particles via `after_take_damage`).
 - Character (archetype) selection/data: `Systems/characters/CharacterData.gd`, `Resources/characters/*.tres`, and `Scenes/menu/CharacterSelect.tscn` — the selection UI writes `GlobalGameState.starting_character` and `CharacterInitializer` applies the data to `Stats` on spawn.

Data flow
- Inputs: player input (not fully shown), starting items/weapons from `GlobalGameState`, events from EventManager.
- Processing: equips weapons/items, subscribes to death and damage events; visual feedback (flash on damage, particles, death burst) is delegated to the child effect managers.
- Outputs: emits `character_died` signal; triggers `on_item_added`/`on_weapon_added` through holders.

Dependencies
- `EventManager`, `Stats`, `WeaponHolder`, `ItemHolder`, `GlobalGameState` (assumed autoload).

Known limitations / TODOs
- Some initialization is hardcoded with many commented example items — indicates prototype code and manual testing artifacts.
- Input handling is minimal in `MainScene` — player input integration may live elsewhere or be incomplete.
