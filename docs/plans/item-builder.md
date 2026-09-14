# Goal
Remove duplicated item-construction logic behind one canonical, static ItemBuilder API, and fix the buff/debuff divergence where three call sites build items differently.

## 1. New file: src/Systems/Items/item_builder.gd
class_name ItemBuilder — all static funcs, no Node/autoload/scene needed:
- make_stat_item(name: String, description: String, modifiers: Dictionary) -> Item
- make_effect_item(name: String, description: String, effect_scene: PackedScene, extra_modifiers: Dictionary = {}) -> Item
- make_buff_item(name: String, description: String, stat_name: String, modifier_value: Dictionary, buff_scene: PackedScene) -> Item
  - canonical semantics = ItemFactory's: instantiate buff.tscn, inject {stat_name: modifier_value} into the instance's modifiers, repack via pack_instance(), set meta("type","buff"), leave item.modifiers empty (it's a temporary buff).
- make_debuff_item(...) — same, using DebuffSource.tscn, meta("type","debuff"), keeps item.modifiers empty.
- pack_instance(instance: Node) -> PackedScene — the shared repack trick.
- load_scenes_from_dir(path: String) -> Array[PackedScene] — the shared dir loader.

## 2. Refactor src/Systems/Items/item_factory.gd
- Collapse the twin pairs _generate_X_item / _generate_X_item_insexed into single funcs taking index := -1 (kills ~150 duplicated lines).
- Each generator builds via ItemBuilder.make_* (stat/effect/buff/debuff), keeping its current naming/description/negative-modifier flavor.
- _load_scenes_from_dir and the repack inside _configure_dynamic_modifier delegate to ItemBuilder.

## 3. Refactor src/Scenes/menu/configure_panel.gd
- _create_stat_item, _create_simple_item, _create_effect_item, _create_buff_item, _create_debuff_item become thin wrappers: build via ItemBuilder.make_*, then add to holder + refresh UI.
- _populate_effect_items uses ItemBuilder.load_scenes_from_dir for the scene list.

## 4. Update existing tests to use the builder
- test_bounce_modifier.gd:34 → ItemBuilder.make_effect_item(...)
- test_buff_in_combat.gd:26 → ItemBuilder.make_buff_item("attack_speed", {"flat": 2.5}, load(buff.tscn)) — behavior changes: the buff will now actually receive the requested modifier (previously it silently used the scene's hardcoded default). Expect existing assertions to need adjustment; will verify per AGENTS.md loop.
- test_items_gut.gd → make_stat_item for stat items, make_effect_item + pack_instance for the doubler.
- test_item_factory_gut.gd:30 → make_stat_item.
- test_item_sacrifice_altar_gdunit4.gd — leave as plain Item.new() (it's a bare holder test, not a shape).

## 5. New test (per AGENTS.md: test → run → fix → rerun)
test/Systems/Items/test_item_builder_gdunit4.gd: each make_* returns an Item with correct name/modifiers/effect_scene; buff/debuff items carry the right meta and their packed scene instantiates with the injected modifier; pack_instance returns an instantiable scene with the config preserved.

Run with .\run_tests_gdunit_custom.bat test_item_builder_gdunit4.gd, then full .\run_tests_gdunit.bat.

## 6. Docs
Update docs/systems/items.md to document ItemBuilder as the single item-construction entry point.