# ItemFactory

Purpose
- Procedural generator for item resources used to populate drop pools or shop lists.

Key scripts / scenes
- `Systems/Items/item_factory.gd` (class_name `ItemFactory`)

Data flow
- Inputs: reads available stats from `Stats` instance, loads PackedScenes from `res://src/Systems/Items/Modifiers` and buff/debuff scenes.
- Processing: random roll decides between stat/effect/buff/debuff generators; creates `Item` resources with modifiers and optionally pre-configured PackedScenes.
- Outputs: returns an `Item` instance (or `null` if no sources available); maintains `drop_pool` cache.

Dependencies
- `Stats` node reference (onready `$Stats`), PackedScenes under `Systems/Items/Modifiers` and `Systems/Items/Buffs`.

Known limitations / TODOs
- `_load_scenes_from_dir` uses DirAccess and assumes folder layout; missing/misnamed folders will produce warnings.
- Random generation has some dead/experimental code paths (e.g., `return _generate_debuff_item()` placed before other roll checks) — indicates deliberate temporary behavior or debugging.
- Generation-time randomization lives in the modifiers, not the factory: a modifier scene that supports it implements `randomize_for_generation(context) -> bool` (context: `{"rng": RandomNumberGenerator, "stats": Dictionary}`) and owns its own rolls — e.g., `HealOnEventModifier` picks from its `possible_trigger_event` table, `StatOnKillModifier` rolls a random `target_stat` from `Stats` plus a scaled `add_amount`. `ItemFactory._configure_dynamic_modifier` only builds the context, calls the hook when present, and repacks on mutation; scenes without the hook pass through untouched. Modifiers may also expose `get_generation_suffix()` so generated item names stay distinguishable (e.g., `Stat On Kill Modifier (movement_speed)`).

Assumptions
- The `Stats` reference exists and exposes `stats` keys used for generating stat modifiers.
