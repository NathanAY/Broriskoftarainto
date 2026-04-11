# Overview

Short description
- Genre: Top-down arena roguelite (wave-based shooter with boss and shop loops).
- Core loop: Clear enemy waves → defeat boss → enter shop/upgrade phase → repeat with increased difficulty.
- Inspiration: Brotato-style item/weapon stacking and fast-paced wave combat (as requested).

Major systems
- Event Manager (LocalEventManager)
- Player / Character (`Scripts/character.gd`)
 - Player / Character (`Scripts/character.gd`)
 - Character selection / data (`docs/systems/characters.md`, `Scenes/menu/CharacterSelect.tscn`)
- Enemies (`Scripts/Enemy.gd`, `Systems/Enemy.tscn`)
- Stats system (`Systems/stats/stats.gd`)
- Weapons (`Systems/weapon/*`, WeaponHolder)
- Items (`Systems/Items/*`, Item, ItemHolder)
- ItemFactory (`Systems/Items/item_factory.gd`)
- Modifiers (`Systems/Items/Modifiers/*`) — behavior modules attached by items
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

Modifiers (brief):
- **Role**: Items are mostly data (attributes + metadata) and usually include one or more modifier instances. Modifiers implement gameplay effects (stat changes, spawn effects, on-hit behaviors, healing, projectiles, etc.).
- **Implementation**: Modifiers are Node-based scripts stored in `Systems/Items/Modifiers/`. They expose `attachEventManager(event_manager)` which the `ItemHolder`/`EventManager` uses to attach them to an owner entity at runtime.
- **How they work**: Modifiers subscribe to the local `EventManager` events (e.g., `on_attack`, `on_hit`, `on_item_added`, `on_item_removed`, `on_stat_changes`) to react to gameplay. They commonly access the holder's `Stats`, `Health`, or spawn `Projectile` scenes. Many modifiers support stacking via `add_stack`/`remove_stack`/`set_stack_active`.
- **Types & examples**: stat-affecting (percent/additive modifiers handled by `Stats`), periodic (e.g., `RegenModifier` with a timer), reactive/spawn (e.g., `ChainModifier`, `SpreadModifier`, `HomingOnHit`, `BombModifier`), utility (e.g., shields, reflect, knockback), and life/health effects (e.g., `LifeLeachModifier`, `LifeOnKillModifier`).
- **Notes for AI tooling**: When adding or modifying items, treat modifiers as small, self-contained behavioral modules that attach via the event bus and operate on the holder node. Look for `attachEventManager` and event subscriptions when tracing modifier behavior.

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
