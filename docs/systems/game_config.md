# Game config (`game_config.json`)

One file at the repo root for numbers you want to tune by hand without opening a script. Edit it, restart the game, done — it is parsed once per run by `src/Scripts/game_config.gd` (`GameConfig.section("item_generation")`).

JSON has no comments, so the meaning of each key lives here.

## `item_generation`

Read by `src/Systems/Items/item_factory.gd` when a factory is created.

| Key | Meaning |
|---|---|
| `negative_modifier_chance` | 0-1. How often a generated item's downside is a harmful **modifier** (a life drain) instead of a negated stat. `0` switches harmful modifiers off. |
| `repeat_item_chance_scale` | 0-1. Scales how often the shop / a drop re-offers an item generated earlier this run. The raw chance is `N / (N + 1)` for a pool of `N` items; this multiplies it. `1` is the old behaviour (almost always a repeat), `0.25` caps repeats at 25%, `0` is a new item every time. |
| `modifier_weights` | Drop weight per modifier, keyed by the scene's file name in `src/Systems/Items/modifiers/` without `.tscn`. A modifier that is not listed weighs `1`. `0` means never. |

How the weights behave:
- **They are relative within one pool.** Benefits compete with benefits (the effect item's upside) and costs with costs (the downside). Halving `PoisonModifier` makes poison items rarer and every other benefit slightly more common.
- **Only two costs exist** (`FlatLifeDrainModifier`, `PercentLifeDrainModifier`), so lowering one alone just moves the roll onto the other. To make drains rarer overall, lower `negative_modifier_chance` as well. The chance of one specific cost on an item is `negative_modifier_chance * its weight / sum of cost weights`.
- If every weight in a pool is `0` the pick falls back to uniform rather than failing.

## Adding a new setting

Add the key to the JSON, read it where it is used with `GameConfig.section("...").get("key", fallback)`, and document it in this file. Keep a fallback in code so a missing key does not break the game.

`test/Systems/Items/test_item_generation_config.gd` checks that the file parses and that every key under `modifier_weights` names a real modifier scene, so a typo there fails a test instead of silently doing nothing.
