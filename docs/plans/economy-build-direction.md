# Plan: the economy build direction

Status: **[PROPOSED]** — nothing here is implemented. Open questions are at the end; Phase 0 has to be measured before the numbers in Phase 1 are final.

## 1. Goal

Today a build goes one of two ways: **offense** (`OFF`, weapon budget) or **survivability** (`DEF`, EHP), the two axes of `docs/systems/balance.md` §1.1. About half a run is spent in the shop, but the shop only ever *spends* power that was earned in combat.

The third direction is **economy**: give up power now to have more power later. An economy build:

1. **Invests** — buys items that make no damage and no EHP, so it is weaker in the next wave.
2. **Compounds** — those items pay coins every shop, and some of them grow.
3. **Cashes out** — converts the extra coins into `OFF`/`DEF` by buying more, rerolling for better rarities, or through modifiers that turn money directly into power.

If step 3 never pays off more than the items it skipped, the direction is a trap. If it pays off too fast, it is the only build. Section 4 is the budget that keeps it in between.

## 2. What exists today **[CURRENT]**

| Piece | Where | Note |
|---|---|---|
| Money storage | a `money` key in `Stats.stats`, set with `set_base_stat` | Not in `DEFAULT_STATS`. No event is emitted when it changes. |
| Income: kills | `src/Scripts/spawner_modifier.gd` | `+1` per kill, a hardcoded literal. The boss pays nothing (`src/Systems/boss_spawner.gd`). |
| Income: selling | `src/Scenes/menu/shop_menu.gd` | Collected pickups and weapons sell for 50% of shop price (`DEFAULT_SELL_RATIO` in `src/Systems/Items/item_price_analyzer.gd`). |
| Prices | `src/Systems/Items/item_price_analyzer.gd` | Stat 1, buff/debuff 2, effect 3, weapon 5, × rarity `positive_multipliers`. **Item prices do not grow with the loop.** |
| Reroll | `src/Scenes/menu/shop_menu.gd` | `1 + 2 × (loop − 1) + rerolls_done`. Grows with the loop. |
| Shop cadence | `src/Scripts/stage_manager.gd` | One 20 s wave + one boss per loop, then exactly one shop visit. |

Money is written from five call sites (kill reward, buy, sell pickup, sell weapon, reroll), each doing its own `get + set_base_stat`. Every economy mechanic below needs to *react* to money changing and to the shop opening, and today neither is observable. That is why Phase 0 exists.

The tunables in that table (kill reward, sell ratio, reroll steps, type prices, heal drop chance) are `const`s or literals. AGENTS.md's "no hardcoded tunables" rule applies, and this work touches all of them, so they move to `game_config.json` as part of Phase 0.

## 3. Phase 0 — foundation (no new content)

### 3.1 A wallet

A small static helper, **wallet.gd** next to `src/Systems/Items/item_price_analyzer.gd`, with three functions:

```gdscript
Wallet.balance(character) -> float
Wallet.earn(character, amount: float, source: String)   # source: "kill", "sell", "dividend", "interest", "bounty", ...
Wallet.spend(character, amount: float, reason: String) -> bool   # false (and no change) if it cannot be afforded
```

Every one of the five call sites goes through it. `earn`/`spend` emit `on_money_changed` on the character's event manager. `Wallet` also keeps a per-loop tally by `source`, which the shop's payday line and the run-end screen read ("Investments earned you 140 coins this run").

`spend` is the one place that decides what "affordable" means, so the Tycoon's credit line (§7) changes one function instead of five.

### 3.2 New events

Registered in `src/Scripts/event_contract.gd` like the existing ones:

| Event | Payload | Emitted by |
|---|---|---|
| `on_money_changed` | `old`, `new`, `source` | `Wallet` |
| `on_shop_enter` | `loop` | `ShopMenu.show_menu()` — guarded so one visit fires it once |
| `on_payday` | `loop`, `breakdown` (source → coins) | the payday step, §5.1 |
| `on_purchase` | `resource`, `price` | shop buy |
| `on_sell` | `resource`, `price` | shop sell (pickup and weapon) |
| `on_reroll` | `cost` | shop reroll |
| `on_wave_start` | `loop` | `StageManager` when a wave starts |

### 3.3 Measure the baseline income

Every budget below is written in terms of **`I_L`, the coins a baseline build earns in loop `L`**. Nobody has measured it. Before Phase 1:

- Play loops 1–3 with the Multitasker and no economy items (or drive a debug scenario), and read `I_1`, `I_2`, `I_3` and the coins left unspent at each shop from the `Wallet` tally.
- **The precondition for this whole plan: money has to be scarce.** If a loop pays ~40 coins and the 4-card row costs ~8, the player already buys everything, and "more money" means nothing.
- **Decided: item prices rise each loop**, the way rerolls already do. A new `economy.item_price_growth_per_loop` key gives `roundi(price × (1 + growth × (loop − 1)))`, applied in `ItemPriceAnalyzer.get_price` after the rarity multiplier and before `shop_discount`. The measurement no longer decides *whether* prices grow, only *by how much*: pick `growth` so the 4-card row costs a similar share of `I_L` on every loop.
- **Selling uses the current loop's price.** The sell ratio is applied to what the item would cost now, so selling never beats buying in the same shop.

### 3.4 Config section

A new `economy` section in `game_config.json`, documented in `docs/systems/game_config.md`. Phase 0 moves the existing numbers in; later phases add theirs:

```json
"economy": {
    "coins_per_kill": 1,
    "sell_ratio": 0.5,
    "reroll_base_cost": 1,
    "reroll_loop_step": 2,
    "reroll_step": 1,
    "type_prices": { "stat": 1, "buff": 2, "effect": 3, "weapon": 5 },
    "item_price_growth_per_loop": 0.5,
    "boss_coins_base": 5,
    "boss_coins_per_loop": 5
}
```

### 3.5 Boss bounty

**Decided:** the loop boss pays coins when it dies: `boss_coins_base + boss_coins_per_loop × (loop − 1)`, through `Wallet.earn(character, amount, "boss")`. The starting values above are placeholders; Phase 0's measurement sets them.

- The boss does not go through `src/Scripts/spawner_modifier.gd` (the comment in `src/Systems/boss_spawner.gd` says so), so the payout hooks the boss's `on_death` in `BossSpawner` itself.
- `coin_gain` multiplies it like any kill, so the bounty gives that stat a second source.
- The final boss pays nothing: the run ends there, and there is no shop to spend it in.
- It is in place **before** the §3.3 measurement, so `I_L` includes it and the scarcity decision accounts for it.

**Tests:** `Wallet.earn/spend` change the balance and emit `on_money_changed` with the right source; `spend` refuses and changes nothing when short; a kill pays `coins_per_kill` read from config; a loop boss pays the configured bounty for its loop and the final boss pays nothing; an item's price at loop 2 is its loop-1 price scaled by `item_price_growth_per_loop` read from config, and its sell price follows; `on_shop_enter` fires once per visit.

## 4. The economy axis — `ECO` budget

This is the section that goes into `docs/systems/balance.md` as §1.3 once the plan is accepted (a design decision, so it belongs in the rulebook, not the audit).

### 4.1 How it is measured

```
ECO(item) = coins the item returns between the shop it was bought in
            and the loop-3 shop (the final-boss choice point)

ROI       = ECO / item price
```

Measured at **baseline income `I_L`** and the **loop-1 shop** purchase, like `WB` is measured at baseline stats.

### 4.2 The rules

| Rule | Value | Why |
|---|---|---|
| Target ROI for a loop-1 purchase | **2.0 … 3.0×** | Below 2×, skipping a stat item for it is never right. |
| **Hard cap** | **3.0×** | A price-1 stat item is +3…5% power. An economy item at 3× returns three stat items' worth of coins, bought one or two loops late: **+9…15% power, delayed**. That lands exactly on the §1 "+15% per item" rule, so the core rule holds for economy items too. |
| Upside | economy only | An economy item gives **no `OFF` or `DEF` gain**. That is its cost: the next wave is fought without it. |
| Downside | may be `OFF`/`DEF` | A curse like "−3% attack speed" fits the theme and is still budgeted at 1.0…1.2× of the gift (§3.2). |
| Late purchases | allowed, shown | An investment bought at loop 3 barely pays back. Rather than hiding economy offers late, the tooltip states the payback ("pays for itself in ~2 shops"). |
| Every compounding stat has a cap | config | Past loop 3 the run has no ceiling (`StageManager.current_loop` is unbounded), so anything that grows per loop needs a cap or it is infinite on a long run. |

The promise of the direction is **stacking**: one investment is a modest delayed stat item; eight of them are a shop where the player buys the whole row and rerolls for rarity. Stacking is capped per stat (§5), not per item, exactly like `docs/systems/balance.md` §3.1.

## 5. New stats

All five are plain numbers in `Stats.DEFAULT_STATS` with a default of `0.0`. Being in `DEFAULT_STATS` makes them candidates for generated stat items automatically (`_candidate_stat_names()` in `src/Systems/Items/item_factory.gd`), and `stat_overrides` in `game_config.json` already gives each one a `min_roll` and `pick_weight` — no new generation code.

Amounts per price-1 item come from the §4.2 ROI band. Because prices rise each loop, ROI is measured in coins against the price **paid**, and a coin earned later buys less. That makes `shop_discount` worth more in late loops and flat payouts (`stock_investment`, bounties) worth less, which is one more reason `stock_investment` compounds. The provisional numbers below assume **`I_L ≈ 40` coins per loop**; Phase 0 replaces that assumption, and the formula in each row says how to redo it.

| Stat | What it does | When | Price-1 item gives | Cap | Config keys |
|---|---|---|---|---|---|
| `stock_investment` | Pays `floor(stock)` coins, then grows by `stock_growth` | payday | **+1.0** (pays 1 + 1.1 by the loop-3 shop = 2.1×) | 100 | `stock_growth` (0.10), `stock_cap` |
| `coin_gain` | Coins from kills × `(1 + coin_gain)`. Fractions carry over, so +5% on 1-coin kills is real | every kill | **+3%** (`0.03 × (I_2 + I_3) ≈ 2.4×`) | +100% | `coin_gain_cap` |
| `interest_rate` | Pays `interest_rate × money held`, at most `interest_cap` coins | payday | **+5%** | 30% | `interest_rate_cap`, `interest_cap` (coins per payday) |
| `shop_discount` | Item prices × `(1 − discount)`, never below 1 coin. Rerolls are not discounted | shop | **+3%** (`0.03 × spend over loops 2–3`) | 40% | `shop_discount_cap` |
| `resale_value` | Added to the sell ratio | sell | **+5 pp** | ratio 0.9 | `resale_value_cap` |

### 5.1 Stock investment — the user's example, exactly

> 20 stock pays 20 coins and grows by 2; next shop it pays 22.

**Decided:** `stock_growth = 0.10`, compounding (not a flat +2 per loop): pay `floor(stock)`, then `stock += stock × stock_growth`. 20 → 22 → 24.2 → 26.6. The fraction is kept, so a single +1.0 item grows 1.0 → 1.1 → 1.21 and starts paying 2 a shop once it passes 2.0.

**Where the growth lives.** Items add stock as ordinary stat modifiers, and the growth is added to the **base** stat: `base += get_stat("stock_investment") × stock_growth`. 20 stock that all came from items still grows by 2. Selling an item later removes that item's part but keeps the growth it already earned ("realised gains"), which is both simple and the right feel.

### 5.2 Payday — one fixed order at shop entry

On `on_shop_enter`, once per loop:

1. **Debt interest** (Tycoon only, §7).
2. **Interest** on money held — computed *before* dividends, so dividends cannot inflate interest.
3. **Stock dividend** — `floor(stock_investment)`.
4. **Stock growth.**
5. Emit `on_payday` with the breakdown. The shop shows it next to the money label: `Payday +27 (dividends +22, interest +5)`.

The order is written down because each step reads what the previous one wrote; changing it silently changes the numbers.

### 5.3 What these stats must not do

- **No buffs or debuffs of economy stats.** A 3-second "+2 stock" is meaningless. Economy stats are excluded from the buff/debuff roll (a list next to `LISTENER_ONLY_STATS` in `src/Systems/Items/item_factory.gd`).
- **A curse may negate one** (−1 stock, −3% discount), and payout clamps at 0 so a negative stock never charges the player. A negative `shop_discount` is a real surcharge; that is allowed and is a good curse.
- **Watch the offer mix.** `stats.stats.size()` weights how often a stat item vs. buff vs. effect is generated (`item_factory.gd`), so five new stats shift the whole mix towards stat items. Re-check the shares in `docs/systems/balance.md` §2.1 after adding them, and lower the economy stats' `pick_weight` if a non-economy build starts seeing too many.

## 6. New modifiers (effect items, price 3)

Each one is a `BaseModifier` scene in `src/Systems/Items/modifiers/`, follows the `X + S × (stacks − 1)` scaling model (`docs/systems/balance.md` §6.1), and reads its numbers from a `modifiers.<Name>` block in `game_config.json`. The first three are the **cash-out** half of the direction: they turn money into `OFF`/`DEF`, so an economy build has a payoff even before it spends.

| Modifier | Mechanic | Listens to | Bridge | Budget |
|---|---|---|---|---|
| **Gilded Edge** | +`damage` % per coin held, capped. Republished on every money change. | `on_money_changed` | money → `OFF` | Cap +15% `OFF` (first stack), +5% per extra stack |
| **Insurance Policy** | A lethal hit instead leaves 1 HP and costs a premium of `premium_base + premium_per_loop × (loop − 1)` coins. Once per wave. Does nothing if the player cannot pay. | `before_take_damage` (see listener phases in `docs/systems/damage.md`), `on_wave_start` | money → `DEF` | Defensive class, +10% EHP. Compare `src/Systems/Items/modifiers/emergency_heal_modifier.gd` |
| **Market Rally** | At wave start, a buff of +`attack_speed` per point of `stock_investment` for `rally_duration` s, capped. Uses the existing buff system (`src/Systems/Items/Buffs/buff.gd`). | `on_wave_start` | stock → `OFF` | Time-averaged ≤ +15% `OFF` at cap |
| **Bounty Mark** | Every `bounty_interval` s one enemy wears a gold mark. Killing it pays `bounty_base + bounty_per_loop × (loop − 1)` coins. Stacks add coins, not marks. | timer, `on_kill` | combat → money | `ECO` ≤ 3× price. The only one that asks something of the player mid-fight. Its VFX follows `docs/systems/effects.md`. |
| **Regular Customer** | The first reroll each shop visit is free; +1 free reroll per extra stack (cap 3). A free reroll does not raise the surcharge. | `on_shop_enter`, `on_reroll` | shop quality | 1 free reroll is worth ~3 + 5 coins over loops 2–3: 2.7× at price 3, in band |
| **Fire Sale** | Selling anything also adds `fire_sale_ratio × sell price` to `stock_investment`. | `on_sell` | gear → stock | Turns dead pickups into growth; synergy with `resale_value` |

And one **curse**, for the negative-modifier pool:

| Modifier | Mechanic | Note |
|---|---|---|
| **Tax Collector** (`COST`) | At payday, lose `tax_rate` of money held (after payday). | A third `COST` modifier. `docs/systems/game_config.md` notes that with only two costs, lowering one just moves the roll onto the other; a third makes those weights meaningful. |

The tension the set is built around: **Interest and Gilded Edge reward holding money; everything else rewards spending it.** Neither is always right, which is what makes the shop a decision instead of a checkout.

## 7. New character — the Tycoon

A potato in a top hat (the shared `src/Assets/character/potato.png` body with new eyes and mouth overlays, per `docs/systems/characters.md` "Character art"). He earns from the market, not from fighting.

| | Value | Why |
|---|---|---|
| Weapon | `src/Resources/weapons/Smg.tres` | No character starts with it, so the kit is distinct. "Spraying money" fits. |
| `base_stats` | `health 35`, `damage 0.9`, `stock_investment 5`, `coin_gain −0.25` | Kills pay him less; his income is the market. |
| Modifier | **Credit Line** (below) | The signature mechanic. |

Starting `WB_solo` ≈ `2.0 × 5 × 0.9 × 0.85 ≈ 7.7` (1.09× the reference) and `EHP 35` (0.88×), both inside the §5 bands — `test/Systems/characters/test_character_power_budget.gd` checks this from the `.tres`.

### Credit Line

The Tycoon may **spend into debt**, down to `−credit_limit`.

- `credit_limit` is a **provided stat** of the Credit Line modifier (`docs/systems/stats.md`, "Provided (dynamic) stats"). It exists only on the Tycoon, and a generated `+credit_limit` item does nothing for anyone else — the same pattern `life_leach_multiplier` uses.
- At payday, step 1, debt grows by `debt_interest` (e.g. 25%) before any income is paid.
- While money is below 0 the character has the `in_debt` condition, and a conditional modifier `{"damage": {"percent": −debt_damage_penalty}, "condition": {"in_debt": 1}}` applies. That reuses the existing condition system in `src/Systems/stats/stats.gd`; no new mechanism.
- `Wallet.spend` checks `balance + credit_limit ≥ price` for him and `balance ≥ price` for everyone else. That is the single change §3.1 made room for.

What it makes interesting: on loop 1 he can borrow to buy two items he cannot afford, fight loop 2 stronger but with a damage penalty, and repay from dividends — or over-leverage and spend loop 3 paying interest. It is the economy direction's risk turned into a character.

**Decided:** the Tycoon with Credit Line is the economy character. (A simpler "Haggler" — 5th shop slot, free first reroll, no selling — was considered and dropped as much less distinct.)

## 8. UI

- **Payday line** by the money label in the shop, from `on_payday` (§5.2).
- **Stat descriptions** for the five stats in the description table in `src/ui/item_tooltip.gd`, next to the existing `money` entry.
- **Stat icons** — one per stat in `src/Assets/stats/`, named after the stat key (`docs/visual_style.md`, "Asset classes"); `Stats.get_stat_icon()` finds them there with no code change.
- **An "Economy" group** in the shop's stats panel, so five zero-valued rows do not crowd a combat build's panel. Rows at 0 are hidden.
- **Price display** on `src/Scenes/menu/shop_item_card.gd` shows the discounted price, with the original struck through when `shop_discount > 0`.
- **Run-end screen** (`src/Scenes/menu/RunEndScreen.tscn`) shows coins earned by source, from the `Wallet` tally.
- Check every change with `.\run_scene_shot.bat res://test/tools/shop_ui_preview.tscn`.

## 9. Implementation order

Each phase follows AGENTS.md: write the test, run it, read the failure, fix, run again. No test pins a balance number — expectations are derived from `game_config.json` values read in the test (e.g. "payday pays `floor(stock)` and stock grows by `stock × stock_growth`"), never from literals.

| Phase | Content | Done when |
|---|---|---|
| **0** | `Wallet`, the seven events, `economy` config section, existing tunables moved out of code, boss bounty, income measured | All money goes through `Wallet`; the measured `I_1..I_3` and the scarcity decision (§3.3) are written into this plan |
| **1** | The five stats, payday, discount and resale in pricing, tooltips, icons | Each stat has a suite; a payday with all of them active pays the documented breakdown in the documented order |
| **2** | Gilded Edge, Insurance Policy, Market Rally first (the cash-out half), then Bounty Mark, Regular Customer, Fire Sale, Tax Collector | Each modifier has a suite at 1 and 3 stacks (`docs/systems/balance.md` §6.4); weights added to `modifier_weights` |
| **3** | Tycoon `.tres`, Credit Line, `in_debt` condition, art | Character budget test passes; a test buys into debt, takes the penalty, pays interest at payday |
| **4** | Docs and balance | `ECO` section in `docs/systems/balance.md`; `docs/systems/stats.md`, `docs/systems/modifiers.md`, `docs/systems/characters.md`, `docs/systems/ui_shop_portal.md`, `docs/systems/game_config.md` updated; a played economy run reaches the §2.3 power curve by loop 3 instead of overshooting it |

Phase 4's playtest is the real acceptance test: **an all-in economy build should be the weakest build at loop 1, roughly even at loop 2, and the strongest at the loop-3 choice point** — and still within the `docs/systems/balance.md` §2.3 band, not 20× over it.

## 10. Open questions

1. ~~**Stock growth: compounding 10% or flat?**~~ **Decided: 10% compounding** (20 → 22 → 24.2 → 26.6), capped by `stock_cap` so a long run past loop 3 stays bounded.
2. ~~**Does item pricing scale with the loop?**~~ **Decided: yes** (§3.3). The growth rate is still set from the Phase 0 measurement; 0.5 in §3.4 is a placeholder.
3. ~~**Tycoon with Credit Line, or the simpler Haggler?**~~ **Decided: the Tycoon with Credit Line** (§7). The Haggler is dropped.
4. ~~**Should the boss pay coins?**~~ **Decided: yes, a boss bounty** (§3.5). It is in place before the Phase 0 measurement, so question 2 is answered with it included.
