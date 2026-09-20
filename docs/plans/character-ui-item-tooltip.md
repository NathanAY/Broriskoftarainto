# Character UI Item Tooltip Plan

> Status: IMPLEMENTED (done). Do NOT implement this file.
> Open follow-up work lives in `docs/plans/item-tooltip-clarity.md` — implement that file when asked about tooltip clarity.

## Goal

Add a tooltip / hover card to `src/ui/CharacterUI.tscn` that appears when the mouse is over an entry in the Items or Weapons list. For now the card shows only simple key-value text:

```
name: Cactus
damage: 50
range: 500
```

Scope decision (confirmed with user): the tooltip applies to **both** the Items list and the Weapons list entries.

## Relevant code

- `src/ui/CharacterUI.tscn` — scene; root `CharacterUi` (Control) with `ItemsList` (VBoxContainer) and `WeaponsList` (GridContainer) populated at runtime.
- `src/ui/character_ui.gd` — builds rows dynamically:
  - `_update_items()` / `_on_item_added()` create one `HBoxContainer` per item (icon + label).
  - `_update_weapons()` creates one `VBoxContainer` per weapon (icon + name).
- `src/Systems/Items/Item.gd` — fields: `name`, `description`, `modifiers` (Dictionary, e.g. `{"damage": {"flat": 5.0}}`), `effect_scene` (Array[PackedScene]).
- `src/Systems/weapon/BaseWeapon.gd` — fields: `name`, `description`, `base_attack_speed`, `base_damage`, `weapon_range`, `modifiers`.

## Key-value mapping

### Weapons (`BaseWeapon` instance)

| Label   | Source field     |
| ------- | ---------------- |
| name    | `weapon.name`    |
| damage  | `weapon.base_damage` |
| range   | `weapon.weapon_range` |
| attack speed | `weapon.base_attack_speed` |
| description | `weapon.description` |
| + modifiers | flattened via shared helper (see Items) |

### Items (`Item` resource)

| Label   | Source field     |
| ------- | ---------------- |
| name    | `item.name` |
| description | `item.description` |
| modifiers | flattened: for each `stat` → for each modifier type (`flat`/`percent`/...) → `"<stat> <type>: <value>"` e.g. `damage flat: 5`, `area_size_multiplier percent: 30%` |
| effects | basename of each `effect_scene` resource path (e.g. `ExplosiveShotEffect`) |

Percent values are multiplied by 100 for display (`0.3` → `30%`).

## Implementation steps

### 1. Scene (`CharacterUI.tscn`)

- Add a `Tooltip` node as last child of root `CharacterUi` (so it renders on top):
  - `PanelContainer` `name = "Tooltip"`, `mouse_filter = IGNORE`, `visible = false`.
  - Child `RichTextLabel` with `fit_content = true`, default text empty, `mouse_filter = IGNORE`, autowrap off for now.

### 2. Script (`character_ui.gd`)

- Onready reference: `@onready var tooltip: PanelContainer = $Tooltip`, `@onready var tooltip_label: RichTextLabel = $Tooltip/...`.
- Helpers:
  - `_build_tooltip_lines(resource: Resource) -> PackedStringArray` — dispatches `is BaseWeapon` → weapon lines, `is Item` → item lines.
  - `_modifier_lines(modifiers: Dictionary) -> PackedStringArray` — shared flattening for items and weapons.
- Hover wiring, in row-creation loops (`_update_items`, `_on_item_added`, `_update_weapons`):
  - Set `row.mouse_filter = Control.MOUSE_FILTER_STOP`.
  - Set child labels/icon `mouse_filter = Control.MOUSE_FILTER_IGNORE` so the hover lands on the row.
  - `row.mouse_entered.connect(func(): _on_row_hovered(resource))`
  - `row.mouse_exited.connect(_on_row_exited)`
- Handlers:
  - `_on_row_hovered(resource)` — cache `_hovered_resource`, fill `tooltip_label.text = "\n".join(lines)`, `tooltip.visible = true`, position it.
  - `_on_row_exited()` — `_hovered_resource = null`, `tooltip.visible = false`.
  - `_process(_delta)` — while a row is hovered, follow `get_global_mouse_position()`.
- Positioning: `tooltip.global_position = get_global_mouse_position() + Vector2(16, 16)`; clamp so the card never leaves the screen (flip to left/above the cursor when overflowing, using `get_viewport_rect().size` and the tooltip size).

### 3. Test

New GDUnit4 suite `test/test_character_ui_tooltip.gd` (class extends `GdUnitTestSuite`):

- `test_weapon_tooltip_lines` — load a weapon `.tres` (e.g. `res://src/Resources/weapons/Pistol.tres`), assert lines contain `name:`, `damage:`, `range:`, `attack speed:`.
- `test_item_tooltip_lines` — load `res://src/Resources/items/PlusDamageItem.tres`, assert lines contain `name: Damage Amulet`, `damage flat: 5`.
- `test_hover_shows_and_hides_tooltip`:
  - Instantiate `CharacterUI.tscn` in a stub character node (Node with `Stats`, `ItemHolder`, `WeaponHolder`, `EventManager` children; onwer matches node paths used in `_ready`, and `GlobalGameState.current_character` is set to it).
  - Populate one item, verify tooltip shows on the row's `mouse_entered` (emit signal or call handler directly) and hides on `mouse_exited`.

Run: `.\run_tests_gdunit_custom.bat test_character_ui_tooltip.gd`

## Verification

1. Run the test suite above.
2. Manual: start a run, open the character menu, hover each item and weapon entry; the card follows the cursor, stays on-screen, and disappears on exit.

## Data caveat (out of scope unless requested)

Several weapon `.tres` files (`Fist.tres`, `Thorns.tres`, `Shotgun.tres`, `Knife.tres`) define `range = X`, but `BaseWeapon` declares `weapon_range`. The `range` key is ignored, so those weapons already use the default `weapon_range = 400` in game logic, and the tooltip will show `400`. Fixing the `.tres` files to `weapon_range` is a separate cleanup task.

## Out of scope (unless requested)

- Styled multi-row layout, icons, colors in the tooltip.
- Runtime-computed damage (base values only for now; can be extended with holder stats later).
- Tooltips on other menus (see "Extraction & shop extension" below — shop is now covered).

## Implementation notes (deviations applied)

- `RichTextLabel` was replaced with a plain `Label` in the `Tooltip` panel: `RichTextLabel` has a broken minimum width inside containers, which made the card only a few pixels wide. A `Label` (multi-line via `\n`, autowrap off) sizes correctly to the widest line.
- `_position_tooltip()` is a shared helper called both on hover (after `tooltip.reset_size()`) and each `_process` frame so the card follows the cursor and stays on screen.
- Test hover test builds a **typed `Character` stub** kept outside the scene tree (so `Character._ready` never runs and doesn't add hardcoded items or require the full character scene children). `GlobalGameState.current_character` is typed `Character`, so a plain `CharacterBody2D` stub caused a runtime type error.

## Extraction & shop extension (implemented)

The tooltip logic was extracted from `character_ui.gd` into a reusable component so other UIs (e.g. the shop's character info) can use it.

### New reusable files

- `src/ui/TooltipUi.tscn` — root `PanelContainer` (`visible = false`, `mouse_filter = IGNORE`) with a child `Label`. Hidden by default.
- `src/ui/tooltip_ui.gd` (`class_name TooltipUi`, extends `PanelContainer`):
  - `show_for(resource: Resource)` — fills the `Label` from `ItemTooltip.tooltip_lines(resource)` and shows/positions the card.
  - `hide_tooltip()` — hides the card.
  - `bind_to_row(row: Control, resource: Resource)` — sets `row.mouse_filter = MOUSE_FILTER_STOP`, recursively sets children to `MOUSE_FILTER_IGNORE` (hover lands on the row), connects `mouse_entered`/`mouse_exited`.
  - `_process(_delta)` — follows `get_global_mouse_position()`; `_position()` clamps so the card stays on screen (flips sides when overflowing viewport).
- `src/ui/item_tooltip.gd` (`class_name ItemTooltip`) — static, reusable line builders moved from `character_ui.gd`:
  - `tooltip_lines(resource) -> PackedStringArray` — dispatches `is BaseWeapon` / `is Item`.
  - `modifier_lines(modifiers: Dictionary) -> PackedStringArray` — shared flattening (percents multiplied by 100).

### Refactor of existing UIs

- `src/ui/character_ui.gd` / `CharacterUI.tscn`:
  - Replaced the inline `Tooltip` panel + label with `[node name="Tooltip" ... instance=ExtResource("TooltipUi.tscn")]`, `@onready var tooltip: TooltipUi = $Tooltip`.
  - Removed `_build_tooltip_lines`, `_modifier_lines`, `_on_row_hovered`, `_on_row_exited`, `_process`, `_position_tooltip`, `tooltip_label`.
  - `_update_weapons()` and `_build_item_row()` now call `tooltip.bind_to_row(row, resource)`; the old manual `mouse_filter` edits were removed (done inside `bind_to_row`).
- `src/Scenes/menu/ShopMenu.tscn` / `shop_menu.gd`:
  - Added `TooltipUi` instance as last child of the `CanvasLayer` root.
  - `@onready var tooltip: TooltipUi = $Tooltip`.
  - `_update_character_info()` now builds hoverable rows in the character info section: each collected item gets an `HBoxContainer` (name `Label`), each weapon gets a `VBoxContainer` (icon `TextureRect` + name `Label`); both are wired via `tooltip.bind_to_row(row, resource)`.

### Tests (`test/test_character_ui_tooltip.gd`)

- `test_weapon_tooltip_lines` / `test_item_tooltip_lines` — now assert through `ItemTooltip.tooltip_lines(...)`.
- `test_hover_shows_and_hides_tooltip` — same as before but asserts `ui.tooltip.visible` and `ui.tooltip.label.text`.
- `test_tooltip_ui_bind_to_row` — standalone `TooltipUi` bound to a generated row; hover shows, exit hides.
- `test_shop_menu_character_info_tooltips` — instantiates `ShopMenu.tscn` off a typed `Character` stub (item + weapon added), calls `_update_character_info()`, verifies one row per container and hover/exit behavior via `shop.tooltip`.

Result: 5/5 pass, 0 orphans, 0 errors in the GDUnit4 run.