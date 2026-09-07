# Main rules if changing project
- After any feature implementation: 1. Create a test 2. Read failures 3. Fix the test/code 4. Run test again
- Task -> Read relevant code -> Read testing rules/docs -> Write test -> RUN TEST -> Read error -> Fix -> RUN TEST again -> Done
- After any changes add it it AGENTS_history.md file.
- If you have questions or options for some implementation than ask about it.

# Core systems

## Player & combat
- `Scripts/character.gd`: player entity holds `WeaponHolder` and `ItemHolder` children.
- `Systems/damage/health.gd`: health/stats subsystem (uses modifiers and conditions).

## Items & modifiers
- `Scripts/item_pickup.gd`: item pickup logic.
- `Scripts/item_factory.gd`: generates item Node instances from `.tres` resources.
- `Systems/Items/item_holder.gd`: holds items; attaches modifier children to stats node.
- Modifiers live in `Systems/Items/Modifiers/`. They are attached via `ItemHolder`, subscribe to events (`on_attack`, `on_hit`, `on_stat_changes`), and manipulate the holder's `Stats`/`Health` nodes.

# Testing

## Setup and run test
- Example how to run GDUnit4 all tests: `.\run_tests_gdunit.bat`
- Example how to run GDUnit4 specific test: `.\run_tests_gdunit_custom.bat test_stat_creation_stat.gd`

# Project documentation.
- This is top-down brotato style rogulike game project on godot 4.6.
- If you think that some of the doc files outdated or need some changes just suggest to update it.

## The most important docs located by those path:
- \docs\ai_overview.md
- \docs\architecture.md

# Major systems (event manager, player, enemies, stats, weapons, items, itemFactory, modifiers, etc.) docs in folder docs/systems/*
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
