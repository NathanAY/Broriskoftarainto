# Items

Purpose
- Item `Resource`s provide stat modifiers, effects (Node behaviors from `effect_scene`), buffs/debuffs and condition managers to actors via `ItemHolder`.

Key scripts / scenes
- `src/Systems/Items/Item.gd` (class_name `Item`)
- `src/Systems/Items/item_holder.gd` (class_name `ItemHolder`)
- `src/Systems/Items/item_pickup.gd` (pickup behavior)
- `src/Systems/Items/item_builder.gd` (class_name `ItemBuilder`)
- `src/Systems/Items/item_price_analyzer.gd` (class_name `ItemPriceAnalyzer`) — prices items for the shop

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
- Processing: `Item.apply_to(holder)` adds stat modifiers to `Stats` and instantiates condition managers; the holder then attaches every scene in `Item.effect_scene` as its own child node (deduplicated per scene, stacked per copy) and manages the stacks. `Item.effect_scene_condition[i]` gates effect `i` - an empty or missing entry means always active.
- Outputs: Events emitted like `on_item_added`/`on_item_removed`; effects may attach to `EventManager`.

Pricing (items.md, catalog `ItemPriceAnalyzer`)
- `ItemPriceAnalyzer.get_price(resource)` classifies an offer and returns its shop cost:
  - stat item (no effect scene, no buff/debuff meta type) = 1
  - buff or debuff (`meta("type")` = `buff`/`debuff`) = 2
  - modifier (has an `effect_scene`) = 3
  - `BaseWeapon` = 5
- `get_sell_price(resource, ratio = 0.5)` sells a collected pickup at `round(price * ratio)` (min 1). The `ratio` is an optional callable parameter; shop default is 50% of the buy price.
- The shop (`ShopMenu`) holds a `PriceAnalyzer` node and uses it for both buy and sell buttons.
- **A stat item that rolled a harmful modifier is priced as a modifier (3), not as a stat item (1).** `get_price` only looks at whether `effect_scene` is non-empty, so the ~35% of generated stat items that carry a drain cross a price band. Intentional - the item really does run a behavior - but it means the stat-item tier is no longer a flat 1.

Polarity: positive half and curse
- An item's positive half and its curse can both be **behaviors**. `Item.effect_scene` is an `Array[PackedScene]`, so `ItemFactory` appends the harmful modifier as a second entry and `ItemHolder` gives each scene its own deduplicated node with its own stack. See `docs/systems/item_factory.md` for the roll and `docs/systems/modifiers.md` for how a modifier declares itself harmful.
- **Order matters:** index 0 is always the positive half. `effect_scene_condition` is a parallel array, so a gift-first ordering keeps index 0 meaning "always on unless the item says otherwise".
- A **stat** item has no positive scene, so when its curse is a modifier that scene is its *only* entry and its positive stat stays in `modifiers`. The card has to tell these two shapes apart - see `docs/systems/ui_shop_portal.md`.

Buffs and debuffs
- `src/Systems/Items/Buffs/buff.gd` (`Buff`) is the effect an item carries when it grants a temporary buff. It subscribes to its own `trigger_event` (`on_hit` by default), and every trigger calls `Stats.add_modifier()` **once per stack** - which is why three stacks of `attack_speed: {flat: 0.5}` move the stat by 1.5, and why the UI has to multiply rather than read the payload as-is. `max_stacks` is a FIFO cap: at the ceiling the oldest stack is expired to make room.
- `src/Systems/Items/Buffs/debuff_source.gd` (`DebuffSource`) is the mirror image, and lives on the **enemy**: it subscribes on the holder that carries the item and, on `after_deal_damage`, spawns a `Debuff` on `damage_context.target`.
- `src/Systems/Items/Buffs/debuff_instance.gd` (`Debuff`) is that spawned instance, and it lives on the **target**. A debuff does not stack at its source - every trigger makes a separate node - so the source is recorded on the instance as `Debuff.source`, and that back-reference is the only thing that lets two curses of one kind be grouped into one tile. `Debuff.timer` is the instance's own expiry timer, parented to the instance rather than to the target and started from `_ready()` (a `Timer` started off-tree does not run). `setup()` also carries `display_name` / `tooltip_text` through from the source.
- **Display fields.** `Buff` and `DebuffSource` each export `display_name` and `tooltip_text`, both defaulting to empty. They are display-only and power no stat, so no shipped `.tres` has to set them: the HUD falls back to the humanized primary stat. `Buff.stack_count()` and `Buff.remaining_time()` are the read-only accessors the UI reads, so nothing outside the class reaches into `_active_stacks`. `remaining_time()` reports the **soonest** stack, because that is the one whose lapse the tile's duration arc has to run out by.
- **The HUD's debuff row fills only when an enemy carries a debuff item**, and enemies carry no items in the shipped game - `src/Scripts/Enemy.gd` has the `add_item` line commented out. The row is reachable through the `Cursed enemies` debug scenario (see `docs/systems/debug_scenarios.md`), which hangs an `EnemyDebuffModifier` off the enemy spawner. Giving every enemy a debuff item in a real run would be a balance change, and `docs/systems/balance.md` governs those.
- Rendering: `src/ui/buff_ui.gd` (`BuffUi`) draws both rows as icon tiles - see `docs/systems/ui_shop_portal.md`.

Dependencies
- `Stats` (for stat modifiers), `EventManager` (for effect interactions), `ItemFactory` (for generating items at runtime), scene resources under `Systems/Items/Modifiers` (effects) and `Systems/Items/Buffs` (buffs/debuffs).

Known limitations / TODOs
- Removing condition managers when item is removed is TODO in `Item.remove_from()`.
- Item stacking/unique identification relies on scene instances and `effect_scene` resource paths; may need explicit IDs for complex interactions.
- **`DebuffSource` has no `max_stacks`.** A debuff is unbounded at its source by construction - every trigger spawns another `Debuff` - so a fast weapon can pile up far more instances than a buff ever stacks. The HUD groups them into one tile with a summed total, but the underlying count is not capped anywhere.
