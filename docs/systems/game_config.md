# Game config (`game_config.json`)

One file at the repo root for numbers you want to tune by hand without opening a script. Edit it, restart the game, done — it is parsed once per run by `src/Scripts/game_config.gd` (`GameConfig.section("item_generation")`).

JSON has no comments, so the meaning of each key lives here.

## `item_generation`

Read by `src/Systems/Items/item_factory.gd` when a factory is created.

| Key | Meaning |
|---|---|
| `negative_modifier_chance` | 0-1. How often a generated item's downside is a harmful **modifier** (a life drain) instead of a negated stat. `0` switches harmful modifiers off. |
| `repeat_item_chance_scale` | 0-1. Scales how often the shop / a drop re-offers an item generated earlier this run. The raw chance is `N / (N + 1)` for a pool of `N` items; this multiplies it. `1` is the old behaviour (almost always a repeat), `0.25` caps repeats at 25%, `0` is a new item every time. |
| `stat_overrides` | Per-stat tweaks, keyed by stat name (any stat in `stats.gd` or a modifier's `provided_stat`). Each entry may set `roll`, `min_roll` and/or `pick_weight`, see below. |
| `modifier_weights` | Drop weight per modifier, keyed by the scene's file name in `src/Systems/Items/modifiers/` without `.tscn`. A modifier that is not listed weighs `1`. `0` means never. |

`stat_overrides` entries (all optional; the script holds no default for any stat):
- `roll`: the flat amount a rolled line gives for a stat whose base value is 0 (the economy stats). Default `1`. A stat with a non-zero base rolls 5-10% of it instead.
- `min_roll`: smallest flat amount a rolled line for that stat can give (the roll is raised to it; a loss is negated afterwards).
- `pick_weight`: relative chance the stat is picked when a stat item or an extra stat line is rolled. Unlisted stats weigh `1`; `0` means never.

Example: `"stat_overrides": {"health": {"min_roll": 3.0, "pick_weight": 3}}`. Add another stat by adding another key.

How the weights behave:
- **They are relative within one pool.** Benefits compete with benefits (the effect item's upside) and costs with costs (the downside). Halving `PoisonModifier` makes poison items rarer and every other benefit slightly more common.
- **Only two costs exist** (`FlatLifeDrainModifier`, `PercentLifeDrainModifier`), so lowering one alone just moves the roll onto the other. To make drains rarer overall, lower `negative_modifier_chance` as well. The chance of one specific cost on an item is `negative_modifier_chance * its weight / sum of cost weights`.
- If every weight in a pool is `0` the pick falls back to uniform rather than failing.

## `buff`

Read by `src/Systems/Items/Buffs/buff.gd` as the default for `max_stacks`.

| Key | Meaning |
|---|---|
| `max_stacks` | Most stacks a buff holds at once. At the cap the oldest stack expires to make room for a new one. A buff `.tres` that sets its own `max_stacks` overrides this. |

## `item_rarity`

Read through `Item.rarity_value()` by `ItemFactory` (rolling and applying rarity) and `ItemPriceAnalyzer` (price). Every list has 5 entries: common, uncommon, rare, epic, legendary. `docs/systems/item_factory.md` ("Rarity") has the mechanics.

| Key | Meaning |
|---|---|
| `weights` | Relative roll weight per rarity on stage 1. |
| `stage_weight_growth` | Each stage past the first multiplies tier `i`'s weight by `1 + growth * (stage - 1) * i`. `0` keeps the odds fixed. |
| `positive_multipliers` | Gains on the item (and its buff/debuff payload) are multiplied by this. Also multiplies the shop price. |
| `negative_multipliers` | Losses on the item are multiplied by this. Keep it below the positive one. |
| `extra_positive_chance` | Chance per attempt of an extra gain line; a rarity gets as many attempts as its index (common 0, legendary 4). |
| `extra_negative_chance` | Chance of one extra loss line. |

## `economy`

Read through `Wallet.config()` by `src/Systems/Items/wallet.gd`, `src/Systems/Items/item_price_analyzer.gd`, `src/Scenes/menu/shop_menu.gd`, `src/Scripts/spawner_modifier.gd` and `src/Systems/boss_spawner.gd`. `docs/systems/economy.md` has the mechanics.

| Key | Meaning |
|---|---|
| `coins_per_kill` | Coins paid for every enemy death (not the boss). |
| `sell_ratio` | 0-1. Share of an item's current shop price paid when it is sold. |
| `reroll_base_cost` | Price of the first reroll on stage 1. |
| `reroll_stage_step` | Added to the reroll base for every stage past the first. |
| `reroll_step` | Added for every reroll already made in this shop visit. |
| `type_prices` | Shop price per offer type before rarity and stage scaling: `stat`, `buff` (buffs and debuffs), `effect`, `weapon`. |
| `item_price_growth_per_stage` | Every price is multiplied by `1 + growth × (stage − 1)`. `0` keeps prices flat. |
| `boss_coins_base` | Coins the stage-1 boss pays on death. The final boss pays nothing. |
| `boss_coins_per_stage` | Added to the boss bounty for every stage past the first. |
| `stock_growth` | At payday, stock grows by `stock_investment × stock_growth`. |
| `stock_investment_cap` | Stock stops growing here (items can still push it higher). |
| `coin_gain_cap` | Highest `coin_gain` that counts. |
| `interest_rate_cap` | Highest `interest_rate` that counts. |
| `interest_cap` | Most coins interest can pay in one payday. |
| `shop_discount_cap` | Highest `shop_discount` that counts. |
| `resale_value_cap` | Highest `resale_value` that counts; added to `sell_ratio`. |

The per-item amount of each economy stat is its `roll` in `item_generation.stat_overrides`.

## `enemy_rarity`

Read by `src/Systems/enemy_spawner.gd`. One block per enemy type, keyed by its scene file name in `src/Systems/enemies/` without `.tscn`. Give every enemy in the spawn table a `weight`: common ones high, specials low, so the arena stays mostly grunts with the odd tough specialist. `base_health` is optional and only set for specials.

| Key | Meaning |
|---|---|
| `weight` | Spawn weight of that enemy's row in `src/Scenes/Game.tscn`, relative to the other open rows. The only place weights live: a scene not listed weighs `1`, and `0` never spawns it. |
| `base_health` | Replaces the `health` stat in the enemy's `Stats` node at spawn, before elite and stage scaling. Omit it to keep the scene's own health. |

## `economy_modifiers`

One block per economy modifier, keyed by its scene name in `src/Systems/Items/modifiers/`, read by `BaseModifier._economy_config()`. `docs/systems/economy.md` describes each modifier. "Extra stack" means every copy after the first.

| Block | Keys |
|---|---|
| `GildedEdgeModifier` | `per_unit` (damage per coin held), `cap`, `cap_per_extra_stack` |
| `MarketRallyModifier` | `per_unit` (attack speed per point of stock), `cap`, `cap_per_extra_stack` |
| `InsurancePolicyModifier` | `premium_base` (coins on stage 1), `premium_per_stage`, `survive_health` (HP left after a saved hit) |
| `BountyMarkModifier` | `interval` (seconds between marks), `coins_base`, `coins_per_stage`, `bonus_per_extra_stack` |
| `RegularCustomerModifier` | `max_free_rerolls` |
| `FireSaleModifier` | `stock_per_coin` (stock per coin of sale price), `bonus_per_extra_stack` |
| `TaxCollectorModifier` | `tax_rate` (share of money taken), `tax_rate_per_extra_stack` |
| `CreditLineModifier` | `credit_limit` (coins of debt allowed), `debt_interest` (share a debt grows by each shop), `debt_damage_penalty` (damage lost while in debt) |

## `arena`

Read by `src/Systems/arena.gd`. The ground art is brown; each theme recolours it (and the wall outline) with a hue-rotate shader. A random theme is picked when the arena loads and a different one at every `StageManager.start_new_stage()`.

| Key | Meaning |
|---|---|
| `decor_chance` | Chance that each 64 px ground cell gets one decor sprite (from `tiles_3.png`, or the theme's own `decor` sheet). |
| `decor_scale` | Scale of a decor sprite (the sheet cells are 128x128 px, so 0.5 is 64x64, one ground cell). |
| `themes` | List of themes, one picked per stage: `{name, hue_shift, saturation, brightness}` recolours the flat ground and the border (`hue_shift` is degrees, the art starts brown so ~75-100 is green; the others are multipliers). An optional `decor` is the path of an 8x8 sheet of transparent-background sprites scattered over the ground instead of the default sheet; unlike the default it is not recoloured, so pair it with a ground colour that suits it. Add a row for a new look; an empty list leaves the art brown. |

## `final_boss`

Read by `src/Systems/boss/boss_brain.gd`, `src/Systems/boss/boss_attack.gd` and `src/Systems/boss/boss_bullets.gd`. See `docs/systems/final_boss.md`. Lists marked *per phase* have one entry per phase (1, 2, 3).

| Key | Meaning |
|---|---|
| `phase_thresholds` | Health fractions that end phase 1 and phase 2. A hit is cut short at the next one, so no phase is skipped. |
| `intro_time` | Seconds after spawning before the first attack. Kept equal to `name_card_time`, so the first attack comes as the card fades. |
| `name_card_time` | Seconds the boss's name card is on screen (fade in, hold, fade out). |
| `sound_volume_db` | Volume offset for every boss sound. |
| `shake` | Camera kick in px (before the options slider) per moment: `phase` (phase change), `wall` (ram hits a wall), `blast` (safes land), `erupt` (burrow eruption), `death`. |
| `transition_time` | Seconds the boss stands still and takes no damage between phases. |
| `attack_gap` | Seconds of walking between one attack's recovery and the next telegraph. |
| `keep_distance` | *Per phase.* Distance in px the boss walks to between attacks (0 = right onto the player). |
| `speed_mult` | *Per phase.* Movement speed multiplier. |
| `phase3_damage_taken_mult` | Damage multiplier on hits the boss takes in phase 3. |
| `coin_speed`, `coin_size`, `coin_life`, `coin_hit_radius` | Coin speed (px/s), drawn size (px), lifetime (s), and collider radius as a fraction of `coin_size`. |
| `coin_damage` | A coin's damage before the boss's `damage` stat and the attack's `damage_mult`. |
| `attacks.<key>` | One block per attack. Every block has `weight` (pick chance), `phases` (which phases may pick it), `telegraph` and `recover` (seconds). |
| `attacks.coin_spray` | `count` coins per volley over `spread_deg`; `volleys` volleys, `volley_interval` s apart; `damage_mult`. |
| `attacks.dividend_ring` | `count` slots in the ring, `gap` of them left empty towards the player; `speed_mult` on `coin_speed`; `damage_mult`. |
| `shockwave_radius`, `shockwave_force`, `shockwave_duration` | The phase-change push: reach (px), knockback speed (m/s) and how long it lasts (s). No damage. |
| `adds_phases`, `adds_interval`, `adds_pack_size`, `adds_max_alive`, `adds_spawn_distance` | Debt Collectors: which phases spawn them, seconds between packs, swarmers per pack, the alive cap, and spawn distance from the player (px). |
| `enrage_time`, `enrage_recover_mult` | Seconds of fight before the boss enrages, and the multiplier on its recoveries and attack gaps after that. |
| `plate_burst_radius` | Size (px) of the visual pop when the ram plate breaks at phase 3. |
| `death_time_scale`, `death_slowmo_time`, `death_ramp_time` | The kill's slow motion: time scale, real seconds held, real seconds easing back to 1. |
| `death_coins`, `death_coin_lifetime` | The kill's coin fountain: particle count and lifetime (s). |
| `attacks.gold_rush` | The ram script with `charges` 4: each charge runs until a wall (or `max_duration`), then re-aims after `between` s. Same keys as `attacks.ram`. |
| `attacks.golden_beam` | `arc_deg` swept over `sweep_time` (s), beam `length` and `width` (px), `hit_interval` (s, per body), `damage` (times the damage stat). |
| `attacks.margin_call` | `close_time`, `hold_time`, `open_time` (s), `min_radius` (px around the boss), `start_radius` (px, only without an arena), `ring_width` (px), `hit_interval` (s), `damage` (times the damage stat) to anything outside the ring. |
| `attacks.ram`, `attacks.double_ram` | One script: `charges` (1 or 2), `between` (pause between charges, s), `speed_mult` on movement speed while charging, `max_duration` per charge (s), `wall_stagger` (extra recovery after a wall hit on the last charge, s), `line_length` of the telegraph line (px). |
| `attacks.safe_drop` | `count` safes, `fall_time` (s), blast `radius` (px), `scatter` (px around where the player is heading), `drop_height` and `safe_size` (px, visual), `damage` (times the boss's damage stat). |
| `attacks.burrow` | `track_time` and `lock_time` (s), `mound_speed` (px/s), `mound_size` (px), `erupt_radius` (px), `damage` (times the damage stat), and the eruption ring: `ring_count`, `ring_gap`, `ring_speed_mult`, `ring_damage_mult`. |
| `attacks.coin_spiral` | `duration` (s), `arms`, `interval` between shots (s), `turn_deg` per shot, `speed_mult`, `damage_mult`. |

## Adding a new setting

**Do not hardcode tunable numbers.** Any chance, weight, minimum, multiplier, cap or other value someone might rebalance goes into `game_config.json`, not into a `const` or a literal in a script. A `const` is fine only for a true invariant (an array index, an enum, a unit conversion).

Add the key to the JSON, read it where it is used with `GameConfig.section("...").get("key", fallback)`, and document it in this file. Keep a fallback in code so a missing key does not break the game.

`test/Systems/Items/test_item_generation_config.gd` checks that the file parses and that every key under `modifier_weights` names a real modifier scene, so a typo there fails a test instead of silently doing nothing.
