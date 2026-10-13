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

Stats a modifier PUBLISHES
- Not owning a stat does not mean never writing one. A modifier that grants a per-stack amount nobody declares - `ArmorModifier`'s held-item armor, the regen modifiers' per-second rate - pushes it into the shared stat through `BaseModifier._publish_stat_value()`, which adds an ordinary modifier and takes it off again in `detach()`. This is what makes the amount visible: the stat panels list the stat, so an amount kept inside the modifier is one the player cannot see (the armor bug in `docs/systems/characters.md`).
- Because it is an ordinary modifier, a stat item / buff / debuff on the same stat composes with it and can drive it negative - which is how a life drain lands in the same row as the regen it cancels. The row is therefore the character's **net** rate.
- Three stats work this way and are not in `DEFAULT_STATS`: `armor`, `flat_regen_per_second` (HP/s) and `percent_regen_per_second` (percentage points of max HP per second, the `0-100` convention `critical_chance` uses). They appear in a stat list only while non-zero, and `ItemFactory.LISTENER_ONLY_STATS` keeps generated items from handing one out without the modifier that reads it.

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
