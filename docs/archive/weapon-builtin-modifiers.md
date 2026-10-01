# Weapon Built-in Modifiers Plan

## Goal

Give individual weapons their own built-in combat effects, scoped to exactly that weapon — not the holder:

- **Fist** → knockback
- **Knife** → poison
- **Pistol** → pierce (penetration) + knockback

The core requirement: if a holder has a poisoned knife AND a knockbacking fist, the fist's hits must **not** poison and the knife's hits must **not** knock back. Effects apply only to events emitted by the weapon that declared them.

This is implemented as a general *weapon-scoping system* over the existing EventManager bus and modifier scripts, so any current/future on-hit modifier can be bound to a weapon without duplicating its logic.

## Current gaps (verified in code)

1. **No weapon attribution on hits.** `on_hit`/`on_kill` payloads vary by emitter:
   - melee: `{"melee": self, ...}` (node has `.weapon_data`) — `melee_weapon_node.gd:271`
   - projectile: `{"projectile": self, ...}` — NO back-link to the firing weapon (`projectile.gd:101`)
   - contact/area: `{"weapon": self, ...}` — already carry it (`contact_weapon.gd:86`, `area_weapon.gd:29`)
2. **Holder-wide modifier leakage.** `knockback_modifier.gd` and `poison_modifier.gd` subscribe to the holder's bus and react to *every* hit, from any weapon. (knockback_modifier.gd:21/33, poison_modifier.gd:24)
3. **Dead config field.** `BaseWeapon.modifiers: Dictionary` (`BaseWeapon.gd:10`) is exported but never read — perfect spot for the per-weapon declaration.
4. **Freed listeners crash the bus.** `EventManager.emit_event` calls listeners with no `!l.is_valid()` check (`LocalEventManager.gd:29`), so any detach path must explicitly unsubscribe before freeing nodes.
5. **Pre-existing double knockback for projectiles.** `knockback_modifier._on_attack` attaches a `KnockbackBehavior` to projectiles AND `_on_hit` knocks back again on the projectile hit. We fix this while adding the guard.

## Design

Two mechanisms work together:

**A. Spawn-time built-ins** (`pierce`): merged into the projectile's `properties` in `ProjectileWeapon.shoot_projectile`, on top of the existing stats (e.g. `projectile_pierce`). No node, no event.

**B. Hit-event built-ins** (`knockback`, `poison`): reuse the existing modifier scripts (`knockback_modifier.gd`, `poison_modifier.gd`) as real modifier nodes, but **bind** them to one weapon instance via a new `bound_weapon` field on `BaseModifier`. Their handlers bail out on any event whose `weapon` isn't the bound one.

Per-weapon config lives in each `.tres` under `BaseWeapon.modifiers`, e.g.:

```
modifiers = {
  "knockback": { "strength": 250.0, "duration": 0.2 },
  "poison":    { "chance": 0.5, "duration": 3.0, "tick_interval": 1.0, "max_stacks": 3 },
  "pierce":    { "amount": 1 }
}
```

Keys not in the registry are ignored, so the system is extensible by design.

---

## Step 1 — Consistent `weapon` attribution on every hit event

Add the firing weapon to all hit payloads (extra keys are tolerated by `EventContracts`; `event_contract.gd:34`).

- `src/Systems/weapon/melee_weapon_node.gd`
  - `do_damage`: add `"weapon": weapon_data` to `after_deal_damage` (line 269), `on_hit` (271), `on_kill` (273). (`on_attack` at line 50 already has it.)
- `src/Systems/weapon/projectile.gd`
  - Add `var source_weapon: Object = null` (holds the firing `BaseWeapon` resource).
  - `do_damage`: add `"weapon": source_weapon` to `after_deal_damage` (99), `on_hit` (101), `on_kill` (103).
- `src/Systems/weapon/projectile_weapon.gd`
  - In `shoot_projectile`, before `add_child` (line 46): `p.source_weapon = self`. (`on_attack` already passes both keys.)
- `src/Systems/weapon/contact_weapon.gd` / `area_weapon.gd`
  - Add `"weapon": self` to their `after_deal_damage` payloads (contact:84, area:27) for consistency (rest already carry it).

`explosion.gd` / `orbiting_orb.gd` stay unmodified — secondary hits carry no weapon, so weapon-bound modifiers correctly ignore them.

## Step 2 — `BaseModifier` gains weapon binding + clean detach

`src/Systems/Items/Modifiers/base_modifier.gd`:

```
## When non-null, handler events must carry this exact weapon to fire.
var bound_weapon: Object = null

func _is_bound_event(data: Dictionary) -> bool:
    if bound_weapon == null:
        return true            # item-pickup path: holder-wide, unchanged
    return data.get("weapon") == bound_weapon

# Track subscriptions so we can silently detach (EventManager crashes on freed listeners).
var _subscriptions: Array = []   # each entry: [event_name, callable]
func _subscribe(event_name: String, listener: Callable) -> void:
    _subscriptions.append([event_name, listener])
    event_manager.subscribe(event_name, listener)

func detach_from_event_manager() -> void:
    for sub in _subscriptions:
        if is_instance_valid(event_manager):
            event_manager.unsubscribe(sub[0], sub[1])
    _subscriptions.clear()
```

## Step 3 — Guard the built-in-enabled modifiers

- `src/Systems/Items/Modifiers/knockback_modifier.gd`
  - Use `_subscribe("on_attack", ...)` / `_subscribe(trigger_event, ...)` in `attachEventManager`.
  - `_on_attack`: `if not _is_bound_event(data): return`.
  - `_on_hit`: `if not _is_bound_event(data): return`.
  - Fix double knockback: when attaching the `KnockbackBehavior`, set `behavior.name = "KnockbackBehavior"`; in `_on_hit`, skip the projectile branch if `data.get("projectile")` already has that named child (behavior handles it). Non-bound item knockback then also applies once.
- `src/Systems/Items/Modifiers/poison_modifier.gd`
  - Use `_subscribe(trigger_event, ...)`.
  - `_on_hit`: `if not _is_bound_event(event): return`.

No behavior change for item-pickup versions (`bound_weapon == null` → `_is_bound_event` always true).

## Step 4 — New helper: `src/Systems/weapon/weapon_builtin_effects.gd`

`class_name WeaponBuiltinEffects` (static, `extends RefCounted`, mirroring `ItemBuilder`):

- `const MODIFIER_KEY_TO_SCRIPT := {
    "knockback": preload("res://src/Systems/Items/Modifiers/knockback_modifier.gd"),
    "poison": preload("res://src/Systems/Items/Modifiers/poison_modifier.gd"),
  }`
- `const SPAWN_TIME_KEYS := ["pierce"]`
- `attach_for_weapon(weapon: BaseWeapon, holder: Node, em: EventManager) -> void`
  - For each `key -> cfg` in `weapon.modifiers`: if key in `MODIFIER_KEY_TO_SCRIPT` → `node = script.new()`, map cfg keys onto the modifier's vars (`strength`→`knockback_strength`, `duration`→`knockback_duration`, `chance`→`poison_chance`, etc., keeping defaults for missing), set `node.bound_weapon = weapon`, add under `holder.get_node("WeaponHolder")` if present else `holder`, call `node.attachEventManager(em)`.
- `detach(weapon: BaseWeapon) -> void`
  - For each node in `weapon._bound_effect_nodes`: `detach_from_event_manager()` then `queue_free()`; clear the array.
- `get_spawn_time_modifiers(weapon: BaseWeapon) -> Dictionary`
  - Returns `{"pierce": cfg.amount}` for SPAWN_TIME_KEYS present in `weapon.modifiers` (used by `shoot_projectile`).

## Step 5 — Wire into `BaseWeapon`

`src/Systems/weapon/BaseWeapon.gd`:
- Add `var _bound_effect_nodes: Array[Node] = []`.
- `apply_to` (after the `event_manager` resolution, ~line 31): `if event_manager: WeaponBuiltinEffects.attach_for_weapon(self, holder, event_manager)`.
- `remove_from` (before nulling `event_manager`, ~line 57): `WeaponBuiltinEffects.detach(self)`.

`WeaponHolder.remove_weapon` already calls `remove_from` (`weapon_holder.gd:44`), so removal cleans up bound modifiers and unsubscribes. `duplicate(true)` in `add_weapon` gives each holder (and each copy) an independent weapon instance → per-holder isolation for free.

## Step 6 — Declare built-ins in the weapon resources

- `src/Resources/weapons/Fist.tres`: add `modifiers = { "knockback": { "strength": 250.0, "duration": 0.2 } }`
- `src/Resources/weapons/Knife.tres`: add `modifiers = { "poison": { "chance": 0.5, "duration": 3.0, "tick_interval": 1.0, "max_stacks": 3 } }`
- `src/Resources/weapons/Pistol.tres`: add `modifiers = { "pierce": { "amount": 1 }, "knockback": { "strength": 120.0, "duration": 0.15 } }`

`src/Systems/weapon/projectile_weapon.gd` `shoot_projectile` (after building `projectile_props`, line 34):
```
var spawn_mods := WeaponBuiltinEffects.get_spawn_time_modifiers(self)
for key in spawn_mods:
    projectile_props[key] = projectile_props.get(key, 0.0) + spawn_mods[key]
```
So pistol pierce = stat `projectile_pierce` + 1.

## Step 7 — Tests (per AGENTS.md: write → run → fix → rerun)

New `test/Systems/weapon/test_weapon_builtin_modifiers.gd` (pattern of `test_fist.gd` / `test_pistol.gd`, using `res://test/TestScene.tscn` + `simulate_frames`):

1. **Unit — scoping guarantee (the core requirement):** instantiate `PoisonModifier` on the test Character's bus, `bound_weapon = a Knife instance`; emit a forged `on_hit` with `"weapon": ` some *other* weapon → enemy `Health` has **no** `PoisonEffect`; emit with `"weapon": ` the bound Knife → `PoisonEffect` appears. Same pair for `KnockbackModifier` → `KnockbackController` absent/present on the enemy.
2. **Integration — fist knockback:** Character with only `Fist.tres`; after frames, enemy has a `KnockbackController`.
3. **Integration — knife poison:** Character with only `Knife.tres` (duplicate, force `chance = 1.0`); after frames, enemy `Health` has `PoisonEffect`.
4. **Integration — pistol pierce + knockback:** two enemies in a line (mirror `test_pierce_stat.gd`); back enemy takes damage (pierce worked) and hit enemy gets `KnockbackController`.
5. **Detach/cleanup:** after `remove_weapon`, emitting `on_hit` does not error (confirms unsubscription).

Regression: existing `test/Systems/weapon/*.gd`, `test_pierce_stat.gd`, item-modifier suites must stay green.

Run: `.\run_tests_gdunit_custom.bat test_weapon_builtin_modifiers.gd`, then full `.\run_tests_gdunit.bat`.

## Step 8 — Docs

- `docs/systems/weapons.md`: document `BaseWeapon.modifiers` built-in keys, `WeaponBuiltinEffects`, spawn-time vs hit-event effects.
- `docs/systems/modifiers.md`: document `bound_weapon` / `_is_bound_event` and the `_subscribe`/`detach_from_event_manager` contract.
- `docs/systems/event_manager.md`: document that `on_hit`/`on_kill`/`after_deal_damage` now consistently carry `weapon`.

## Risks & gotchas

- `EventManager` does not guard freed listeners (`LocalEventManager.gd:29`) → detach MUST unsubscribe (Step 2/3). Test 5 guards this.
- `_active_stacks()` floors at 1; bound built-ins are single-stack, strength comes solely from config — correct by construction.
- Pistol built-in knockback attaches `KnockbackBehavior` at `on_attack`; the `_on_hit` skip (Step 3) prevents double application and also fixes the existing item-knockback double for projectiles.
- Modifier items still work holder-wide (`bound_weapon == null` → guard always passes).