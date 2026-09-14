# Items

Purpose
- Item `Resource`s provide stat modifiers, effects (Node behaviors from `effect_scene`), buffs/debuffs and condition managers to actors via `ItemHolder`.

Key scripts / scenes
- `Systems/Items/Item.gd` (class_name `Item`)
- `Systems/Items/item_holder.gd` (class_name `ItemHolder`)
- `Systems/Items/item_pickup.gd` (pickup behavior)
- `Systems/Items/item_builder.gd` (class_name `ItemBuilder`)

Construction (single entry point)
- `ItemBuilder` is the canonical, static API for creating items from code. All construction goes through it:
  - `make_stat_item(name, description, modifiers)` — plain stat modifiers on the `Item`.
  - `make_effect_item(name, description, effect_scene, extra_modifiers = {})` — attaches an effect scene (optional extra modifiers, e.g. a negative trade-off).
  - `make_buff_item(name, description, stat_name, modifier_value, buff_scene)` — injects `{stat_name: modifier_value}` into a `buff.tscn` instance, repacks it via `pack_instance()`, sets `meta("type", "buff")` and leaves `item.modifiers` empty (temporary buff).
  - `make_debuff_item(...)` — same for `DebuffSource.tscn` with `meta("type", "debuff")`.
  - `pack_instance(instance)` — repacks a Node into a `PackedScene` (used to pre-configure effect/buff/debuff scenes before storage on an item).
  - `load_scenes_from_dir(path)` — loads all `.tscn` scenes from a directory.
- `ItemFactory` and `configure_panel.gd` build their items through `ItemBuilder`; no other code constructs `Item`s directly.

Data flow
- Inputs: `Item` resources are added via `ItemHolder.add_item()` (player or enemy).
- Processing: `Item.apply_to(holder)` adds stat modifiers to `Stats` and instantiates condition managers; holder may attach effect scenes as child nodes and manage stacks.
- Outputs: Events emitted like `on_item_added`/`on_item_removed`; effects may attach to `EventManager`.

Dependencies
- `Stats` (for stat modifiers), `EventManager` (for effect interactions), `ItemFactory` (for generating items at runtime), scene resources under `Systems/Items/Modifiers` (effects) and `Systems/Items/Buffs` (buffs/debuffs).

Known limitations / TODOs
- Removing condition managers when item is removed is TODO in `Item.remove_from()`.
- Item stacking/unique identification relies on scene instances and `effect_scene` resource paths; may need explicit IDs for complex interactions.
