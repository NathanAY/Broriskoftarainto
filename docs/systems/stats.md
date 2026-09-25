# Stats

Purpose
- Central stat storage, modifier application and condition tracking for entities.

Key scripts / scenes
- `Systems/stats/stats.gd` (`Stats` class)

Data flow
- Inputs: base stat values (exported), `add_modifier` / `remove_modifier` calls from Items/Weapons, condition updates from managers, and modifiers claiming dynamic stats via `claim_provided_stat` / `release_provided_stat` (see "Provided (dynamic) stats" below).
- Processing: `get_stat()` computes final stat by applying all modifiers (flat then percent multipliers) and honoring conditional modifiers via `_check_condition()`.
- Outputs: emits `on_stat_changes` and `on_condition_change` events via `event_manager` when stats or conditions change.

Provided (dynamic) stats
- A behavior modifier can OWN a stat on the holder via `BaseModifier.provided_stat`. The stat is dynamic: it only exists while at least one such modifier is attached.
- `claim_provided_stat(stat_name, default_value)` installs the base value on first claim and bumps a reference count; `release_provided_stat(stat_name)` decrements and erases the stat key at zero. Both emit `on_stat_changes`.
- The modifier READS the stat (never writes it), so stat items/buffs/debuffs compose with its base and can drive the value negative. Two semantics:
  - Multiplier (e.g. `lifeleach`, base `1.0`): stacks drive the power, the stat scales it.
  - Additive shared (e.g. `armor`, `provided_stat_owned = false`): the stat already exists on the holder; the modifier is a pure consumer.

Units
- `movement_speed` is stored in meters per second (base default 0.25 m/s = 50 px/s). Use `get_movement_speed_px()` (or multiply by `Stats.PIXELS_PER_METER` = 200) when feeding velocity into physics, which works in pixels.

Dependencies
- Expects `event_manager` reference (exported or found on parent). Condition managers are added via `add_condition_manager`.

Known limitations / TODOs
- Modifiers are simple dictionaries; no ids or references to track duplicates beyond exact Dictionary matches.
- Condition manager lifecycle (removal) is TODO.
