# Architecture

Scene structure (main scenes & roles)
- `Scenes/Game.tscn` — main gameplay scene (entry after starter menu).
- `Scenes/MainScene` / `Scripts/MainScene.gd` — root helper for scene-level behaviors and UI access.
 - `Scenes/menu/CharacterSelect.tscn` — character selection UI (data-driven CharacterData resources in `Resources/characters`).
- `Nodes/Enemies` — runtime container for spawned enemies (used by spawners and StageManager).
- `Systems/*` — reusable system scenes and scripts (spawners, boss, shop portal, item factory).
- `UI/*` — in-scene UI (ShopMenu, PauseMenu, Player UI).

Script responsibilities
- `LocalEventManager.gd` (`EventManager`): lightweight pub/sub event bus used across systems.
- `character.gd` (`Character`): player logic, equipment (WeaponHolder, ItemHolder), subscribes to events.
- `Enemy.gd`: enemy behavior wrapper (health, weapons, movement behaviour).
- `Systems/stats/stats.gd` (`Stats`): base stats, modifiers, conditions and condition managers.
- Weapon scripts (`Systems/weapon/*`): weapon resources and runtime firing/aiming logic.
- Item scripts (`Systems/Items/*`): `Item` resource, `item_holder`, pickups, `item_factory` generator.
- Spawners: `enemy_spawner.gd` and `boss_spawner.gd` handle spawn logic and scaling.
- `stage_manager.gd`: orchestrates stage transitions (enemy → boss → shop) and loop progression.

How systems communicate
- Local event bus: `EventManager` (subscribe/emit) is the primary decoupling mechanism (examples: on_stat_changes, on_item_added, on_death).
- Godot Signals: scene-specific signals (e.g., `character_died` in `Character`) used for UI/flow.
- Direct node references / exported variables / `@onready` nodes: many modules call children directly (e.g., `hold_owner.get_node("Stats")`).
- GlobalGameState (assumed autoload singleton): used for persistent starting selections (`GlobalGameState.starting_items`). Marked as assumed because no local definition found.

Important design patterns
- Component/holder pattern: `WeaponHolder` and `ItemHolder` attach resources to an entity and apply modifiers.
- Resource-driven configuration: items/weapons are `Resource` (`.tres`) and `PackedScene` objects, enabling data-driven content.
- Modifier stack pattern: `Stats` collects modifier dictionaries and computes final stat values.
- Lightweight event bus: `EventManager` implements a simple dictionary-of-list callables pub/sub.
