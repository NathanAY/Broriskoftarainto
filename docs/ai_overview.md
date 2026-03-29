# AI Overview

Short description
- Genre: Top-down arena roguelite (wave-based shooter with boss and shop loops).
- Core loop: Clear enemy waves → defeat boss → enter shop/upgrade phase → repeat with increased difficulty.
- Inspiration: Brotato-style item/weapon stacking and fast-paced wave combat (as requested).

Major systems
- Event Manager (LocalEventManager)
- Player / Character (`Scripts/character.gd`)
- Enemies (`Scripts/Enemy.gd`, `Systems/Enemy.tscn`)
- Stats system (`Systems/stats/stats.gd`)
- Weapons (`Systems/weapon/*`, WeaponHolder)
- Items (`Systems/Items/*`, Item, ItemHolder)
- ItemFactory (`Systems/Items/item_factory.gd`)
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

Architecture docs in next file
- Scene structure, design patterns, script responsibilities docs/architecture.md

Major systems (event manager, player, enemies, stats, weapons, items, itemFactory, modifiers, etc.) docs in folder docs/systems/*
- docs/systems/enemies.md
- docs/systems/event_manager.md
- systems/item_factory.md
- systems/items.md
- docs/systems/player.md
- systems/spawners.md
- systems/stage_manager.md
- systems/stats.md
- docs/systems/ui_shop_portal.md
- systems/weapons.md
