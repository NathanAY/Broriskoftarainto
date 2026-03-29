# ItemFactory

Purpose
- Procedural generator for item resources used to populate drop pools or shop lists.

Key scripts / scenes
- `Systems/Items/item_factory.gd` (class_name `ItemFactory`)

Data flow
- Inputs: reads available stats from `Stats` instance, loads PackedScenes from `res://Systems/Items/Modifiers` and buff/debuff scenes.
- Processing: random roll decides between stat/effect/buff/debuff generators; creates `Item` resources with modifiers and optionally pre-configured PackedScenes.
- Outputs: returns an `Item` instance (or `null` if no sources available); maintains `drop_pool` cache.

Dependencies
- `Stats` node reference (onready `$Stats`), PackedScenes under `Systems/Items/Modifiers` and `Systems/Items/Buffs`.

Known limitations / TODOs
- `_load_scenes_from_dir` uses DirAccess and assumes folder layout; missing/misnamed folders will produce warnings.
- Random generation has some dead/experimental code paths (e.g., `return _generate_debuff_item()` placed before other roll checks) — indicates deliberate temporary behavior or debugging.
- Some generator logic assumes properties exist on instantiated effect scenes (e.g., `possible_trigger_event`) and will skip overrides otherwise.

Assumptions
- The `Stats` reference exists and exposes `stats` keys used for generating stat modifiers.
