# Modifiers (Item Effects)

Purpose
- Modifiers ARE the "effects" half of an `Item`. While `Item.modifiers` carries plain stat values applied to `Stats`, modifiers are Node-based scripts that implement gameplay behavior (spawn extra projectiles, heal, debuff, shields, on-hit reactions, ...). They attach to an actor's `ItemHolder`, subscribe to `EventManager` events, and react to gameplay.

Location and files
- Base class: `Systems/Items/Modifiers/base_modifier.gd` (`class_name BaseModifier`) — owns the stack state, `EventManager`/holder/Stats caching, and `get_health()`.
- Scripts: `Systems/Items/Modifiers/*_modifier.gd` (e.g. `life_leach_modifier.gd`).
- Scenes: `Systems/Items/Modifiers/*Modifier.tscn` (one per script that ships as an item effect).
- Item data: `Resources/items/*.tres` reference a modifier scene via `effect_scene`.

Naming conventions (enforced by the 2026 naming pass)
- Script file is `snake_case_modifier.gd`.
- Scene file basename equals the script's class, PascalCase `SomethingModifier.tscn`.
- Modifiers that differ only slightly reuse a shared script via inheritance (e.g. `homing_rocket_from_target_modifier.gd` extends `homing_rocket_modifier.gd`), keeping one scene per variant.
- Items that want to randomize their generated stats also implement generation hooks (see "Generation hooks" below).

Why a modifier exists vs a stat modifier
- Pure numeric build-ups (flat/percent stats) belong on `Item.modifiers` / `Stats.add_modifier`, not here.
- Anything reactive (needs events, timers, scene spawning, health) is a modifier.

The modifier contract
Every modifier `extends BaseModifier`, which provides the shared scaffolding so the `ItemHolder` and tooltip can treat them uniformly:

1. Stack state (implemented in `BaseModifier`)
   - `var stacks: Array[bool] = []` — one entry per instance (stack) of the effect; `true` = active.
   - `add_stack(active: bool)` — called by `ItemHolder.add_item()` after instantiation + `attachEventManager`.
   - `remove_stack(index: int)` — removes one entry.
   - `set_stack_active(index: int, active: bool)` — toggles a stack on/off. `ItemHolder` wires this to condition managers: an item with `effect_scene_condition` gets an `on_condition_change` subscription that flips the matching index.
   - `_active_stacks() -> int` — `max(1, stacks.count(true))`. The floor of 1 means a single (or even all-inactive) copy still runs at base power; all scaling is expressed as `(active - 1)`.

2. Attachment (implemented in `BaseModifier`)
   - `_cache_holder(em)` — caches `event_manager`, `holder = em.get_parent()`, `stats = holder.get_node_or_null("Stats")` (with a `push_warning` when the holder has no `Stats` node); `get_health()` returns `holder.get_node_or_null("Health")`.
   - Each modifier overrides `attachEventManager` to subscribe to its main behavior event via the `trigger_event` export, plus `on_stat_changes` when it caches derived stats.
   - Per-event handlers stay idempotent and cheap: bail out early when the event lacks what they need.
   - Spawned objects are tagged to avoid recursive triggers (see "Anti-recursion" below).
   - `static instantiate_attached(scene, parent) -> Node` — the one place an effect scene becomes a live node (`instantiate()` + `add_child()`). Wiring is left to the caller because the effect kinds differ: modifiers go through `attachEventManager`, while buffs / poison effects wire themselves in their own `_ready()` from their `ItemHolder` parent.
   - `static attach(scene, parent, em) -> BaseModifier` — the full contract for a `BaseModifier` scene: `instantiate_attached` + `attachEventManager(em)` + one `add_stack(true)`. Used by hosts that merely declare a modifier scene (a character's `CharacterData.modifiers`); warns and returns `null` when the scene is not a `BaseModifier` or `em` is null, so a misconfigured declaration never silently does nothing.

3. Owning a stat (implemented in `BaseModifier`)
   - A modifier can OWN a stat on the holder's `Stats` node by setting `provided_stat` (e.g. `LifeLeach` owns `lifesteal`). The stat is **dynamic**: it exists while at least one claiming modifier is attached (reference-counted) and is erased when the last one detaches.
   - Contract fields: `provided_stat` (name, `""` = none), `provided_stat_default` (base installed on first claim, e.g. `1.0`), `provided_stat_owned` (`true` = claim/release dynamic presence; `false` = the stat already exists, e.g. armor, modifier is a pure consumer).
   - `_cache_holder(em)` calls `claim_provided_stat` on first attach. `detach()` (called by `remove_stack` on the last stack, or directly before freeing) releases the claim and unsubscribes all recorded subscriptions.
   - **The modifier never writes the stat.** Behavior handlers read the live value through `get_provided_stat()`. Stat items/buffs/debuffs compose with the installed base via the normal `add_modifier` pipeline and can drive the value negative.
   - Two semantics:
     - Multiplier (LifeLeach): stat base is `1.0`; stacks drive the power, the stat scales it — `heal = LIFESTEAL_PER_STACK * _active_stacks() * get_provided_stat()` (1 item = 5%, 2 = 10%; a stat item `flat -2` makes the multiplier `-1.0` → negative leach).
     - Additive shared (Armor): the stat already exists on the holder; the modifier reads `get_provided_stat()` and adds its per-stack contribution in its handler.
   - Stack changes (`add_stack`/`remove_stack`/`set_stack_active`) never touch the stat value — stacks combine inside the subclass behavior, not into the owned stat.

3. Display contract (tooltips)
   - `@export var display_name: String` — short noun shown as the effect head.
   - `@export_multiline var tooltip_text: String` — optional one-sentence description (static flavor).
   - `@export var trigger_event: String` — the eventual trigger shown as `(Triggers on ...)`.
   - `func get_tooltip_stats() -> String` — OPTIONAL dynamic fragment built from live configured numbers (has prevelence: always called if present). Used because heal amounts, damage %, ranges, and per-stack values are configured at generation time and must read live, never stale static text.
   - `@export var effect_kind: BaseModifier.EffectKind` — `BENEFIT` (default) or `COST`. See "Harmful modifiers" below.
   - `ItemTooltip` reads these off a temp instance once, caches per scene path, and renders `effect: <display_name> — <tooltip_text> <stats> (Triggers on <humanized trigger>)`. Falling back to a humanized scene basename when `display_name` is absent.

4. Generation hooks (optional)
   - `randomize_for_generation(context: Dictionary) -> bool` — called by `ItemFactory` at generation time; rolls a random trigger/stat/value. Returns `true` when it mutated the instance so the factory repacks it. Implemented by `HealOnEventModifier` and `StatOnKillModifier`.
   - `get_generation_suffix() -> String` — postfix for the item name so randomized variants differ (`StatOnKillModifier`).

5. Weapon binding (implemented in `BaseModifier`)
   - `var bound_weapon: Object = null` — when non-null, handler events must carry this exact weapon to fire. Used by weapon built-in effects (`Systems/weapon/weapon_builtin_effects.gd`): Fist/Knife/Pistol declare their own `knockback`/`poison` via `BaseWeapon.modifiers`, and the helper instantiates these modifier scripts as real nodes bound to one weapon instance.
   - `_is_bound_event(data: Dictionary) -> bool` — returns `true` when `bound_weapon` is null (item-pickup path, holder-wide, unchanged) or `data.get("weapon") == bound_weapon`.
   - `_subscribe(event_name, listener)` — subscribes and records the pair. When `bound_weapon` is set, the listener is auto-wrapped so it only receives events whose payload carries the bound weapon; guard-less handlers are scoped automatically. Modifiers never write their own `if not _is_bound_event(data): return` — subscribing via `_subscribe` is enough. Events without a `weapon` key (explosion/orb sources) never match a bound modifier.
   - `_subscribe` also records every pair so `_unsubscribe_all()` can unregister before freeing. Because `EventManager` crashes on freed listeners (`LocalEventManager.gd:29`), detach MUST unsubscribe before freeing — `WeaponBuiltinEffects.detach` relies on this. Modifiers that subscribe via raw `event_manager.subscribe` bypass both the auto-scoping and the tracking; any modifier intended to work as a weapon built-in must use `_subscribe`.

Lifecycle / data flow
- `Item.effect_scene` is an `Array[PackedScene]`: one item can carry several effects, so `ItemHolder` walks the whole array. `effect_scene_condition` is the parallel array - entry `i` gates effect `i` (empty/absent = always active).
- `ItemHolder.add_item(item)` (`Systems/Items/item_holder.gd`), once per entry of `item.effect_scene`:
  1. Looks up an existing child by `scene_file_path == effect_scene[i].resource_path` (dedup).
  2. If new: `BaseModifier.instantiate_attached(effect_scene[i], self)`, then `item.apply_to(holder)` (stat modifiers + condition managers) and `attachEventManager(event_manager)` when the effect implements it. `apply_to` runs once per added copy, before the first new effect node is wired, so a modifier that owns a stat sees the item's own bonuses (and never twice for a multi-effect item).
  3. Decides the initial `active` flag from `item.effect_scene_condition[i]` (via `stats.get_condition`); registers an `on_condition_change` subscription bound to the new stack index so the stack turns off/on with the condition.
  4. Calls `add_stack(active)` on that effect node.
- `remove_item(item)` removes stat modifiers, then for every entry of `item.effect_scene` pops one stack of the matching effect node (via `remove_latest_stack`), detaches + frees the node on the last stack, and re-emits `on_item_removed`.
- Modifiers live as children of the `ItemHolder` node; spawned projectiles/orbs/explosions go to `get_tree().current_scene`.

Harmful modifiers (red effect line)
- A modifier that is a net loss declares `effect_kind = EffectKind.COST`; everything else stays `BENEFIT` (the default, so all pre-existing modifiers render unchanged).
- Path to the screen: `ItemTooltip._read_display_from_scene` / `ItemFactory._store_effect_display` read the export into the effect-display dictionary → `ItemTooltip._append_effect_row` maps it through `_tone_for_effect_kind` onto `ItemCardRow.tone` → `ItemDisplayPanel._row_bbcode` renders an EFFECT row with `effect_tone_color(tone)`, which is `COLOR_HEADING` gold at NEUTRAL and `COLOR_NEGATIVE` red at NEGATIVE.
- `EffectKind` is mapped **by name, not cast** onto `ItemCardRow.Tone`: the two enums are separate and are free to number their entries differently (`COST` is 1 while `Tone.NEGATIVE` is 2).
- `ItemFactory` caches the value as the `effect_kind` item metadata, so a *generated* drain still renders red through the steady-state path that skips instantiation.
- **It is an `@export` and not a folder on purpose.** The display contract is read reflectively (a `get_property_list()` probe plus `has_method` checks), so a `modifiers/negative/` directory would be completely invisible to the tooltip and would need a path check at both reflection sites plus a second `load_scenes_from_dir` in `ItemFactory._ready`.

Losing health over time
- `regen_modifier.gd` carries a **signed** delta: subclasses return `_health_delta_per_tick(h)` and a positive value heals, a negative one drains. `FlatRegenModifier` / `PercentRegenModifier` export `health_delta` / `health_delta_percent`; `FlatLifeDrainModifier` / `PercentLifeDrainModifier` are the same code with negative defaults and `effect_kind = COST`.
- **A drain must not go through `Health.heal()`.** `heal()` is `min(current + amount, max)`: it clamps only at the ceiling, so a negative amount drives health below zero while the entity stays alive, and it fires `on_heal` with a negative payload that every heal listener reads as a gain. `Health.apply_damage()` is the only place the dead check lives, so a drain routes there and gets the whole defender phase for free (`before_take_damage` → armor / energy shield → damage → `on_death` → `after_take_damage`).
- Consequence worth knowing: because the drain runs the defender phase, armor reduces it and energy shield soaks it before health. That is intentional — those systems are documented as "reduces incoming damage" / "absorbs incoming damage before health" — but it does mean armor is a stat that matters against debuffs.
- A drain emits **nothing on an attacker's bus** (`before_deal_damage`, `after_deal_damage`, `on_kill`). There is no attacker, so the only bus available is the holder's own, and a self-inflicted tick must not pay the holder its own `StatOnKillModifier` rewards for dying.
- Exactly zero is a no-op: healing by 0 would still emit `on_heal`, and damaging by 0 would still flash a sprite and float a damage number.

Scaling models (how per-stack growth is implemented)
- Multiplicative growth: `value = base * (1.0 + bonus_per_stack * (_active_stacks() - 1))` — bomb detonation, explosive shot, poison tick base, crit multiplier bonus.
- Owned-stat multiplier: `value = per_stack * _active_stacks() * stats.get_stat(provided_stat)` — life leach (`0.05` per stack, stat base `1.0`); the stat scales power and can go negative.
- Flat-per-stack: `value * (1.0 + bonus * _active_stacks())` — plus-damage-to-healthy.
- Count-per-stack: `for i in range(_active_stacks())` spawn/attach N copies — homing (projectile steering modules), homing rockets, spread (left+right pair per stack = "2 extra projectiles per stack"), projectile bounce attachment count, knockback strength scaling, reflect volley `volley + (active - 1)`, spinning orbs `ORB_COUNT + (active - 1)`, chain bounce count `max_bounces * active`.
- Linear-with-stacks: `value * _active_stacks()` — regen heal amount, stat-on-kill gain, heal-on-event; emergency heal shortens its cooldown `COOLDOWN / _active_stacks()`.
- All rely on `_active_stacks()` and express the strategy in the same style; tooltip text mirrors the math ("per stack", "(+1 per stack)", "+50% per stack").

Anti-recursion
- Spawned projectiles/orbs are tagged with metadata (e.g. `spawned_by_ChainModifier`, `spawned_by_HomingRocketModifier`, `spawned_by_HomingRocketFromTargetModifier`, `spawned_by_ReflectProjectileModifier`, `spawned_by_SpinningOrbsModifier`, bomb `_tag = "bomb_modifier"`).
- Handlers early-return when the event carries an object already carrying that meta, so a chain fired by a chain never chains again. `SpinningOrbsModifier` also checks the `damage_context.tags` of any event that carries one (not its own `trigger_event` name) before spawning.

Events used
- Consumed: `on_attack`, `on_hit`, `before_take_damage`, `after_take_damage`, `before_deal_damage`, `on_kill`, `on_item_added`, `on_condition_change`, `on_stat_changes`.
- Emitted: `on_crit` (crit), `on_shield_changed` (energy shield).

Catalog
| Modifier (class) | Script | Trigger event | Effect |
|---|---|---|---|
| ArmorModifier | `armor_modifier.gd` | `before_take_damage` | Reduces damage by armor formula `10/(10+armor)`; +5 armor per stack. Reads the (existing) `armor` stat — pure consumer, not owned. The stat alone is inert: a character must also list this scene in `CharacterData.modifiers` alongside its `armor` value (see `docs/systems/characters.md`). |
| BombOnHitModifier | `bomb_on_hit_modifier.gd` | `on_hit` | Attaches a bomb to the target, explodes for 30% of hit damage after 3s; +20% explosion damage per stack. |
| ChainModifier | `chain_modifier.gd` | `on_hit` | Spawns a chain projectile that chains to 3 extra targets per stack. |
| CritModifier | `crit_modifier.gd` | `before_deal_damage` | On crit applies crit multiplier; +0.15 crit multiplier per stack. |
| EmergencyHealModifier | `emergency_heal_modifier.gd` | `after_take_damage` | Heals 75% max HP when below 25% HP; cooldown 60s shortens per stack. |
| EnergyShieldModifier | `energy_shield_modifier.gd` | `before_take_damage` | Shield absorbs damage, recharges 10/s after 1.5s; +5 max shield per stack. |
| ExplosiveShotModifier | `explosive_shot_modifier.gd` | `on_hit` | Hits explode for 3.0 area damage; +50% explosion damage per stack. |
| HealOnEventModifier | `heal_on_event_modifier.gd` | randomized (`on_attack`/`on_hit`/`on_crit`/`after take damage`/... ) | Heals fixed HP per event; heal amount × active stacks. |
| HomingModifier | `homing_modifier.gd` | `on_attack` | Adds homing steering module to projectiles; one module per stack. |
| HomingRocketModifier | `homing_rocket_modifier.gd` | `before_take_damage` | Launches a homing rocket dealing 100% of hit damage; +1 rocket per stack. |
| HomingRocketFromTargetModifier | `homing_rocket_from_target_modifier.gd` (extends the homing rocket script) | `on_hit` | Same rocket, but resolves the target from the hit (`target`/`source`), searches the next enemy within `homing_range`, and spawns the rocket from the target. +1 rocket per stack. |
| KnockbackModifier | `knockback_modifier.gd` | `on_hit` (also listens `on_attack`) | Knocks enemies back; strength × stacks. |
| LifeLeachModifier | `life_leach_modifier.gd` | `on_hit` | Heals 5% of dealt damage per item; the `lifesteal` stat (base `1.0`, multiplier, owned) scales it — stat items can drive it negative. |
| PlusDamageToHealthyTargetModifier | `plus_damage_to_healthy_target_modifier.gd` | `before_deal_damage` | +30% damage vs targets above 90% HP; × active stacks. |
| PoisonModifier | `poison_modifier.gd` | `on_hit` | Applies `PoisonEffect` (100% of hit damage per tick); +50% tick damage per stack. |
| ProjectileBounceModifier | `projectile_bounce_modifier.gd` | `on_attack` | Projectiles bounce to 3 extra targets per stack. |
| ReflectProjectileModifier | `reflect_projectiles_modifier.gd` | `before_take_damage` | Fires 2 projectiles back at attackers; +1 per stack and larger range. |
| FlatRegenModifier | `flat_regen_modifier.gd` (extends `regen_modifier.gd`) | passive timer | Regenerates fixed HP per tick; × stacks. No trigger event. `health_delta` is signed — a negative value drains (see "Losing health over time"). |
| PercentRegenModifier | `percent_regen_modifier.gd` (extends `regen_modifier.gd`) | passive timer | Regenerates % of max HP per tick; × stacks. No trigger event. `health_delta_percent` is signed. |
| FlatLifeDrainModifier | `flat_life_drain_modifier.gd` (extends `regen_modifier.gd`) | passive timer | Loses fixed HP per tick; × stacks. `effect_kind = COST`, so the card effect line is red. Routed through `Health.apply_damage`, so it can kill and runs the defender phase. |
| PercentLifeDrainModifier | `percent_life_drain_modifier.gd` (extends `regen_modifier.gd`) | passive timer | Loses % of max HP per tick; × stacks. `effect_kind = COST`. |
| SpinningOrbsModifier | `spinning_orbs_modifier.gd` | `on_hit` | Spawns orbiting orbs (2 base, +1 per stack) dealing 50% of base damage. |
| SpreadModifier | `spread_modifier.gd` | `on_attack` | Spawns 2 extra projectiles per stack. |
| StatMultiplierModifier | `stat_multiplier_modifier.gd` | `on_item_added` | Multiplies flat bonuses of a target stat from items by 2.0× per stack. Script-only (no `.tscn`; packed via `ItemBuilder`). |
| StatOnKillModifier | `stat_on_kill_modifier.gd` | `on_kill` | Gains a randomized stat per stack (`health`, `movement_speed`, ...). |

Guidelines for adding a new modifier
1. `extends BaseModifier` (`Systems/Items/Modifiers/base_modifier.gd`), matching the file's indentation style (4-space), in `Systems/Items/Modifiers/`. For a variant of an existing behavior, extend that script instead and set differing defaults in `_init()`.
2. Stack state, `attachEventManager` caching, `_active_stacks()`, and `get_health()` come free from `BaseModifier`.
3. Implement `attachEventManager`; subscribe your behavior with `_subscribe(trigger_event, ...)`, and to `on_stat_changes` only when you cache derived stats. Always use `_subscribe` (not raw `event_manager.subscribe`) — it handles weapon scoping when bound and unsubscribes on detach. Bail early when data is missing.
4. Add the display contract (`display_name`, optional `tooltip_text`, `trigger_event`, and `get_tooltip_stats()` reading live values). If you add it, an item `.tres` in `Resources/items/` and a matching `XxxModifier.tscn` are needed to ship it. If the modifier is a net **loss**, set `effect_kind = EffectKind.COST` so its effect line renders red.
5. Scale per stack using `_active_stacks()`; keep the formula mirrored in the tooltip string.
6. Tag anything you spawn to prevent recursion.
7. Follow AGENTS.md: write/extend a test first, run it, fix, rerun. Relevant suites: `test/ui/test_character_ui_tooltip.gd` (tooltip sweep over every modifier scene) and `test/Systems/Items/`. New harmful modifiers and the signed-delta drain belong in `test/Systems/Items/test_negative_modifier_marking.gd` and `test_regen_modifier.gd`. After changing a card, render it: `.run_scene_shot.bat res://test/tools/shop_ui_preview.tscn`.

Known limitations / TODOs
- `remove_item` pops the most recently added stack (`remove_latest_stack`); it does not track which item instance maps to which stack index, so condition-scoped stacks' `on_condition_change` subscriptions are not removed with the stack (existing condition wiring stays stale).
- `_active_stacks()` floors at 1, so a fully condition-deactivated modifier still runs at base power.
- Not every stat-based tilt belongs here; pure numeric bonuses should be `Item.modifiers` instead.
- `StatMultiplierModifier` mutates the incoming `Item.modifiers` dictionary in place at `on_item_added` (no rollback on remove).
- `BaseModifier` misses the `Stats` node with a `push_warning` (not hard-crash); child lookups like `holder.get_node("Sprite")` in homing target selection still assume the node exists.