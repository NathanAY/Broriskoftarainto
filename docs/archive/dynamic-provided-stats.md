# Dynamic Provided Stats — Plan

## Goal

Replace the current write-based `provided_stat` mechanism on `BaseModifier` (the `compute_provided_stat()` → `_sync_provided_stat()` → `Stats.set_base_stat()` loop) with a hybrid model where a behavior modifier **owns** a stat on the holder: the stat exists only while the modifier is attached, its value is read-only input for the behavior (never the output), and stacks + stat items compose independently.

Design requirements (from user decisions):

- **Dynamic presence.** A stat like `lifesteal` must NOT exist on a character node unless the owning modifier is attached. No modifier item → no stat key at all.
- **Multiplier semantics for lifesteal.** Stat `lifesteal` is a *multiplier* with base `1.0`. Stacks drive the power: 1 item = 5%, 2 items = 10%. The stat scales it: a stat item `{"lifesteal": {"flat": 0.5}}` → 15%; a debuff `{"flat": -2}` → multiplier `-1.0` → **negative** leach (previously impossible with stack-only approach).
- **Additive semantics for armor.** Stat `armor` IS the value (characters already carry base armor: Wildling 10, Soldier 10, Brawler 4). Damage reduction stays in `ArmorModifier` (`before_take_damage`), which reads `stats.get_stat("armor")` + its per-stack contribution. The stat already exists → **not** owned → the modifier is a pure consumer.
- **Refcounted removal.** When the last item carrying the modifier is removed, the owned stat is erased from `Stats` (reverses the earlier "keep simple, no cleanup" decision, so a real modifier detach path is needed).
- **Factory catalog.** `ItemFactory` candidate-pool = static base stats **+ `provided_stat` from every modifier scene**, so generated stat items / buffs / debuffs can target `lifesteal`, `armor`, etc.

The key architectural change vs today: the modifier **claims and reads** its stat instead of **writing** it. No more `set_base_stat(computed)` → no clobbering, no double counting, no ordering conflicts with stat items.

## Current gaps (verified in code)

1. **Write-based stat exposure.** `base_modifier.gd` `compute_provided_stat()` / `_sync_provided_stat()` write a *computed total* as the stat base (`stats.set_base_stat(provided_stat, compute_provided_stat())`, base_modifier.gd:109-112). This overwrites any pre-existing value and double-counts item modifiers for already-present stats (the armor problem: `armor` is already a stat with base + item modifier sources).
2. **No detach path for modifiers.** `ItemHolder.remove_item` calls `item.remove_from(holder)` (stat modifiers) but never `remove_stack`/detach on the effect node — stack state and `EventManager` subscriptions leak (documented in modifiers.md Known limitations). A "fully dynamic" stat that must disappear on removal requires this to exist.
3. **`set_base_stat` never erases.** `Stats` has no API to remove a stat key; `lifesteal` once written stays forever.
4. **Factory only knows static stats.** `item_factory.gd` builds candidate lists from `stats.stats.keys()` (lines 100, 146, 162, 192) — dynamic stats like `lifesteal` can't be targeted by generated stat items / debuff sides unless they happen to exist on the factory's `Stats` node.
5. **Armor handler conflates sources.** `armor_modifier.gd:23` already adds `armor_per_stack * (_active_stacks() - 1)` on top of `get_stat("armor")` — after the refactor the per-stack math stays, but the read must go through the stat contract.

## Design

### A. `Stats` gains claim/release (reference counting)

Add to `src/Systems/stats/stats.gd`:

```
## Provided-stats reference counts: stat_name -> number of live modifier instances.
var _provided_counts: Dictionary = {}

func claim_provided_stat(name: String, default: float) -> void:
    if _provided_counts.get(name, 0) == 0:
        stats[name] = default
        emit on_stat_changes {stat_name: name, final_value: default}
    _provided_counts[name] = _provided_counts.get(name, 0) + 1

func release_provided_stat(name: String) -> void:
    if not _provided_counts.has(name):
        return
    _provided_counts[name] -= 1
    if _provided_counts[name] <= 0:
        _provided_counts.erase(name)
        stats.erase(name)
        emit on_stat_changes {stat_name: name, final_value: 0.0}
```

- Presence lives in `stats.stats`; the count tracks how many modifier instances share it.
- Claim on first attach installs the default base; release on last detach erases the key.
- Reuses the existing `event_manager.emit_event("on_stat_changes", ...)` path so UIs update.

### B. `BaseModifier` stat contract (replaces compute/sync)

`src/Systems/Items/modifiers/base_modifier.gd`:

```
@export var provided_stat: String = ""            # "" = none
@export var provided_stat_default: float = 0.0    # installed base (lifesteal: 1.0)
@export var provided_stat_owned: bool = true      # dynamic presence (armor: false)

func get_provided_stat() -> float:
    if not stats:
        return provided_stat_default
    return stats.get_stat(provided_stat) if not provided_stat.is_empty() else provided_stat_default

func _claim_provided_stat() -> void:
    if provided_stat.is_empty() or not stats or not provided_stat_owned:
        return
    if stats.has_method("claim_provided_stat"):
        stats.claim_provided_stat(provided_stat, provided_stat_default)

func _release_provided_stat() -> void:
    if provided_stat.is_empty() or not stats or not provided_stat_owned:
        return
    if stats.has_method("release_provided_stat"):
        stats.release_provided_stat(provided_stat)
```

- `_cache_holder(em)` calls `_claim_provided_stat()` after caching `stats` (replaces the old `_sync_provided_stat()`).
- **No stack-change sync.** `add_stack`/`remove_stack`/`set_stack_active` no longer touch the stat value — stacks combine inside the subclass behavior, never into the owned stat. `_sync_provided_stat()`/`compute_provided_stat()` are deleted.
- New detach contract:
  ```
  func detach() -> void:
      _release_provided_stat()
      _unsubscribe_all()
  ```
  `remove_stack` when the last stack is removed: if `stacks.is_empty()` after removal → `detach()`.

### C. Modifiers combine stacks + stat (tuning stays in subclass)

**LifeLeach** (`life_leach_modifier.gd`):
- `_init()`: `provided_stat = "lifesteal"`, `provided_stat_default = 1.0`, `provided_stat_owned = true`.
- Behavior: `leach_ratio = LIFESTEAL_PER_STACK * _active_stacks() * get_provided_stat()` where `LIFESTEAL_PER_STACK = 0.05`.
  - 1 item → `0.05 * 1 * 1.0 = 5%`; 2 items → `0.05 * 2 * 1.0 = 10%`.
  - Stat item `{"lifesteal": {"flat": 0.5}}` → multiplier `1.5` → 15%.
  - Debuff `{"lifesteal": {"flat": -2}}` → multiplier `-1.0` → **negative** leach (loses HP instead of healing).
- `Health.heal` uses the signed result; negative heal clamps via `Health.heal` min/max — verify and document the negative-heal contract.

**Armor** (`armor_modifier.gd`):
- `_init()`: `provided_stat = "armor"`, `provided_stat_owned = false` (stat already exists), `provided_stat_default = 0.0`.
- `before_take_damage`: `armor = get_provided_stat() + armor_per_stack * (_active_stacks() - 1)`, then the existing `10/(10+armor)` reduction.
- No claim/release; the modifier reads an already-present stat. Stacks scale additively in the handler as today.

### D. Removal wiring in `ItemHolder`

`src/Systems/Items/item_holder.gd` `remove_item(item)`:
- If the item is an effect item, find the matching effect child (by `scene_file_path`) and call `effect.remove_stack(<that stack>)` (or a new `BaseModifier.remove_latest_stack()`).
- `BaseModifier.remove_stack` with `stacks.is_empty()` already calls `detach()` (Step B); `ItemHolder` then `free()`s the orphaned effect node.
- Optionally fall back to a `detach()` call for robustness.

### E. Factory candidate pool = static + provided stats

`src/Systems/Items/item_factory.gd`:
- Helper: `_candidate_stat_names() -> Array` = `stats.stats.keys()` **+ `provided_stat` from every scene in `effect_scenes`** (instantiate, read `provided_stat`, free). Cache it (recompute when `effect_scenes` load).
- Use it in `_generate_stat_item`, `_generate_buff_item`, `_generate_debuff_item`, and the negative-side stat picks (lines 100, 106, 146-147, 162, 170, 192, 195).
- For an absent base value, `_generate_stat_modifiers` takes the `base_value == 0` branch → `flat 1`. Tuning decision for multiplier stats (e.g. a `lifesteal` stat item granting flat +1 rather than +0.05·something) is deferred — default branch is acceptable; optionally a per-stat scale table later.

## Files to change

- `src/Systems/stats/stats.gd` — `claim_provided_stat` / `release_provided_stat`, `_provided_counts`.
- `src/Systems/Items/modifiers/base_modifier.gd` — new stat contract fields + `get_provided_stat` / `_claim` / `_release` / `detach`; delete `compute_provided_stat` / `_sync_provided_stat`.
- `src/Systems/Items/modifiers/life_leach_modifier.gd` — multiplier semantics.
- `src/Systems/Items/modifiers/armor_modifier.gd` — read through `get_provided_stat()`, `provided_stat_owned = false`.
- `src/Systems/Items/item_holder.gd` — wire stack removal + effect-node free on `remove_item`.
- `src/Systems/Items/item_factory.gd` — `_candidate_stat_names()` union and use it in all generators.

## Tests (per AGENTS.md: write → run → fix → rerun)

Extend `test/Systems/Items/test_provided_stat.gd` (and add cases for the new contract):

1. **Presence + multiplier base.** Attach LifeLeach → `stats.stats` has `lifesteal == 1.0`; detach → key erased.
2. **Refcount.** Two LifeLeach items → `lifesteal` present; remove one → still present; remove last → erased.
3. **Multiplier scaling.** Attach 2 stacks, `stats.add_modifier({"lifesteal": {"flat": 0.5}})` → on-hit heal = `0.05 * 2 * 1.5` of damage.
4. **Negative stat.** `stats.add_modifier({"lifesteal": {"flat": -2}})` → multiplier `-1.0` → heal call with negative (Health clamps; assert the contract).
5. **Armor reads stat.** Attach ArmorModifier, `armor_per_stack` default, assert `before_take_damage` uses `get_stat("armor") + armor_per_stack * (stacks - 1)`; armor key NOT claimed/released (still present after detach).
6. **Factory candidates.** A generated stat item can target `lifesteal` (catalog includes effect scenes' `provided_stat`).
7. **Detach unsubscribes.** After `remove_item`, emitting events does not error (regression for `EventManager` freed-listener crash).

Run: `.\run_tests_gdunit_custom.bat test_provided_stat.gd`, then full `.\run_tests_gdunit.bat`. Existing suites (`test_items_gut.gd`, weapon b* arrays, tooltip sweep) must stay green.

## Docs

- `docs/systems/modifiers.md`: rewrite the "Exposing a stat" section for claim/release + get; note the lifestyle multiplier vs armor additive split; remove the outdated "stat not removed" limitation; document the new detach contract.
- `docs/plans/dynamic-provided-stats.md` ← this file.
- `docs/systems/stats.md`: document `claim_provided_stat`/`release_provided_stat`.

## Risks & gotchas

- `Health.heal` clamps at `max_health` but is unbounded at the low end (no floor) — a negative heal asserts the player *loses* HP rather than erroring. Add a guard/test so `heal` handles negative amounts explicitly (either clamp at 0 loss or allow damage — decide and document).
- Removing an owned stat mid-run (`stats.erase(name)`) while another system cached `get_stat("lifesteal")` → default 0.0 path; fine, but the modifier must always read through `get_provided_stat()` after claim (defaults to `provided_stat_default` when the key is briefly absent).
- `effect_scenes` in the factory load before the pool helper is first called; guard for null/empty scenes.
- The old `_sync_provided_stat` calls in `add_stack`/`remove_stack`/`set_stack_active` must be fully removed — leftover syncs would re-introduce value writing for owned stats.
- `ItemHolder.remove_item` currently never removes effect nodes; wiring stack removal touches condition-scoped stacks (the `on_condition_change` subscription is bound to a stack index). Removing the *last added* stack must also drop that condition subscription — tracked as a small follow-up in Step D.