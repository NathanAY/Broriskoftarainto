# Main rules if changing project
- After any feature implementation: 1. Create a test 2. Read failures 3. Fix the test/code 4. Run test again
- Task -> Read relevant code -> Read testing rules/docs -> Write test -> RUN TEST -> Read error -> Fix -> RUN TEST again -> Done
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
- Example how to run GDUnit4 specific tests: `.\run_tests_gdunit_custom.bat test_stat_creation_stat.gd`

### `run_tests_gdunit_custom.bat` uses fuzzy test lookup
The argument is matched case-insensitively against test suite paths under `test/`; `.gd`, folders and slashes/backslashes are optional, so all of these run the same suite:
- `.\run_tests_gdunit_custom.bat Systems/Items/test_pierce_stat.gd`
- `.\run_tests_gdunit_custom.bat pierce_stat`
- `.\run_tests_gdunit_custom.bat Systems\Items` (directory -> all suites inside)

Other behavior:
- Partial words match several suites at once (e.g. `modifier` -> 7 suites, all run).
- Only `test_*.gd` files are fuzzy-matched, so shared helper scripts are not run as suites.

## Visual checks (rendering a scene to a PNG)
Tests assert structure, not looks. After changing a UI, render it:
```
.run_scene_shot.bat res://path/to/Scene.tscn [res://out.png]
```
- Writes `res://scene_shot.png` by default, prints the path, and quits. Measured at ~1.5s end to end, because run, capture and quit all happen inside that one call.
- **Prefer this over MCP for a plain render.** Every tool call is a separate round trip that costs model time before the request is even sent, so `run_project` + `get_runtime_screenshot` + `stop_project` is 3 calls and several times slower for the same PNG.
- The window flashes up briefly — a headless viewport has no framebuffer to read back.
- The target scene must render standalone (no gameplay set up behind it). `res://test/tools/character_ui_preview.tscn` and `res://test/tools/shop_ui_preview.tscn` exist for the character menu and the shop, which both need a character in `GlobalGameState.current_character`.

### MCP screenshots (live game, when you need to interact first)
`get_editor_screenshot` (2D/3D viewport), `run_project` and `get_runtime_screenshot` Use them when the check needs a running game rather than a one-shot render: firing `simulate_input_action`, inspecting nodes mid-run, or screenshotting after several actions. `stop_project` exits cleanly, leaving only the editor process.

# Project documentation.
- This is top-down brotato style rogulike game project on godot 4.6.
- If docs outdatet than updated them.

## The most important docs located by those path:
- docs/ai_overview.md
- docs/architecture.md

## Major systems (event manager, player, enemies, stats, weapons, items, itemFactory, modifiers, etc.) docs in folder docs/systems/*
- docs/systems/enemies.md
- docs/systems/event_manager.md
- docs/systems/item_factory.md
- docs/systems/items.md
- docs/systems/modifiers.md
- docs/systems/player.md
- docs/systems/spawners.md
- docs/systems/stage_manager.md
- docs/systems/stats.md
- docs/systems/ui_shop_portal.md
- docs/systems/weapons.md

## Dev tooling (`test/tools/`, not shipped)
- `test/tools/scene_shot.tscn` + `test/tools/scene_shot.gd` — instantiates a scene named by `OS.get_cmdline_user_args()`, screenshots it, quits. Driven by `run_scene_shot.bat`.
- `test/tools/character_ui_preview.tscn`, `test/tools/shop_ui_preview.tscn` — the character menu and the shop with a stub character wearing sample items/weapons, so they render standalone for a visual check.
- The shop fixture pins its offers: it builds its own `ItemFactory` (which needs a `Stats` child), seeds `drop_pool` with a fixed `rng.seed`, and calls `load_items([])` to jump from phase 1 (icon tiles) to phase 2 (the card row whose `InfoLabel` carries the tone-coloured stat body). Phase 1 shows icons only, so it cannot show card colours. The offer pool is small and weighted (`_offer_items()`) because `get_item_from_pool_or_generate()` picks *with* replacement, so a big pool would leave the items you care about off the 4-card row. The character menu only renders icon tiles, so card-body checks must go through the shop fixture.
- `SAMPLE_ITEMS` in the character fixture is the place to add an item you want to see rendered. Neither preview is named `test_*.gd`, so the gdUnit and GUT runners skip them.
