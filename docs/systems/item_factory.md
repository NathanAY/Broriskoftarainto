# ItemFactory

Purpose
- Procedural generator for item resources used to populate drop pools or shop lists.

Key scripts / scenes
- `src/Systems/Items/item_factory.gd` (class_name `ItemFactory`)

Data flow
- Inputs: reads available stats from `Stats` instance plus the union of `provided_stat` names advertised by every Modifier scene (`_candidate_stat_names()`), and loads PackedScenes from `src/Systems/Items/modifiers` and buff/debuff scenes — so generated stat items / debuffs can target dynamic stats like `life_leach_multiplier` even before any owning modifier is attached.
- Processing: random roll decides between stat/effect/buff/debuff generators; creates `Item` resources with modifiers and optionally pre-configured PackedScenes.
- Outputs: returns an `Item` instance (or `null` if no sources available); maintains `drop_pool` cache. `get_random_weapon()` lazily loads `BaseWeapon` resources from `res://src/Resources/weapons` and returns a random one (used by the shop).

Dependencies
- `Stats` node reference (onready `$Stats`), PackedScenes under `src/Systems/Items/modifiers` and `src/Systems/Items/Buffs`.

Entry points
- `get_item_from_pool_or_generate()` (`:117`) — what the shop and enemy drops call. Re-offers a `drop_pool` item with probability `repeat_item_chance_scale * N / (N + 1)`, otherwise generates a new one.
- Three knobs come from `game_config.json` — `negative_modifier_chance`, `repeat_item_chance_scale`, `modifier_weights`. See `docs/systems/game_config.md`.
- `get_item_by_type(type, index)` (`:154`) — deterministic, used by the debug/configure panel.

## Generation roll

`generate_random_item()` (`:165`) picks a category, then the category generator picks a stat and a value:

| Category | Generator | What it rolls | Curse scale (`:330`) |
|---|---|---|---|
| Stat item (40%) | `_generate_stat_item` `:188` | 1 random stat, 1 flat value | ×1.0 |
| Effect item (30%) | `_generate_effect_item` `:214` | 1 random BENEFIT modifier scene | ×2.0 negated stat |
| Buff item (15%) | `_generate_buff_item` `:263` | 1 stat, injected into `buff.tscn` | ×1.0 |
| Debuff item (15%) | `_generate_debuff_item` `:288` | 1 stat, **negated**, into `DebuffSource.tscn` | ×2.0 |

The candidate stat pool (`:104-115`) is every key in `Stats.DEFAULT_STATS` plus every `provided_stat` a modifier advertises (`life_leach_multiplier`, `armor`). **Uniform pick, no weighting** — the factory has no idea that `attack_range` is worth 0% and `life_leach_multiplier` is worth double.

`armor`, `flat_regen_per_second` and `percent_regen_per_second` are candidates but are never **rolled**: `LISTENER_ONLY_STATS` filters them out of `_gratable_stat_names()`, which is what the stat / buff / debuff generators and `_roll_negative_stat` pick from. Each only does something while its modifier scene listens, so a bare `{"armor": 1}` item would show a benefit in the stat panel and change nothing on a character without the modifier. They reach the player as the modifier item instead (`ArmorModifier`, `FlatRegenModifier`, ...), which publishes its value into the stat — see `docs/systems/stats.md`.

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

**The `base_value == 0` branch is the worst of them.** Five stats in the pool have a base of 0 (`energy_shield`, `critical_chance`, `flat_weapon_damage`, `projectile_pierce` are 0.0 in `DEFAULT_STATS`; `life_leach_multiplier` is not in the table at all, so `.get` returns 0.0). All five roll a **hard constant `1.0`, with no RNG call and no scaling by the stat's actual scale** — a `1.0` means +1 percentage point on a 0-100 stat and a doubling on a 0-1 multiplier stat.

| Stat | Base | Roll | What 5-10% actually buys |
|---|---|---|---|
| `health` | 10.0 | 0.5 – 1.0 | +0.4% on a Soldier (120 HP) … +2.5% on a Multitasker (40 HP). Same item, 6× spread. |
| `attack_speed` | 1.0 | 0.05 – 0.10 | +5-10% WB. Also multiplies every on-hit rider (`balance.md` §6.1). |
| `critical_chance` | 0.0 | **1.0 (constant)** | +1 pp of a 0-100 scale → **+0.5% WB**, and always exactly the same number. |
| `armor` | not in `DEFAULT_STATS`, and never rolled | — | Filtered out of the rollable pool (see above). Armor comes from the `ArmorModifier` item's own per-stack bonus. |
| `flat_regen_per_second` / `percent_regen_per_second` | not in `DEFAULT_STATS`, and never rolled | — | Same. The regen items already exist as effect items, and each publishes its per-second rate into the stat. |
| `life_leach_multiplier` | not in `DEFAULT_STATS` | **1.0 (constant)** | Stat goes `1.0 → 2.0`, so `LifeLeachModifier`'s 5% lifesteal (`life_leach_modifier.gd:6,26`) **doubles to 10%**. One price-1 item doubles the build's only stat. |
| `flat_weapon_damage` | 0.0 | **1.0 (constant)** | +10% WB on a Fist, +20% on a Shotgun. Unbounded vs weapon tier. |
| `projectile_pierce` | 0.0 | **1.0 (constant)** | +1 target on a Pistol that already pierces 1 → **+100% WB**. |
| `attack_range`, `area_radius` | 500.0 / 1.0 | 25-50 / 0.05-0.10 | **Nothing. No code reads either stat.** |
| `item_base_damage` | 5.0 | 0.25 – 0.5 | Nothing, until you also hold Spinning Orbs or Reflect, then +5-10% (`balance.md` §6.3). |

Three structural problems, all fixable without new systems:

1. **`base_value` is read from the wrong character.** `:192` reads `stats.stats` off the factory's own `$Stats` child (`ItemFactory.tscn` → `Stats.tscn` → `DEFAULT_STATS`), not from `GlobalGameState.current_character`. Generation is blind to the character that will wear the item, so a flat roll cannot be a fair percentage. **Fix**: pass the holder's `Stats` into the generator and roll a **percentage of the holder's current value**, so `+3% max_health` means the same thing on every character. The target table for that percentage is `balance.md` §3.1.
2. **The `base_value == 1` branch (`:460`) is dead code** — identical body to the `else`.
3. **Dead stats are in the pool.** `attack_range` and `area_radius` appear in `DEFAULT_STATS` (`stats.gd:36-37`) and have tooltip text (`item_tooltip.gd:24-25`) but nothing reads them. A generated "Attack Range Plus" costs a full price-1 slot and does literally nothing. Remove them from `_candidate_stat_names()`.

## `drop_pool` and repeat offers

```gdscript
if rng.randf() < repeat_item_chance_scale * pool_size / (pool_size + 1.0):
    return drop_pool.pick_random()
```

The raw pool hit rate `N / (N + 1)` climbs towards 100%, which used to make a run converge on re-offering the same handful of items. `repeat_item_chance_scale` (0.25 in `game_config.json`) multiplies it, so a repeat is at most a 25% outcome and a new item is always the likelier one.

Still true: every generated item is appended, nothing is evicted, and the pool is never reset per loop. The shop fixture `test/tools/shop_ui_preview.gd` sets the scale back to 1.0 so its row is drawn from the pool it pinned.

## Gift and curse (the negative half)

Every generated item is a positive half plus a curse, and the curse is one of two things:
- a **negated stat** (`{stat: {"flat": -x}}` in `Item.modifiers`) - always been the case; or
- a **harmful modifier** (`effect_kind = COST`, e.g. a life drain) appended as a second `Item.effect_scene` entry.

- `negative_modifier_chance` (from `game_config.json`) decides which, once per item, via `_roll_negative_modifier()`. Which COST or BENEFIT scene is then picked is a weighted draw over `modifier_weights` (`_pick_weighted_scene()`). The two are **alternatives, never both** - an item never gets a double penalty from one roll.
- All four generators (`_generate_stat_item`, `_generate_effect_item`, `_generate_buff_item`, `_generate_debuff_item`) roll it.
- **The positive half may only roll a BENEFIT and the curse only a COST.** `_benefit_effect_scenes()` / `_cost_effect_scenes()` partition `effect_scenes` by `BaseModifier.effect_kind` (built once by `_rebuild_scene_pools()`). Without the split the shop can offer "Grants special effect: Life Drain" as an upside. Adding a harmful modifier to the folder and tagging it `COST` is all it takes to widen the pool.
- A harmful scene is appended **after** the positive one, so `effect_scene[0]` still reads as the gift and `effect_scene_condition` stays aligned.
- `_roll_negative_stat(exclude, ...)` never picks the stat the positive half already uses. Picking it again collapses both halves onto one key, and since `Dictionary.merge()` does **not** overwrite by default the curse would silently vanish, yielding a free item.
- A **stat** item's curse scene is its only entry, so its positive stat remains in `modifiers` and the card must keep rendering it as a gain (`ItemTooltip._append_modifier_rows`).
- Buff/debuff items render their payload from scene 0 and any appended curse from scene 1 onwards, on both the card and the flat tooltip.
- `ItemPriceAnalyzer.get_price` only checks whether `effect_scene` is non-empty, so a stat item that rolled a curse is priced as a modifier (3) rather than a stat item (1).
- **[PROPOSED]** the curse's *magnitude* is currently re-rolled independently of the gift, so a 0.5-HP gift can carry a 1.0-HP curse. `balance.md` §3.2 specifies it as a fixed 1.0-1.2× of the gift.
- Covered by `test/Systems/Items/test_item_factory_polarity.gd`. The chance is a roll, so its tests pin `rng.seed` and draw a batch: a fixed seed makes "both branches appear" deterministic rather than flaky. `test_item_pickup.gd` pins its seed for the same reason.

## Known limitations / TODOs
- The value roll is the big one, and it is described above rather than here: one formula for 14 stats, six of which get a constant. See "The value roll".
- `drop_pool` never evicts or resets. See above.
- `_load_scenes_from_dir` uses DirAccess and assumes folder layout; missing/misnamed folders will produce warnings.
- Anything you drop in `src/Systems/Items/modifiers/` is offerable, including a base class that was only ever meant to be `extends`-ed. The abstract `regen_modifier.gd` base used to ship as a scene in that folder and sold as a do-nothing card, because its `_health_delta_per_tick` returns 0.0; that scene is deleted, and `test/Systems/Items/test_offerable_modifier_scenes.gd` sweeps the folder so the next one fails.
- Random generation has some dead/experimental code paths (e.g., `return _generate_debuff_item()` placed before other roll checks) — indicates deliberate temporary behavior or debugging.
- Generation-time randomization lives in the modifiers, not the factory: a modifier scene that supports it implements `randomize_for_generation(context) -> bool` (context: `{"rng": RandomNumberGenerator, "stats": Dictionary}`) and owns its own rolls — e.g., `HealOnEventModifier` picks from its `possible_trigger_event` table, `StatOnKillModifier` rolls a random `target_stat` from `Stats` plus a scaled `add_amount`. `ItemFactory._configure_dynamic_modifier` only builds the context, calls the hook when present, and repacks on mutation; scenes without the hook pass through untouched. Modifiers may also expose `get_generation_suffix()` so generated item names stay distinguishable (e.g., `Stat On Kill Modifier (movement_speed)`).
- The build-time display cache (`_store_effect_display`) is an Array aligned **by index** with `item.effect_scene`. Keying by scene path would not work, because repacked randomized modifiers have an empty `resource_path`.

## Assumptions
- The `Stats` reference exists and exposes `stats` keys used for generating stat modifiers.
- Every figure in "The value roll" is measured against `Stats.DEFAULT_STATS` as it stands. If a base stat changes, that table is wrong until it is re-derived. `docs/systems/balance_audit.md` carries the same figures as numbered audit rows, and the target budgets live in `docs/systems/balance.md` §3.1.
