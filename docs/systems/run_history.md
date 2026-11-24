# Run history and effect messages

Effects that pay out off-screen (a bounty, a dividend, a stat gained on a kill) are announced as floating text over the player and listed in a **Run history** tab, so the player can see when they happened.

## The one call
`RunHistory.record(holder, source, what, amount)` in `src/Systems/run_history.gd`:
- `source` is the effect's display name (`display_name` for a modifier), `what` is a stat name or `coins`, `amount` is negative for a loss.
- Appends to `Character.run_history`, merging repeats of the same `source` + `what` in the same stage into one entry with a `count` — a stat gained on every kill is one line, `Stat On Kill: +6 Health (x12)`.
- Emits `on_run_event` (`source`, `what`, `amount`) on the character's bus.
- Does nothing for a holder that is not a `Character` (an enemy configured with the same modifier) or for a zero amount.

## Who records
| Source | What |
|---|---|
| `bounty_mark_modifier.gd` | coins paid for a marked kill |
| `stat_on_kill_modifier.gd` | the stat gained per kill |
| `fire_sale_modifier.gd` | `stock_investment` gained on a sale |
| `tax_collector_modifier.gd`, `credit_line_modifier.gd`, `insurance_policy_modifier.gd` | coins lost (tax, debt interest, premium) |
| `emergency_heal_modifier.gd` | health healed |
| `Wallet.payday()` | interest and the Stock Investment dividend (coins), stock growth (`stock_investment`); labels in `Wallet.PAYDAY_LABELS` |

Plain kill income, buying, selling and rerolls are not recorded: the player chose them or sees them already. A new effect that pays out calls `RunHistory.record` next to the change it makes.

## Floating text
`src/ui/numberspawn/RunEventSpawner.tscn` (a child of `src/Systems/Character.tscn`) listens to `on_run_event` and shows `+12 Coins (Bounty Mark)` with the same `FloatingNumber` scene the damage numbers use: gold for coins, green for other gains, red for losses. Messages from the same frame (a payday's parts) stack upward. Lifetime, height and spacing are exports on the scene.

## The tab
`RunHistory.populate(container, character)` fills the **Run history** tab of both the character menu (`src/ui/CharacterUI.tscn`) and the shop (`src/Scenes/menu/ShopMenu.tscn`): newest stage first, one `Stage N` heading per stage, losses in red.

Tests: `test/Systems/test_run_history.gd`. Visual: set `STATS_TAB` to 2 in `test/tools/character_ui_preview.gd` and render it.
