# Game config (`game_config.json`)

One file at the repo root for numbers you want to tune by hand without opening a script. Edit it, restart the game, done — it is parsed once per run by `src/Scripts/game_config.gd` (`GameConfig.section("item_generation")`).

JSON has no comments, so the meaning of each key lives here.

## `item_generation`

Read by `src/Systems/Items/item_factory.gd` when a factory is created.

| Key | Meaning |
|---|---|
| `negative_modifier_chance` | 0-1. How often a generated item's downside is a harmful **modifier** (a life drain) instead of a negated stat. `0` switches harmful modifiers off. |
| `repeat_item_chance_scale` | 0-1. Scales how often the shop / a drop re-offers an item generated earlier this run. The raw chance is `N / (N + 1)` for a pool of `N` items; this multiplies it. `1` is the old behaviour (almost always a repeat), `0.25` caps repeats at 25%, `0` is a new item every time. |
| `stat_overrides` | Per-stat tweaks, keyed by stat name (any stat in `stats.gd` or a modifier's `provided_stat`). Each entry may set `min_roll` and/or `pick_weight`, see below. |
| `modifier_weights` | Drop weight per modifier, keyed by the scene's file name in `src/Systems/Items/modifiers/` without `.tscn`. A modifier that is not listed weighs `1`. `0` means never. |

`stat_overrides` entries (all optional; the script holds no default for any stat):
- `min_roll`: smallest flat amount a rolled line for that stat can give (the roll is raised to it; a loss is negated afterwards).
- `pick_weight`: relative chance the stat is picked when a stat item or an extra stat line is rolled. Unlisted stats weigh `1`; `0` means never.

Example: `"stat_overrides": {"health": {"min_roll": 3.0, "pick_weight": 3}}`. Add another stat by adding another key.

How the weights behave:
- **They are relative within one pool.** Benefits compete with benefits (the effect item's upside) and costs with costs (the downside). Halving `PoisonModifier` makes poison items rarer and every other benefit slightly more common.
- **Only two costs exist** (`FlatLifeDrainModifier`, `PercentLifeDrainModifier`), so lowering one alone just moves the roll onto the other. To make drains rarer overall, lower `negative_modifier_chance` as well. The chance of one specific cost on an item is `negative_modifier_chance * its weight / sum of cost weights`.
- If every weight in a pool is `0` the pick falls back to uniform rather than failing.

## `item_rarity`

Read through `Item.rarity_value()` by `ItemFactory` (rolling and applying rarity) and `ItemPriceAnalyzer` (price). Every list has 5 entries: common, uncommon, rare, epic, legendary. `docs/systems/item_factory.md` ("Rarity") has the mechanics.

| Key | Meaning |
|---|---|
| `weights` | Relative roll weight per rarity on loop 1. |
| `loop_weight_growth` | Each loop past the first multiplies tier `i`'s weight by `1 + growth * (loop - 1) * i`. `0` keeps the odds fixed. |
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
| `reroll_base_cost` | Price of the first reroll on loop 1. |
| `reroll_loop_step` | Added to the reroll base for every loop past the first. |
| `reroll_step` | Added for every reroll already made in this shop visit. |
| `type_prices` | Shop price per offer type before rarity and loop scaling: `stat`, `buff` (buffs and debuffs), `effect`, `weapon`. |
| `item_price_growth_per_loop` | Every price is multiplied by `1 + growth × (loop − 1)`. `0` keeps prices flat. |
| `boss_coins_base` | Coins the loop-1 boss pays on death. The final boss pays nothing. |
| `boss_coins_per_loop` | Added to the boss bounty for every loop past the first. |

## Adding a new setting

**Do not hardcode tunable numbers.** Any chance, weight, minimum, multiplier, cap or other value someone might rebalance goes into `game_config.json`, not into a `const` or a literal in a script. A `const` is fine only for a true invariant (an array index, an enum, a unit conversion).

Add the key to the JSON, read it where it is used with `GameConfig.section("...").get("key", fallback)`, and document it in this file. Keep a fallback in code so a missing key does not break the game.

`test/Systems/Items/test_item_generation_config.gd` checks that the file parses and that every key under `modifier_weights` names a real modifier scene, so a typo there fails a test instead of silently doing nothing.
