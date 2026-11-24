# Economy

Purpose
- Where money comes from, where it goes, the economy stats, and the one helper every change goes through. This is the implemented part of the economy build direction planned in `docs/plans/economy-build-direction.md` (Phases 0 and 1).

Key scripts / scenes
- `src/Systems/Items/wallet.gd` (`Wallet`) — static helper: `balance()`, `earn()`, `spend()`, `payday()`, `income_for_loop()`, the capped stat readers (`stat()`, `coins_for()`, `discount()`, `sell_ratio()`) and `ECONOMY_STATS`.
- `src/Systems/Items/item_price_analyzer.gd` (`ItemPriceAnalyzer`) — buy and sell prices, see "Pricing" in `docs/systems/items.md`.
- `src/Scripts/spawner_modifier.gd` — `award_kill()` pays `coins_per_kill × (1 + coin_gain)` on every enemy death.
- `src/Systems/boss_spawner.gd` — `BossSpawner.bounty_for(loop, is_final)` and the boss's `on_death` payout.
- `src/Scenes/menu/shop_menu.gd` — buy, sell, reroll, payday and the shop events.
- `StageManager.loop_of(node)` in `src/Scripts/stage_manager.gd` — the one "which loop is it?" lookup, shared by prices, rerolls and the wallet tally.

Data flow
- **Storage.** The balance is the `money` base stat on the character's `Stats`. It is not in `DEFAULT_STATS`, so item generation never rolls it. It is a float: `coin_gain` makes fractional kill rewards, and the label rounds down.
- **Every change goes through `Wallet`.** `earn(character, amount, source)` and `spend(character, amount, reason)` set the stat and emit `on_money_changed` (`old`, `new`, `source`) on the character's event manager. `spend` returns false and changes nothing when the character cannot afford it. Nothing else writes `money` (tests and previews seed it with `set_base_stat`).
- **Income tally.** `earn` adds the amount to `Character.income_by_loop[loop][source]`. Spending is not tallied.
- **Sources:** `kill`, `boss` (the loop boss's bounty; the final boss pays nothing because no shop follows), `sell`, `interest`, `dividend`, `bounty`.
- **Sinks:** `buy` (shop offer), `reroll`, `insurance`, `tax`.

Economy stats
- Five plain numbers in `Stats.DEFAULT_STATS`, all 0 by default. Only the wallet reads them, always through `Wallet.stat()`, which holds each to its `<stat>_cap` in the config. A curse can drive one negative.
- They are hidden from stat lists while 0 (`Stats.display_stat_names()`), and never roll as a buff or debuff (`ItemFactory._temporary_stat_names()`), because a few seconds of one does nothing.
- A generated item's amount is the stat's `roll` override in `item_generation.stat_overrides`, since a 0 base has no "5-10% of base" to roll.

| Stat | Effect | Read at |
|---|---|---|
| `stock_investment` | Pays `floor(stock)` coins, then grows by `stock × stock_growth` up to `stock_investment_cap`. Growth goes to the base stat, so stock that came from an item keeps its growth after the item is sold. Negative stock pays nothing. | payday |
| `coin_gain` | Kill coins and the boss bounty × `(1 + coin_gain)`, never below 0. | kill, boss death |
| `interest_rate` | Pays `floor(rate × carried)`, at most `interest_cap`. `carried` is the balance minus this loop's income, i.e. the money kept from the previous shop, so the rate rewards saving instead of multiplying kills. | payday |
| `shop_discount` | Offer price × `(1 − discount)`, rounded, never below 1. Rerolls are not discounted. Negative is a surcharge. | shop prices |
| `resale_value` | Added to `sell_ratio` (result clamped to 0-1). | sell prices |

- **Selling cannot be farmed.** A weapon's sell price is a ratio of its *discounted* price and never exceeds it, so a discount plus resale never makes buy-then-sell a profit. A pickup was never bought, so it sells at the ratio of the full price.

Payday
- `Wallet.payday(character, loop)` runs once per shop visit, from `ShopMenu.show_menu()` right after `on_shop_enter`. The order is fixed because each step reads the one before: interest, then dividend, then stock growth. It earns each part under its own source, emits `on_payday` and returns the breakdown, which the shop shows next to the money (`Payday +29 (interest +7, dividend +22)`).

Economy modifiers
- Seven `BaseModifier` scenes in `src/Systems/Items/modifiers/`. They join the generated item pool like any other effect (weights in `item_generation.modifier_weights`), and each reads its numbers from its own block in the `economy_modifiers` config through `BaseModifier._economy_config()`, keyed by scene name.

| Scene | Script | What it does |
|---|---|---|
| `GildedEdgeModifier` | `economy_scaling_modifier.gd` | +`damage` per coin held, capped. Republished on every `money` change, so spending lowers it. |
| `MarketRallyModifier` | `economy_scaling_modifier.gd` | +`attack_speed` per point of `stock_investment`, capped. |
| `InsurancePolicyModifier` | `insurance_policy_modifier.gd` | A lethal hit instead leaves `survive_health` HP and costs a premium that grows per loop. One claim per stack per loop (reset by `on_shop_enter`); nothing happens if the premium cannot be paid. Runs at `Damage.PHASE_ABSORB + 1`, after the energy shield. |
| `BountyMarkModifier` | `bounty_mark_modifier.gd` | Every `interval` s marks a random enemy with a gold ring; killing it pays a bounty (source `bounty`) scaled by `coin_gain`. |
| `RegularCustomerModifier` | `regular_customer_modifier.gd` | Publishes `free_rerolls` (one per stack, capped). The shop's first rerolls each visit are free and do not raise the surcharge. |
| `FireSaleModifier` | `fire_sale_modifier.gd` | Each sale adds `price × stock_per_coin` to base `stock_investment`. |
| `TaxCollectorModifier` | `tax_collector_modifier.gd` | `COST`: after payday, lose `tax_rate` of the money held. The third cost modifier in the curse pool. |

Credit Line and the Tycoon
- `src/Assets/character/tycoon/Tycoon.tres` is the economy character: SMG, starting `stock_investment`, negative `coin_gain`, and `CreditLineModifier` in his `modifiers`. His face art is a copy of the Ranger's until he gets his own.
- `CreditLineModifier` (`credit_line_modifier.gd`) owns the provided stat `credit_limit` (base from config). `Wallet.spend` / `Wallet.can_afford` allow `balance + credit_limit >= price`, so the shop's Buy, reroll and an Insurance premium can all go into debt. Everyone else has no `credit_limit`, so for them nothing changes.
- While the balance is negative the modifier sets the `in_debt` condition, which switches on a conditional `damage` penalty it added at attach (`{"damage": {"percent": -penalty}, "condition": {"in_debt": 1}}`).
- On `on_shop_enter`, before payday, a debt grows by `ceil(debt × debt_interest)` through `Wallet.charge()`, which, unlike `spend`, can push past the credit limit. Payday interest and Tax Collector ignore a negative balance.
- Its generation weight is 0, so it never appears on a generated item, and its `credit_limit` is not a stat item candidate (it is set at attach, so the factory's scan of `provided_stat` never sees it).

- `EconomyScalingModifier` is one script behind two scenes: the scene sets `source_stat` and `target_stat`, and the config block sets `per_unit`, `cap` and `cap_per_extra_stack`.

Events (character bus, schemas in `src/Scripts/event_contract.gd`)
| Event | Payload | Emitted |
|---|---|---|
| `on_money_changed` | `old`, `new`, `source` | every `Wallet.earn` / successful `Wallet.spend` |
| `on_shop_enter` | `loop` | `ShopMenu.show_menu()`, once per visit (reset by Next Stage) |
| `on_payday` | `loop`, `breakdown` | `Wallet.payday()`, right after `on_shop_enter` |
| `on_run_event` | `source`, `what`, `amount` | `RunHistory.record()` — see `docs/systems/run_history.md` |
| `on_purchase` | `resource`, `price` | an offer is bought |
| `on_sell` | `resource`, `price` | a pickup or a weapon is sold |
| `on_reroll` | `cost` | a paid reroll |

Config
- All numbers are in the `economy` block of `game_config.json` plus the `roll` overrides; `docs/systems/game_config.md` lists the keys.

Dependencies
- `GameConfig`, the character's `Stats` and `EventManager` (a character built for a test needs both children).

Known limitations / TODOs
- The economy stats have no icons yet and show the default stat icon.
- Baseline income was measured once (loops 1-3: 50 / 80 / 77 coins, spent 42 / 55 / 93), and the per-item amounts are derived from it (see the plan). They have not been playtested.
- The economy modifiers have no icons yet (they use `src/Assets/modifiers/_default.png`) and no hand-authored item `.tres`; they reach the player only through generated items.
- The Tycoon and Credit Line have not been playtested.
- **Stale UID cache warnings.** A new script registered only by a headless `--import` can log "invalid UID" for every scene that references it, even when the `.uid` file and the scene agree. It is the local `.godot` cache, not the files: touching the script and re-importing clears it.
