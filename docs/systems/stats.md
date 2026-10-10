# Stats

Purpose
- Central stat storage, modifier application and condition tracking for entities.

Key scripts / scenes
- `src/Systems/stats/stats.gd` (`Stats` class)

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
- **Designer-facing distances are authored in meters; pixels exist only at the boundary.** `Stats.PIXELS_PER_METER` is `300.0`, and `meters_to_px()` / `px_to_meters()` are the only conversions. Prefer the helpers over multiplying by `PIXELS_PER_METER` inline: a call site then reads as meters and the world scale lives in one place. Pixels are for the physics server, a `Vector2` offset and a target selector's search radius - nowhere else.
- Meter-valued fields today: `movement_speed` (m/s, base `1.0`), `attack_range` (`1.67` m), `BaseWeapon.weapon_range` (`1.33` m on the base resource), a weapon's built-in knockback `strength` (m/s), and the explosion / bounce / homing / orbit radii. Each is converted by its own accessor or handler - `get_movement_speed_px()`, `BaseWeapon.get_range_px()`, `Explosion.get_radius_px()`, `KnockbackController.start_knockback()`, the bounce / homing / orb behavior nodes - so nothing downstream needs the scale.
- `movement_speed` base default is `1.0` m/s, i.e. 300 px/s; `get_movement_speed_px()` is what physics consumes. Movement speed was the original meter stat and the model the rest followed.
- The UI prints the authored meters with the unit (`range: 1.33 m`, `knocks back enemies at 1.0 m/s`). Keep the suffix when a tooltip surfaces one of these values; convert at the boundary, never in the tooltip.

Dependencies
- Expects `event_manager` reference (exported or found on parent). Condition managers are added via `add_condition_manager`.

Known limitations / TODOs
- Modifiers are simple dictionaries; no ids or references to track duplicates beyond exact Dictionary matches.
- Condition manager lifecycle (removal) is TODO.
