# Event Manager

Purpose
- Lightweight pub/sub event bus used to decouple systems.
- Every event is governed by a contract (`EventContracts`) that enforces a single-Dictionary payload convention and arity-1 listeners at both subscribe and emit time.

Key scripts / scenes
- `src/Scripts/LocalEventManager.gd` (class_name `EventManager`)
- `src/Scripts/event_contract.gd` (class_name `EventContracts`): registry of event schemas + `check_emit` / `check_subscribe` / `report`.

Data flow
- Inputs: `subscribe(event_name, Callable)`, `unsubscribe(event_name, Callable)`, `emit_event(event_name, payload)`.
- Processing:
  - `subscribe` validates event name against `EventContracts.SCHEMAS` and that the listener takes exactly one argument (the payload dict). Rejections are reported and the listener is NOT registered.
  - `emit_event` validates the payload is a single Dictionary containing all required keys of the schema. Rejections are reported and the event is dropped (no listeners called).
  - Both return an `EventContracts.CheckResult` (`ok`/`reason`/`detail`).
  - Reporting is debug-only: `EventContracts.report()` calls `push_error` only in debug builds. Validation/rejection always applies.
  - Accepted emissions dispatch listeners with a single Dictionary argument: `listener.call(payload)`.
- Outputs: invokes listener callables with the payload dict; used to notify stat changes, item add/remove, damage events, etc.

Payload convention
- The payload is ALWAYS a single Dictionary. Examples:
  - `event_manager.emit_event("on_hit", {"damage_context": ctx, "body": body})`
  - `event_manager.emit_event("on_stat_changes", {"stat_name": "speed", "final_value": 12.0})`
- Emitting an array (the legacy `[{...}]` form), a non-Dictionary value, an unregistered event name, or a payload missing a required key is a hard error in debug builds (event dropped / subscribe refused).

Event schema (required keys; extra keys are tolerated)
- Damage pipeline: `before_deal_damage`, `before_take_damage`, `after_take_damage`, `after_deal_damage`, `on_hit`, `on_kill` -> `damage_context`
- Combat: `on_attack` -> `weapon`
- Stats / conditions: `on_stat_changes` -> `stat_name`, `final_value`; `on_condition_change` -> `condition_name`, `value`
- Equipment / inventory: `on_weapon_changes` -> `weapon_inst`; `on_item_added` / `on_item_removed` -> `hold_owner`, `item`, `items`
- Health: `on_heal`, `on_health_changed` -> `self`, `amount`, `current_health`, `max_health`; `on_death` -> `self`, `damage_context`
- Buffs / debuffs: `on_buff_added` / `on_buff_removed` -> `buff`, `holder`, `id`; `on_debuff_added` / `on_debuff_removed` -> `debuff`, `holder`, `target`
- Misc: `on_crit` -> `damage_context`; `on_shield_changed` -> `self`, `amount`, `current_shield`, `max_shield`

**The buff / debuff schema is unchanged and needs no change.** `on_buff_added` / `on_buff_removed` carry `buff`, `holder`, `id`; `on_debuff_added` / `on_debuff_removed` carry `debuff`, `holder`, `target` — and that is sufficient for everything the HUD reads. The display fields added to `Buff` and `DebuffSource` (`display_name`, `tooltip_text`, `Debuff.source`, `Debuff.timer`) live on the **node the payload points at**, not in the payload, precisely so no event schema had to widen. Widening it to carry a flattened `display_name` would be the mistake here: a listener can already reach it through `buff` / `debuff`.

Damage pipeline ownership
- The six damage-pipeline events split across two buses, and the split matters when writing a new damage source:
  - **Attacker side**, emitted by the weapon/effect on its own (the holder's) bus: `before_deal_damage` -> [armor, crit, high-HP modifiers] -> ... -> `after_deal_damage`, `on_hit`, `on_kill`.
  - **Defender side**, emitted by `Health.apply_damage()` on the *target's* bus: `before_take_damage` -> subtract -> `on_death` (if lethal) -> `after_take_damage`. The order is fixed, and `target_take_persent_damage` is set before `on_death` so listeners can scale by it.
- `Health.apply_damage(damage_context) -> bool` (`src/Systems/damage/health.gd`) is the ONLY way to damage anything. Do not emit `before_take_damage` / `after_take_damage` yourself and do not call `take_damage` (removed); hand the context over and let `Health` run the phase. That is what makes the dead check unbypassable.
- It latches `Health.is_dead` on death, so every hit after the killing blow is rejected: no `HitFlashManager` flash, no `ParticleEffectManager` particles, no `TextureBurstManager` burst, no `on_death`, no `on_health_changed`. This matters because a dying entity stays in the tree for its whole death animation (an `Enemy` is freed from the `death` animation's `animation_finished`, ~0.7s later).
- `false` means the hit did not land. Skip `after_deal_damage` / `on_hit` / `on_kill` in that case, otherwise kill rewards (e.g. `StatOnKillModifier`) and the attacker's hit modifiers fire once per corpse. Note the `on_kill` guards in the weapons read `current_health <= 0`, which is only reachable on the killing blow for the same reason.
- Do not guard damage by reading the owner's private state (`Enemy._alive`) or its groups: a dying enemy has already left `damageable`, but rays and already-registered overlaps can still resolve it, so `Health` is the backstop.

Weapon attribution on hit events
- `on_hit`, `on_kill` and `after_deal_damage` now consistently carry the firing weapon as an extra `"weapon"` key:
  - melee (`melee_weapon_node.gd`) and contact/area weapons (`contact_weapon.gd`, `area_weapon.gd`) pass their weapon resource directly;
  - projectiles (`projectile.gd`) report `"weapon": source_weapon`, a back-link to the firing `BaseWeapon` set by `ProjectileWeapon.shoot_projectile`.
- This lets weapon-bound modifiers (see `bound_weapon` in `docs/systems/modifiers.md`) filter events to exactly the hits their own weapon caused. Secondary hits that never had a weapon (e.g. `explosion.gd`, `orbiting_orb.gd`) simply carry no `weapon`, so weapon-bound modifiers correctly ignore them.

Adding a new event
- Register a schema entry in `EventContracts.SCHEMAS` (file `src/Scripts/event_contract.gd`), then emit/subscribe; the bus will not accept the event until the schema exists.

Dependencies
- `LocalEventManager` depends on `EventContracts` (autoload/class registry). Systems obtain a reference (often via `@onready` or parent-child wiring).

Known limitations / TODOs
- No protection against slow/failing listeners (no try/catch around calls).
- No priority ordering or one-shot listener mode (can be emulated by unsubscribe inside handler).
- Listener arity is checked via `Callable.get_argument_count()` and must equal 1.