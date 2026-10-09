# ItemFactory

Purpose
- Procedural generator for item resources used to populate drop pools or shop lists.

Key scripts / scenes
- `src/Systems/Items/item_factory.gd` (class_name `ItemFactory`)

Data flow
- Inputs: reads available stats from `Stats` instance plus the union of `provided_stat` names advertised by every Modifier scene (`_candidate_stat_names()`), and loads PackedScenes from `src/Systems/Items/modifiers` and buff/debuff scenes — so generated stat items / debuffs can target dynamic stats like `lifeleach` even before any owning modifier is attached.
- Processing: random roll decides between stat/effect/buff/debuff generators; creates `Item` resources with modifiers and optionally pre-configured PackedScenes.
- Outputs: returns an `Item` instance (or `null` if no sources available); maintains `drop_pool` cache. `get_random_weapon()` lazily loads `BaseWeapon` resources from `res://src/Resources/weapons` and returns a random one (used by the shop).

Dependencies
- `Stats` node reference (onready `$Stats`), PackedScenes under `src/Systems/Items/modifiers` and `src/Systems/Items/Buffs`.

Entry points
- `get_item_from_pool_or_generate()` (`:117`) — what the shop and enemy drops call. Pulls from `drop_pool`, generating with probability `1 / (pool_size + 2)`.
- `get_item_by_type(type, index)` (`:154`) — deterministic, used by the debug/configure panel.

## Generation roll

`generate_random_item()` (`:165`) picks a category, then the category generator picks a stat and a value:

| Category | Generator | What it rolls | Curse scale (`:330`) |
|---|---|---|---|
| Stat item (40%) | `_generate_stat_item` `:188` | 1 random stat, 1 flat value | ×1.0 |
| Effect item (30%) | `_generate_effect_item` `:214` | 1 random BENEFIT modifier scene | ×2.0 negated stat |
| Buff item (15%) | `_generate_buff_item` `:263` | 1 stat, injected into `buff.tscn` | ×1.0 |
| Debuff item (15%) | `_generate_debuff_item` `:288` | 1 stat, **negated**, into `DebuffSource.tscn` | ×2.0 |

The candidate stat pool (`:104-115`) is every key in `Stats.DEFAULT_STATS` plus every `provided_stat` a modifier advertises (`lifeleach`, `armor`). **Uniform pick, no weighting** — the factory has no idea that `attack_range` is worth 0% and `lifeleach` is worth double.

Modifiers may randomize themselves at generation time via `randomize_for_generation(context)` (`:432`). Two do: `HealOnEventModifier` picks one of five trigger/heal pairs, `StatOnKillModifier` picks a target stat and a 5-10%-of-base amount. Treat any new modifier that implements this hook as a **weapon-grade** design (`balance.md` §6.2) — it is choosing its own power.

## The value roll, and why it is the core balance bug

```gdscript
# item_factory.gd:456-464
func _generate_stat_modifiers(_chosen_stat, base_value) -> Dictionary:
    if base_value == 0:
        modifier_value["flat"] = 1
    else:
        modifier_value["flat"] = base_value * rng.randf_range(0.05, 0.1)
```

**One formula for all 14 stats.** "5-10% of base" reads like a percentage budget and is not one.

**The `base_value == 0` branch is the worst of them.** Six stats in the pool have a base of 0 (`energy_shield`, `critical_chance`, `flat_damage`, `projectile_pierce` are 0.0 in `DEFAULT_STATS`; `armor` and `lifeleach` are not in the table at all, so `.get` returns 0.0). All six roll a **hard constant `1.0`, with no RNG call and no scaling by the stat's actual scale** — a `1.0` means +1 percentage point on a 0-100 stat, +10% EHP on armor, and a doubling on a 0-1 multiplier stat.

| Stat | Base | Roll | What 5-10% actually buys |
|---|---|---|---|
| `health` | 10.0 | 0.5 – 1.0 | +0.4% on a Soldier (120 HP) … +2.5% on a Multitasker (40 HP). Same item, 6× spread. |
| `attack_speed` | 1.0 | 0.05 – 0.10 | +5-10% WB. Also multiplies every on-hit rider (`balance.md` §6.1). |
| `critical_chance` | 0.0 | **1.0 (constant)** | +1 pp of a 0-100 scale → **+0.5% WB**, and always exactly the same number. |
| `armor` | not in `DEFAULT_STATS` | **1.0 (constant)** | **+10% EHP**, and it compounds with `ArmorModifier`'s +5/stack. |
| `lifeleach` | not in `DEFAULT_STATS` | **1.0 (constant)** | Stat goes `1.0 → 2.0`, so `LifeLeachModifier`'s 5% lifesteal (`life_leach_modifier.gd:6,26`) **doubles to 10%**. One price-1 item doubles the build's only stat. |
| `flat_damage` | 0.0 | **1.0 (constant)** | +10% WB on a Fist, +20% on a Shotgun. Unbounded vs weapon tier. |
| `projectile_pierce` | 0.0 | **1.0 (constant)** | +1 target on a Pistol that already pierces 1 → **+100% WB**. |
| `attack_range`, `area_radius` | 500.0 / 1.0 | 25-50 / 0.05-0.10 | **Nothing. No code reads either stat.** |
| `base_damage` (stat) | 5.0 | 0.25 – 0.5 | Nothing, until you also hold Spinning Orbs or Reflect, then +5-10% (`balance.md` §6.3). |

Three structural problems, all fixable without new systems:

1. **`base_value` is read from the wrong character.** `:192` reads `stats.stats` off the factory's own `$Stats` child (`ItemFactory.tscn` → `Stats.tscn` → `DEFAULT_STATS`), not from `GlobalGameState.current_character`. Generation is blind to the character that will wear the item, so a flat roll cannot be a fair percentage. **Fix**: pass the holder's `Stats` into the generator and roll a **percentage of the holder's current value**, so `+3% max_health` means the same thing on every character. The target table for that percentage is `balance.md` §3.1.
2. **The `base_value == 1` branch (`:460`) is dead code** — identical body to the `else`.
3. **Dead stats are in the pool.** `attack_range` and `area_radius` appear in `DEFAULT_STATS` (`stats.gd:36-37`) and have tooltip text (`item_tooltip.gd:24-25`) but nothing reads them. A generated "Attack Range Plus" costs a full price-1 slot and does literally nothing. Remove them from `_candidate_stat_names()`.

## `drop_pool` is degenerate

```gdscript
# item_factory.gd:117-130
if rng.randi_range(0, pool_size) < pool_size:   # inclusive on both ends
    return drop_pool.pick_random()
```

`randi_range` is inclusive, so the pool branch fires with probability `(N+1)/(N+2)` — **at least 50%, asymptotically 100%**. Every generated item is appended, nothing is ever evicted, and the pool is never reset per loop. A run converges to re-offering the same handful of items.

**Fix**: cap generation probability at a constant (say 30%) instead of deriving it from pool size, cap `drop_pool` at ~20 entries with LRU eviction, and clear it on loop change. Note the shop fixture in `test/tools/shop_ui_preview.gd:104` pins `rng.seed` for exactly this reason — any change here needs that fixture re-tuned.

## Gift and curse (the negative half)

Every generated item is a positive half plus a curse, and the curse is one of two things:
- a **negated stat** (`{stat: {"flat": -x}}` in `Item.modifiers`) - always been the case; or
- a **harmful modifier** (`effect_kind = COST`, e.g. a life drain) appended as a second `Item.effect_scene` entry.

- `const NEGATIVE_MODIFIER_CHANCE := 0.35` decides which, once per item, via `_roll_negative_modifier()`. The two are **alternatives, never both** - an item never gets a double penalty from one roll.
- All four generators (`_generate_stat_item`, `_generate_effect_item`, `_generate_buff_item`, `_generate_debuff_item`) roll it.
- **The positive half may only roll a BENEFIT and the curse only a COST.** `_benefit_effect_scenes()` / `_cost_effect_scenes()` partition `effect_scenes` by `BaseModifier.effect_kind` (built once by `_rebuild_scene_pools()`). Without the split the shop can offer "Grants special effect: Life Drain" as an upside. Adding a harmful modifier to the folder and tagging it `COST` is all it takes to widen the pool.
- A harmful scene is appended **after** the positive one, so `effect_scene[0]` still reads as the gift and `effect_scene_condition` stays aligned.
- `_roll_negative_stat(exclude, ...)` never picks the stat the positive half already uses. Picking it again collapses both halves onto one key, and since `Dictionary.merge()` does **not** overwrite by default the curse would silently vanish, yielding a free item.
- A **stat** item's curse scene is its only entry, so its positive stat remains in `modifiers` and the card must keep rendering it as a gain (`ItemTooltip._append_modifier_rows`).
- Buff/debuff items render their payload from scene 0 and any appended curse from scene 1 onwards, on both the card and the flat tooltip.
- `ItemPriceAnalyzer.get_price` only checks whether `effect_scene` is non-empty, so a stat item that rolled a curse is priced as a modifier (3) rather than a stat item (1).
- **[PROPOSED]** the curse's *magnitude* is currently re-rolled independently of the gift, so a 0.5-HP gift can carry a 1.0-HP curse. `balance.md` §3.2 specifies it as a fixed 1.0-1.2× of the gift.
- Covered by `test/Systems/Items/test_item_factory_polarity.gd`. The chance is a const, so its tests pin `rng.seed` and draw a batch: a fixed seed makes "both branches appear" deterministic rather than flaky. `test_item_pickup.gd` pins its seed for the same reason.

## Known limitations / TODOs
- The value roll is the big one, and it is described above rather than here: one formula for 14 stats, six of which get a constant. See "The value roll".
- `drop_pool` asymptotically re-offers the same items and never resets. See above.
- `_load_scenes_from_dir` uses DirAccess and assumes folder layout; missing/misnamed folders will produce warnings.
- `RegenModifier.tscn` (the abstract `regen_modifier.gd` base with no behaviour) lives in the same folder and is therefore loaded as an offerable scene, so an "effect item" can roll a modifier that does nothing. Pre-existing.
- Random generation has some dead/experimental code paths (e.g., `return _generate_debuff_item()` placed before other roll checks) — indicates deliberate temporary behavior or debugging.
- Generation-time randomization lives in the modifiers, not the factory: a modifier scene that supports it implements `randomize_for_generation(context) -> bool` (context: `{"rng": RandomNumberGenerator, "stats": Dictionary}`) and owns its own rolls — e.g., `HealOnEventModifier` picks from its `possible_trigger_event` table, `StatOnKillModifier` rolls a random `target_stat` from `Stats` plus a scaled `add_amount`. `ItemFactory._configure_dynamic_modifier` only builds the context, calls the hook when present, and repacks on mutation; scenes without the hook pass through untouched. Modifiers may also expose `get_generation_suffix()` so generated item names stay distinguishable (e.g., `Stat On Kill Modifier (movement_speed)`).
- The build-time display cache (`_store_effect_display`) is an Array aligned **by index** with `item.effect_scene`. Keying by scene path would not work, because repacked randomized modifiers have an empty `resource_path`.

## Assumptions
- The `Stats` reference exists and exposes `stats` keys used for generating stat modifiers.
- Every figure in "The value roll" is measured against `Stats.DEFAULT_STATS` as it stands. If a base stat changes, that table is wrong until it is re-derived. `docs/systems/balance_audit.md` carries the same figures as numbered audit rows, and the target budgets live in `docs/systems/balance.md` §3.1.
