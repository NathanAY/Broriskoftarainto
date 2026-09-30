# ItemFactory

Purpose
- Procedural generator for item resources used to populate drop pools or shop lists.

Key scripts / scenes
- `Systems/Items/item_factory.gd` (class_name `ItemFactory`)

Data flow
- Inputs: reads available stats from `Stats` instance plus the union of `provided_stat` names advertised by every Modifier scene (`_candidate_stat_names()`), and loads PackedScenes from `res://src/Systems/Items/Modifiers` and buff/debuff scenes — so generated stat items / debuffs can target dynamic stats like `lifeleach` even before any owning modifier is attached.
- Processing: random roll decides between stat/effect/buff/debuff generators; creates `Item` resources with modifiers and optionally pre-configured PackedScenes.
- Outputs: returns an `Item` instance (or `null` if no sources available); maintains `drop_pool` cache. `get_random_weapon()` lazily loads `BaseWeapon` resources from `res://src/Resources/weapons` and returns a random one (used by the shop).

Dependencies
- `Stats` node reference (onready `$Stats`), PackedScenes under `Systems/Items/Modifiers` and `Systems/Items/Buffs`.

Gift and curse (the negative half)
Every generated item is a positive half plus a curse, and the curse is one of two things:
- a **negated stat** (`{stat: {"flat": -x}}` in `Item.modifiers`) - always been the case; or
- a **harmful modifier** (`effect_kind = COST`, e.g. a life drain) appended as a second `Item.effect_scene` entry.

- `const NEGATIVE_MODIFIER_CHANCE := 0.35` decides which, once per item, via `_roll_negative_modifier()`. The two are **alternatives, never both** - an item never gets a double penalty from one roll.
- All four generators (`_generate_stat_item`, `_generate_effect_item`, `_generate_buff_item`, `_generate_debuff_item`) roll it.
- **The positive half may only roll a BENEFIT and the curse only a COST.** `_benefit_effect_scenes()` / `_cost_effect_scenes()` partition `effect_scenes` by `BaseModifier.effect_kind` (built once by `_rebuild_scene_pools()`). Without the split the shop can offer "Grants special effect: Life Drain" as an upside. Adding a harmful modifier to the folder and tagging it `COST` is all it takes to widen the pool.
- A harmful scene is appended **after** the positive one, so `effect_scene[0]` still reads as the gift and `effect_scene_condition` stays aligned.
- `_roll_negative_stat(exclude, ...)` never picks the stat the positive half already uses. Picking it again collapses both halves onto one key, and since `Dictionary.merge()` does **not** overwrite by default the curse would silently vanish, yielding a free item.
- A **stat** item's curse scene is its only entry, so its positive stat remains in `modifiers` and the card must keep rendering it as a gain (`ItemTooltip._append_modifier_rows`).
- Buff/debuff items render their payload from scene 0 and any appended curse from scene 1 onwards, on both the card and the flat tooltip.
- `ItemPriceAnalyzer.get_price` only checks whether `effect_scene` is non-empty, so a stat item that rolled a curse is priced as a modifier (3) rather than a stat item (1).
- Covered by `test/Systems/Items/test_item_factory_polarity.gd`. The chance is a const, so its tests pin `rng.seed` and draw a batch: a fixed seed makes "both branches appear" deterministic rather than flaky. `test_item_pickup.gd` pins its seed for the same reason.

Known limitations / TODOs
- `_load_scenes_from_dir` uses DirAccess and assumes folder layout; missing/misnamed folders will produce warnings.
- `RegenModifier.tscn` (the abstract `regen_modifier.gd` base with no behaviour) lives in the same folder and is therefore loaded as an offerable scene, so an "effect item" can roll a modifier that does nothing. Pre-existing.
- Random generation has some dead/experimental code paths (e.g., `return _generate_debuff_item()` placed before other roll checks) — indicates deliberate temporary behavior or debugging.
- Generation-time randomization lives in the modifiers, not the factory: a modifier scene that supports it implements `randomize_for_generation(context) -> bool` (context: `{"rng": RandomNumberGenerator, "stats": Dictionary}`) and owns its own rolls — e.g., `HealOnEventModifier` picks from its `possible_trigger_event` table, `StatOnKillModifier` rolls a random `target_stat` from `Stats` plus a scaled `add_amount`. `ItemFactory._configure_dynamic_modifier` only builds the context, calls the hook when present, and repacks on mutation; scenes without the hook pass through untouched. Modifiers may also expose `get_generation_suffix()` so generated item names stay distinguishable (e.g., `Stat On Kill Modifier (movement_speed)`).
- The build-time display cache (`_store_effect_display`) is an Array aligned **by index** with `item.effect_scene`. Keying by scene path would not work, because repacked randomized modifiers have an empty `resource_path`.

Assumptions
- The `Stats` reference exists and exposes `stats` keys used for generating stat modifiers.
