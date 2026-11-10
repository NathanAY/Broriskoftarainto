# Gamepedia

The in-game encyclopedia, opened by a **Gamepedia** button on the main menu (`src/Scenes/menu/Main.tscn`) and the pause menu (`src/Scenes/menu/PauseMenu.tscn`). Four tabs: **Characters**, **Weapons**, **Enemies**, **Modifiers**.

## Files
- `src/Systems/gamepedia/gamepedia_data.gd` (`GamepediaData`) — reads the shipped data and returns plain dictionaries. No numbers live here.
- `src/Systems/gamepedia/gamepedia.gd` (`Gamepedia`) — a `CanvasLayer` built entirely in code; it only lays the dictionaries out. It emits `closed` from its Back button.
- Each menu does `Gamepedia.new()` + `add_child()` on press, hides its own `Control`, and frees the panel on `closed`. The panel has no scene file.

## Layout
Every entry is an `IconCard` (`src/ui/icon_card.gd`) — the same tile the character select screen and the character menu's Weapons grid use — with the entry's text beside it. Characters and weapons hand the tile their resource (`IconCard.set_display`), so they get the layered character portrait and the weapon sprite. Enemies and modifiers are bare textures: they go through `ItemIconGenerator.make_composite_icon`, the compositor an item's effect icon uses, so large source art is mipmapped on the way down. An `IconCard` only fills itself once it is in the tree, so `_add_entry` attaches the row before the caller fills the tile.

## Where each tab reads from
| Tab | Source | Shown |
|---|---|---|
| Characters | every `CharacterData` `.tres` under `src/Assets/character/` (recursive, like character select) | `ItemTooltip.card_rows`: description, base stats, effects, starting gear |
| Weapons | every `.tres` in `src/Resources/weapons/` and `src/Resources/weapons/boss/` (not the `aim/` selectors) | the same rows as the shop's weapon card (`ItemTooltip.weapon_card_rows`): damage, range, attack speed, subclass extras, built-in effects |
| Enemies | every `Enemy*.tscn` in `src/Systems/enemies/`, instantiated and freed (never added to the tree); art is its `Node2D/Sprite2D` texture | health and movement speed from the scene's `Stats` over `Stats.DEFAULT_STATS`, plus each weapon it attacks with (`contact_weapon` and the `WeaponHolder` list) |
| Modifiers | every `.tscn` in `src/Systems/Items/modifiers/`; art is `src/Assets/modifiers/<scene name lowercased>.png`, else `_default.png` — the lookup `ItemIconGenerator` does | `ItemTooltip.resolve_effect_display`: name, description, live stats fragment, trigger. A `COST` modifier's name is red |

Adding a character, weapon, enemy scene or modifier scene to its folder adds it to the Gamepedia with no code change. An enemy's name is its scene name without the `Enemy` prefix; the bare `Enemy.tscn` is shown as the Grunt.

## Tests and preview
- `test/ui/test_gamepedia.gd` — run with `.\run_tests_gdunit_custom.bat gamepedia`. Expectations are derived from the same data, never pinned as literals, and a sweep asserts every tile in every tab holds an image.
- `test/tools/gamepedia_preview.tscn` — the panel on its own for `.\run_scene_shot.bat res://test/tools/gamepedia_preview.tscn`; change `TAB` in its script to look at another tab.
- New `class_name` files need a `godot --headless --path . --import` once before the test runner can resolve them.
