# Damage

Purpose
- One pipeline every hit goes through, and the rules every hit obeys: crit, armor, listener order, and which hits count as a direct hit.
- The principle: **`Stats` holds numbers, the damage pipeline does the math, items add stats or unique behaviour.** Crit and armor are core steps that read stats, not item effects; an item that only grants crit or armor is a stat item.

Key scripts
- `src/Systems/damage/damage.gd` (`Damage`) — `deal()`, the crit roll, the armor formula, the `PHASE_*` constants.
- `src/Systems/damage/damage_context.gd` (`DamageContext`) — one hit as it travels the pipeline.
- `src/Systems/damage/health.gd` (`Health`) — `apply_damage()`, the defender half.
- `src/Scripts/LocalEventManager.gd` (`EventManager`) — `subscribe(event, listener, phase)`.

## Dealing damage
Build a `DamageContext` and call `Damage.deal(ctx, attacker_bus)`. That is the whole contract for a new damage source; never emit the damage events yourself.

```
var ctx := DamageContext.new()
ctx.source = self                 # what physically hit
ctx.target = body                 # must own a Health child
ctx.weapon = weapon               # set only for a direct weapon hit
ctx.base_amount = damage
ctx.final_amount = damage
ctx.tags.append("projectile")
Damage.deal(ctx, event_manager)   # returns true when the hit landed
```

`deal()` runs, in this fixed order:
1. `before_deal_damage` on the attacker's bus — attacker bonuses (e.g. `PlusDamageToHealthyTargetModifier`).
2. **Crit roll** — `critical_chance` (0-100) on the attacker's `Stats`; a crit multiplies `final_amount` by `critical_multiplier`, sets `is_crit` and emits `on_crit`. Skipped when `ctx.can_crit` is false.
3. `Health.apply_damage()` on the target: **armor** (`final_amount *= 10 / (10 + armor)`, negative armor amplifies) → `before_take_damage` → subtract → `on_death` if lethal → `after_take_damage`. Returns false (and nothing below runs) when the target is already dead.
4. `after_deal_damage` — every landed hit; damage numbers read it.
5. `on_hit` — **direct hits only** (`ctx.weapon != null`).
6. `on_kill` — when this hit killed the target.

Dead targets: `Health` latches `is_dead` on the killing blow and rejects every later hit, because a dying entity stays in the tree for its whole death animation (~0.7s for an `Enemy`). Without that, a corpse would keep flashing, bursting and paying `on_kill` rewards. Do not guard damage with the owner's private state or groups; `Health` is the backstop.

`ctx.attacker` is filled in from the bus's owner, so the crit roll reads the right `Stats`. With a null bus (no attacker) only step 3 runs.

## Direct hits and secondary damage
- A **direct hit** is one a weapon landed: projectiles fired by a weapon (`Projectile.source_weapon`), melee swings, aura and contact weapons. Only these emit `on_hit`, so only they proc on-hit effects (poison, knockback, life leech, chain, explosive shot, bombs).
- **Secondary damage** has no weapon: explosions, orbs, death bursts, poison ticks, and projectiles spawned by modifiers (chain, homing rocket, reflect). It still deals damage, crits, shows numbers and reports `on_kill`, but never procs on-hit effects — so effects cannot chain into more of themselves.
- **Damage over time never crits.** `poison_effect.gd` sets `can_crit = false`.
- Life drain (`regen_modifier.gd`) has no attacker and calls `Health.apply_damage()` directly, so armor still applies to it but nothing is emitted on an attacker's bus.

## Listener phases
Several listeners change `final_amount` on the same event, so their order matters. Listeners pass a phase to `subscribe()`; lower runs first, equal phases keep subscription order:

| Phase | Use | Listeners |
|---|---|---|
| `PHASE_MODIFY` (0, default) | grow or shrink the hit | plus-damage-to-healthy |
| `PHASE_MITIGATE` (100) | block or reduce it | `front_shield.gd` |
| `PHASE_ABSORB` (200) | soak what is left | `energy_shield_modifier.gd` |
| `PHASE_OBSERVE` (1000) | read the settled number | hit flash, heal numbers, reflect, homing rocket |

Armor is not a listener: it runs inside `Health.apply_damage()` before every `before_take_damage` listener, so the energy shield soaks the armor-reduced hit.

## DamageContext fields
- `attacker` — entity whose `Stats` / `EventManager` the hit uses. `source` — the projectile, orb, explosion or holder that hit; position-based listeners (knockback, front shield) read it. `target` — the entity hit.
- `weapon` — the weapon behind a direct hit, or null. Weapon-bound modifiers (`BaseModifier.bound_weapon`) filter on it through `BaseModifier.event_weapon()`.
- `base_amount`, `final_amount`, `can_crit`, `is_crit`, `energy_shield_absorbed`, `damage_type`, `tags`.
- `fraction_of_max_health` — set by `Health` after the hit lands; hit particles and death bursts scale by it.
- Damage events carry only `{"damage_context": ctx}`. Read the target, source and weapon from the context, not from extra payload keys.

Tests
- `test/Systems/damage/test_damage_pipeline.gd` — event order, direct vs secondary hits, crit, poison not critting, armor from the stat alone, listener phases, and a real player critting from the stat with no item.
- `test/Systems/damage/test_dead_target_damage.gd` — a corpse rejects every later hit.
