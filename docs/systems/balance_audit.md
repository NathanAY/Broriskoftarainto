# Balance audit

Purpose
- **The companion to `docs/systems/balance.md`.** That file is the prescriptive rulebook and changes only when a design decision changes. This file is the opposite: a dated snapshot of **where the game violates those rules today**. It is allowed to rot; the rulebook is not.
- Read the rulebook to decide what a new weapon, item, modifier or character may give. Read this to see what is currently broken.
- **[CURRENT]** marks a statement about the code as it is written now. **[PROPOSED]** marks the intended target state, not yet implemented.
- Rules marked **[PROPOSED]** elsewhere in the rulebook are not enforced by code. This file is a backlog, not a test suite.

Related reading
- `docs/systems/item_factory.md` — the generator, its current roll, and the degenerate `drop_pool`.
- `docs/systems/modifiers.md` — what each existing modifier actually does, per stack.
- `docs/systems/characters.md` — the `CharacterData` format behind §6 of the rulebook.

## 1. Audit — where the game violates the rules today

Ordered by how much they break the game.

| # | Problem | Where | Measured | Rule violated |
|---|---|---|---|---|
| 1 | **Spread triples weapon output.** 2 extra projectiles per stack × `active_count` | `src/Systems/Items/modifiers/spread_modifier.gd:24-33` | **+200% WB**, price 3 | rulebook §2.1 cap +15% |
| 2 | **Chain triples weapon output.** Full-damage projectile per bounce, `max_bounces * active` | `src/Systems/Items/modifiers/chain_modifier.gd:41, 94` | **+300% WB** vs a pack of 4, price 3 | rulebook §2.1 cap +15% |
| 3 | **`StatMultiplierModifier` doubles every future item, per stack** | `src/Systems/Items/modifiers/stat_multiplier_modifier.gd:8,28` | **×4 at 2 stacks**, uncapped | rulebook §6.1 banned model |
| 4 | **One armor item is +10% EHP; an armor *stack* is +50% EHP** | `src/Systems/Items/modifiers/armor_modifier.gd:41-46`; armor rolls a constant `1.0` (`src/Systems/Items/item_factory.gd:459`) | 4 copies → EHP **×5.06 (+406%)** | rulebook §1, §3.1 caps |
| 5 | **Poison is +300% WB on its own.** `duration 3.0`, full hit damage per stack, `attack_speed` cancels | `src/Systems/Items/modifiers/poison_modifier.gd:11-12, 39`; `src/Systems/Items/Buffs/poison_effect.gd:63` | `poison_dps = 3.0 × weapon_dps`, at any attack speed | rulebook §4.5 |
| 5a | **All poison sources on a target share one `PoisonEffect`**, found by name on the target's `Health`. A poisoned Death Aura and a poisoned Pistol add stack counts together but both tick at whichever weapon applied first | `src/Systems/Items/modifiers/poison_modifier.gd:34-44`, `src/Systems/Items/Buffs/poison_effect.gd:20` | correctness bug, not just balance | — |
| 5b | **`max_stacks 500` never binds** (9 stacks at 3 attacks/s) — dead config that reads like a safety limit | `src/Systems/Items/modifiers/poison_modifier.gd:12` | — | — |
| 5c | **`damage_per_tick` is set once and never refreshed**, so swapping weapons mid-fight does not raise an applied poison | `src/Systems/Items/Buffs/poison_effect.gd:20`, `src/Systems/Items/modifiers/poison_modifier.gd:39` | — | — |
| 6 | **`flat_damage` and `critical_chance` roll a constant**, because `base_value == 0` short-circuits the RNG | `src/Systems/Items/item_factory.gd:458-459` | no variance; `flat_damage +1.0` = +10-20% WB | rulebook §3.1 |
| 7 | **Dead stats are in the generation pool** — nothing reads them | `src/Systems/stats/stats.gd:36-37`; only `src/ui/item_tooltip.gd:24-25` mentions them | **0% power**, full price | rulebook §3.1 |
| 8 | **Generation reads the wrong character.** `base_value` comes from the factory's own `Stats` child, not the holder | `src/Systems/Items/item_factory.gd:192` | a `+1.0 health` item is +0.8% on a Soldier, +2.5% on a Multitasker | `item_factory.md`, "The value roll" |
| 9 | **`base_damage` stat is weapon-independent damage** | `src/Systems/Items/modifiers/spinning_orbs_modifier.gd:68`, `src/Systems/Items/modifiers/reflect_projectiles_modifier.gd:31` | +125% `WB_raw` on a Pistol, +18% on a rifle | rulebook §6.3 |
| 11 | **Pistol (4.0) and Shotgun (5.0) are strictly worse than Fist (10.0)** with no compensating upside | `src/Resources/weapons/Pistol.tres`, `src/Resources/weapons/Shotgun.tres` — 4 of 5 weapons never set `base_damage`, so all sit at the 5.0 default | -60% / -50% | rulebook §2.2 T1 floor |
| 12 | **`Crit` is dead at 1 stack** — `critical_chance` defaults to 0.0, so `randf() * 100 < 0` never fires | `src/Systems/Items/modifiers/crit_modifier.gd:27`, `src/Systems/stats/stats.gd:39` | **0% WB** until a crit item is bought | rulebook §6.2 |
| 13 | **Weapons cost 5 and money starts at 0**, income is +1 per kill | `src/Systems/Items/item_price_analyzer.gd:10`; `src/Scripts/spawner_modifier.gd:22-24` | a weapon costs 5 kills, earned *after* the shop opened | rulebook §2.1 |
| 14 | **Character power spread is huge.** Wildling starts at 288 EHP against the 40 reference, while Brawler starts at +39% `WB_solo` | rulebook §6 table | Wildling **7.2×** the reference EHP, Brawler **1.39×** the reference `WB_solo` | rulebook §6 |
| 15 | **Three of five characters start with no weapon** | `src/Assets/character/ranger/Ranger.tres`, `src/Assets/character/soldier/Soldier.tres`, `src/Assets/character/wildling/Wildling.tres` | 0 `WB_solo` at run start | rulebook §6 |
| 16 | **`highest_hp.tres` and `lowest_hp.tres` are cross-wired** to the wrong scripts | `src/Resources/weapons/aim/highest_hp.tres` runs `LowestHealthTargetSelector`; `src/Resources/weapons/aim/lowest_hp.tres` runs `RandomTargetSelector` | Shotgun aims at the *lowest*-HP target | rulebook §4.8 checklist |
| 18 | **Shotgun pellets sum to 200%**, so it deals double its own `WB_raw` into one target | `src/Systems/weapon/shotgun_weapon.gd:16` | 5.0 actual vs 2.5 budgeted | rulebook §4.2 |
| 19 | **~35% of stat items triple in price** (1 → 3) purely from the curse roll, with identical positive power | `src/Systems/Items/item_price_analyzer.gd:14-24`; `src/Systems/Items/item_factory.gd:206-208` | the price-band-as-budget mapping (rulebook §2.1) breaks for 35% of offers | rulebook §2.1 |
| 20 | **`RegenModifier.tscn`** — the abstract, behaviourless base — is loaded as an offerable scene | `src/Systems/Items/modifiers/` | a price-3 item that does nothing | rulebook §2.1 |
| 21 | **`drop_pool` converges to ~100% reuse** and never resets | `src/Systems/Items/item_factory.gd:117-130` | `(N+1)/(N+2)` pool hit rate | `item_factory.md`, "`drop_pool` is degenerate" |
| 22 | **No player-side scaling at all.** Enemy HP ×5, player power unconstrained | `src/Systems/enemy_spawner.gd:14` | nothing on the item side moves | rulebook §2.3 |
| 23 | **A price-1 `lifeleach` item doubles life leech** — `lifeleach` is not in `DEFAULT_STATS`, so it rolls the constant `1.0` on a stat whose base is 1.0 | `src/Systems/Items/item_factory.gd:459`; `src/Systems/Items/modifiers/life_leach_modifier.gd:6,26` | 5% → 10% lifesteal | rulebook §3.1 |

### 1.1 Fix order

**If you want the shortest path to a playable game:** 1, 2, 4, 5 — the four items that break the ×15 rule outright — then 11 (give every weapon a real `base_damage`), then 7 and 20 (delete the dead stats and the dead scene). Everything else is polish.

### 1.2 Two smaller ones, not balance

- `src/Systems/Items/modifiers/PercentRegenModifier.tscn` used to reference its script with a capital-`M` `Modifiers/` path against a lowercase folder. It worked on NTFS and would break on export. **Fixed** — the folder is now `modifiers/` throughout the project, so the mismatch is no longer possible.
- `test/Systems/test_enemy_health_gut.gd:11` asserts `"Enemy health should be 40"` against a `res://test/TestScene.tscn` that no longer exists.

## 2. Known gaps / TODOs

- **Nothing in the rulebook is enforced by code.** Section 1 is a backlog, not a test suite. The cheapest first step is the rulebook §4.8 weapon-budget test, because `WB` is two multiplications and it will catch every `.tres` edit.
- **No rarity or tier field exists.** `ItemPriceAnalyzer`'s four price bands are the only stratification, and rulebook §2.1 proposes treating them as the budget tiers. A real `tier` field on `Item` / `BaseWeapon` would let the generator widen its ranges per tier — **[PROPOSED]**, not designed further.
- **`money` is not a `DEFAULT_STATS` key**, so it is excluded from the candidate pool but also from every other stat assumption. It is set directly via `set_base_stat`.
- **Item stacking has no cap and no unique ID.** Rulebook §3.1's per-stat caps assume something enforces them; today nothing does (`items.md`, "Known limitations").
- **`_generate_stat_modifiers`' `elif base_value == 1` branch** (`item_factory.gd:460`) is dead code — identical to the `else`. Fold it in when rulebook §3.1 replaces the function.

## 3. Assumptions

These hold the numbers above. If one changes, re-derive the tables rather than trusting the figures.

- `Stats.DEFAULT_STATS` (`src/Systems/stats/stats.gd:29-44`) is the reference frame for every WB and EHP number in the rulebook. If a base stat changes, rulebook §2.3's targets and §4.6's TTK bands move with it.
- Enemy and boss scaling numbers come from the `@export` defaults on `src/Systems/enemy_spawner.gd` and `src/Systems/boss_spawner.gd` as currently set in the scene files. Those are exports, so a scene override changes the curve and invalidates rulebook §4.6.
- `current_loop` on the boss spawner scales from `1` while the enemy spawner scales from `0` (`src/Systems/boss_spawner.gd:58` vs `src/Systems/enemy_spawner.gd:184`). Boss HP is `10 + 500 × loop`, enemy HP is `10 + 20 × (loop − 1)`. That off-by-one is intentional-looking but is worth confirming before anyone tunes against rulebook §4.6.

## 4. Keeping this file honest

This file is not covered by `test/test_doc_links.gd` in its *numbers* — only its path references are checked. Every figure here cites a `file:line`, so when one goes stale the citation is the thing to re-check first. When you fix an audit row, **delete the row** rather than editing the measurement; a shorter table of live problems is worth more than a complete table of half-forgotten ones.
