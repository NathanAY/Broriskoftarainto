# Overview

Short description
- Genre: Top-down arena roguelite (wave-based shooter with boss and shop loops).
- Core loop: Clear enemy waves → defeat boss → enter shop/upgrade phase → repeat with increased difficulty.
- Inspiration: Brotato-style item/weapon stacking and fast-paced wave combat (as requested).

Major systems
- Event Manager (LocalEventManager)
- Player (`Scripts/character.gd` — the `Character` class, see ADR-0001)
 - Character selection / data (`docs/systems/characters.md`, `Scenes/menu/CharacterSelect.tscn`)
- Enemies (`Scripts/Enemy.gd`, `Systems/Enemy.tscn`)
- Stats system (`Systems/stats/stats.gd`)
- Weapons (`Systems/weapon/*`, WeaponHolder)
- Items (`Systems/Items/*`, Item, ItemHolder)
- ItemFactory (`Systems/Items/item_factory.gd`)
- Effects (`Systems/Items/Modifiers/*`) — Node behavior modules attached by items
- Spawners (`Systems/enemy_spawner.gd`, `Systems/boss_spawner.gd`)
- Stage flow (`Scripts/stage_manager.gd`)
- UI & shop (Scenes/menu, `Systems/ShopPortal.tscn`)

Development stage
- Current stage: Early prototype (scripts show many TODOs and commented examples; basic gameplay loop implemented).

Key gameplay pillars
- Rapid arena combat with multiple orbiting/attached weapons.
- Item-driven character progression: persistent modifiers, temporary buffs, and effect scenes.
- Wave → boss → shop loop with scaling difficulty.
- Modular systems using resource-based weapons/items to enable fast iteration.

Effects (brief):
- **Role**: Items are mostly data (attributes + metadata) and usually include one or more effects. Effects implement gameplay behavior (spawn effects, on-hit behaviors, healing, projectiles, etc.), while stat changes come from stat modifiers in `Stats.add_modifier` format.
- **Implementation**: Effects are Node-based scripts stored in `Systems/Items/Modifiers/` (legacy folder name). They expose `attachEventManager(event_manager)` which the `ItemHolder`/`EventManager` uses to attach them to an owner actor at runtime.
- **How they work**: Effects subscribe to the local `EventManager` events (e.g., `on_attack`, `on_hit`, `on_kill`, `on_item_added`, `on_item_removed`, `on_stat_changes`) to react to gameplay. They commonly access the holder's `Stats`, `Health`, or spawn `Projectile` scenes. Many effects support stacking via `add_stack`/`remove_stack`/`set_stack_active`.
- **Types & examples**: periodic (e.g., `RegenModifier` with a timer), reactive/spawn (e.g., `ChainModifier`, `SpreadModifier`, `HomingRocketModifier`, `BombOnHitModifier`), utility (e.g., shields, reflect, knockback), and life/health effects (e.g., `LifeLeachModifier`, `StatOnKillModifier` — configurable `target_stat`/`add_amount`, triggers on `on_kill` which the damage pipeline emits when a target dies).
- **Notes for AI tooling**: When adding or modifying items, treat effects as small, self-contained behavioral modules that attach via the event bus and operate on the holder node. Look for `attachEventManager` and event subscriptions when tracing effect behavior. Positional perks that only touch stats are stat modifiers, not effects.

Architecture docs in next file
- Scene structure, design patterns, script responsibilities docs/architecture.md

Major systems (event manager, player, enemies, stats, weapons, items, itemFactory, modifiers, etc.) docs in folder docs/systems/*
- enemies.md
- event_manager.md
- item_factory.md
- items.md
- player.md
- spawners.md
- stage_manager.md
- stats.md
- ui_shop_portal.md
- weapons.md
