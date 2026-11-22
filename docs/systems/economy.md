# Economy

Purpose
- Where money comes from, where it goes, and the one helper every change goes through. The plan for the economy build direction this is the foundation of is `docs/plans/economy-build-direction.md`; this doc describes only what is implemented.

Key scripts / scenes
- `src/Systems/Items/wallet.gd` (`Wallet`) — static helper: `balance()`, `earn()`, `spend()`, `income_for_loop()`, `config()`.
- `src/Systems/Items/item_price_analyzer.gd` (`ItemPriceAnalyzer`) — buy and sell prices, see "Pricing" in `docs/systems/items.md`.
- `src/Scripts/spawner_modifier.gd` — `award_kill()` pays `coins_per_kill` on every enemy death.
- `src/Systems/boss_spawner.gd` — `BossSpawner.bounty_for(loop, is_final)` and the boss's `on_death` payout.
- `src/Scenes/menu/shop_menu.gd` — buy, sell, reroll and the shop events.
- `StageManager.loop_of(node)` in `src/Scripts/stage_manager.gd` — the one "which loop is it?" lookup, shared by prices, rerolls and the wallet tally.

Data flow
- **Storage.** The balance is the `money` base stat on the character's `Stats`. It is not in `DEFAULT_STATS`, so item generation never rolls it.
- **Every change goes through `Wallet`.** `earn(character, amount, source)` and `spend(character, amount, reason)` set the stat and emit `on_money_changed` (`old`, `new`, `source`) on the character's event manager. `spend` returns false and changes nothing when the character cannot afford it. Nothing else writes `money` (tests and previews seed it with `set_base_stat`).
- **Income tally.** `earn` adds the amount to `Character.income_by_loop[loop][source]`. Spending is not tallied. The shop prints the current loop's tally when it opens (`Shop loop N, income this loop: {...}`), which is how baseline income per loop is measured.
- **Sources today:** `kill` (`coins_per_kill` per enemy death), `boss` (the loop boss's bounty; the final boss pays nothing because no shop follows) and `sell` (pickups and weapons).
- **Sinks today:** `buy` (shop offer) and `reroll`.

Events (character bus, schemas in `src/Scripts/event_contract.gd`)
| Event | Payload | Emitted |
|---|---|---|
| `on_money_changed` | `old`, `new`, `source` | every `Wallet.earn` / successful `Wallet.spend` |
| `on_shop_enter` | `loop` | `ShopMenu.show_menu()`, once per visit (reset by Next Stage) |
| `on_purchase` | `resource`, `price` | an offer is bought |
| `on_sell` | `resource`, `price` | a pickup or a weapon is sold |
| `on_reroll` | `cost` | a paid reroll |

Config
- All numbers are in the `economy` block of `game_config.json`; `docs/systems/game_config.md` lists the keys.

Dependencies
- `GameConfig`, the character's `Stats` and `EventManager` (a character built for a test needs both children).

Known limitations / TODOs
- Baseline income per loop has not been measured yet; the shop's printed tally is the tool for it. `item_price_growth_per_loop` and the boss bounty numbers are placeholders until it is.
- The rest of the plan — economy stats, payday, the economy modifiers and the Tycoon — is not implemented.
