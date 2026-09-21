# UI / Shop Portal

Purpose
- Provide the shop UI and portal flow between gameplay stages (spawned by StageManager when a boss is cleared).

Key scripts / scenes
- `Systems/ShopPortal.tscn` (portal scene referenced from `StageManager`)
- `Scenes/menu/starter_menu.gd` — starter selection UI that writes to `GlobalGameState`.
- `Scenes/menu/ShopMenu.tscn` + `Scenes/menu/shop_menu.gd` — shop UI; `ItemsList` is an `HBoxContainer` so offers are laid out in a horizontal row. Each generated offer has a 10% chance to be a weapon (`WEAPON_CHANCE`); buying a weapon equips it via `WeaponHolder.add_weapon`.
- `Scenes/menu/ShopItemCard.tscn` + `Scenes/menu/shop_item_card.gd` (`ShopItemCard`) — prepared card scene used for every entry in `ItemsList`, both pickup phase (`Take`/`Sell`) and shop phase (`Buy`/`Lock`). Layout: `IconHolder` on top, scrollable `InfoScroll` (`ScrollContainer`, horizontal scroll disabled) with `InfoLabel` below it showing `"\n\n".join(ItemTooltip.tooltip_lines(item))`, and two side-by-side buttons at the bottom. `ShopMenu` instantiates the card, calls `set_item_display(item)`, then wires the buttons; buy/lock/take/sell logic stays in `shop_menu.gd`.

Data flow
- Inputs: `StageManager` spawns portal and possibly connects shop menu signals.
- Processing: UI selection in starter menu writes `GlobalGameState.starting_weapons` and `starting_items` and starts the game scene; shop menu connects back to `StageManager` via signal to continue.
- Outputs: triggers `StageManager.start_new_loop()` when player accepts the shop choices.

Dependencies
- `GlobalGameState` autoload (assumed), `ShopMenu` scene, `StageManager` connections.

Known limitations / TODOs
- `starter_menu.gd` reads resources using DirAccess and assumes `.tres` layout; may fail if resources move.
- `GlobalGameState` implementation not found in repository (assumed autoload singleton).
