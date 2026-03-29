# Items

Purpose
- Item `Resource`s provide stat modifiers, effect scenes (buffs/effects/debuffs) and condition managers to entities via `ItemHolder`.

Key scripts / scenes
- `Systems/Items/Item.gd` (class_name `Item`)
- `Systems/Items/item_holder.gd` (class_name `ItemHolder`)
- `Systems/Items/item_pickup.gd` (pickup behavior)

Data flow
- Inputs: `Item` resources are added via `ItemHolder.add_item()` (player or enemy).
- Processing: `Item.apply_to(holder)` adds modifiers to `Stats` and instantiates condition managers; holder may attach effect scenes as child nodes and manage stacks.
- Outputs: Events emitted like `on_item_added`/`on_item_removed`; effects may attach to `EventManager`.

Dependencies
- `Stats` (for modifiers), `EventManager` (for effect interactions), `ItemFactory` (for generating items at runtime), scene resources under `Systems/Items/Buffs` and `Modifiers`.

Known limitations / TODOs
- Removing condition managers when item is removed is TODO in `Item.remove_from()`.
- Item stacking/unique identification relies on scene instances and `effect_scene` resource paths; may need explicit IDs for complex interactions.
