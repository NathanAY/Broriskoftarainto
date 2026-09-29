# UI / Shop Portal

Purpose
- Provide the shop UI and portal flow between gameplay stages (spawned by StageManager when a boss is cleared).

Key scripts / scenes
- `Systems/ShopPortal.tscn` (portal scene referenced from `StageManager`)
- `Scenes/menu/starter_menu.gd` — starter selection UI that writes to `GlobalGameState`.
- `Scenes/menu/ShopMenu.tscn` + `Scenes/menu/shop_menu.gd` — shop UI; `ItemsList` is an `HBoxContainer` so offers are laid out in a horizontal row. Each generated offer has a 10% chance to be a weapon (`WEAPON_CHANCE`); buying a weapon equips it via `WeaponHolder.add_weapon`. A `PriceAnalyzer` node (`Systems/Items/item_price_analyzer.gd`) prices every offer: stat item 1, buff/debuff 2, modifier 3, weapon 5; selling collected pickups grants 50% of the buy price (min 1). Buy/sell button labels show the price (e.g. `Buy (3)`, `Sell (+2)`).
- `Scenes/menu/ShopItemCard.tscn` + `Scenes/menu/shop_item_card.gd` (`ShopItemCard`) — prepared card scene used for every entry in `ItemsList`, both pickup phase (`Take`/`Sell`) and shop phase (`Buy`/`Lock`). Layout: a `Header` with a 76px `IconPlate` and the humanized item name, an `InfoScroll` (`ScrollContainer`, horizontal scroll disabled) holding a `RichTextLabel` body, a `PricePlate` and two side-by-side buttons. `ShopMenu` instantiates the card, calls `set_item_display(item)`, then wires the buttons; buy/lock/take/sell logic stays in `shop_menu.gd`.
- Card body text comes from `ItemTooltip.card_rows(item)` (in `ui/item_tooltip.gd`), the structured counterpart of `tooltip_lines()`. It returns `ItemCardRow` entries (`src/ui/item_card_row.gd`) tagged with a `Kind` (name / flavor / effect / buff / debuff / tradeoff / stat / weapon) and a `Tone` (neutral / positive / negative). `tooltip_lines()` is unchanged and still serves the hover tooltips; cards are the only consumer of `card_rows()`. Tone is derived from the *numeric* modifier value, not the rendered string, because a positive float renders as `5.0` and never carries a `+`.
- Card states, all driven from `shop_menu.gd`: `set_locked(bool)` switches the border to blue, `set_affordable(bool)` (fed by `ShopMenu._refresh_affordability()` after any money change) disables Buy and dims the card, `set_price(int)` fills the price plate and `set_money(float)` powers its tooltip. Weapon cards are the only category with their own border colour; all items share a neutral look. Purchased/taken/sold cards call `fade_out_and_free()` instead of `queue_free()` so the row animates closed.

Data flow
- Inputs: `StageManager` spawns portal and possibly connects shop menu signals.
- Processing: UI selection in starter menu writes `GlobalGameState.starting_weapons` and `starting_items` and starts the game scene; shop menu connects back to `StageManager` via signal to continue.
- Outputs: triggers `StageManager.start_new_loop()` when player accepts the shop choices.

Dependencies
- `GlobalGameState` autoload (assumed), `ShopMenu` scene, `StageManager` connections.

Known limitations / TODOs
- `starter_menu.gd` reads resources using DirAccess and assumes `.tres` layout; may fail if resources move.
- `GlobalGameState` implementation not found in repository (assumed autoload singleton).
