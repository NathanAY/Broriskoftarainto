# Buff / Debuff UI Remake

> Status: SHIPPED. Everything below was implemented; current truth is
> `docs/systems/items.md` (the buff data), `docs/systems/ui_shop_portal.md` (the
> tiles and the tooltip) and `docs/systems/debug_scenarios.md` (the scenario that
> fills the debuff row). Read those, not this.
>
> Four decisions on this page did not survive implementation, and the reason is
> worth keeping:
>
> - **The tooltip is a sibling of the rows, not a third row in the `VBox`.** It
>   positions itself against the mouse, so inside the container it was laid out
>   and reserved vertical space it never used.
> - **A buff's total is `scaled_modifiers()`, not `total_modifiers()`.** A `Buff`
>   applies the *same* payload once per stack, so `+0.5 x 3` really does move the
>   stat by 1.5. Summing a stack set happens only on the debuff side, where each
>   instance genuinely carries its own copy.
> - **`Debuff` starts its timer from `_ready()`, not from `setup()`.** It is now
>   parented to itself rather than to the target, and `DebuffSource` calls
>   `setup()` *before* `add_child()`, so a timer started there never runs.
> - **`clear()` frees tiles immediately rather than queueing them.** A queued tile
>   is still a child for the rest of the frame, so a character swap left the
>   previous character's buffs on screen for one frame.
>
> The original text of the plan follows.

## Goal

Replace the text prototype in `src/ui/BuffUi.tscn` + `src/ui/buff_ui.gd` with a
grid of icon tiles that matches the game's existing card art:

- **Row 1 (top of screen): buffs.** **Row 2: debuffs.** Both centred, both always
  in the same place so a glance is enough.
- Every tile carries an **icon**, a **stack count** and a **duration arc**.
- Everything else — the full stat change, the trigger, the stat's own
  explanation — is **hover-only**, in the shared `TooltipUi`.
- One scene, instanced by both existing hosts: the in-game HUD
  (`src/ui/PlayerUI.tscn`) and the pause-menu character screen
  (`src/ui/CharacterUI.tscn`).

Non-goals: new buff art, balance changes, new gameplay. The plan changes only
what the UI can read and how it draws it, plus the small data additions needed to
give a buff an identity.

## Settled decisions

| # | Question | Decision |
|---|---|---|
| Q1 | What is the second row? | Debuffs **on the player**. Reachable today: `DebuffSource` spawns its `Debuff` onto `ctx.target`, so an enemy carrying a debuff item fires `on_debuff_added` on the player's own bus. Nothing currently *does* that — enemies carry no items (`src/Scripts/Enemy.gd:31` is commented out) — so step 6 adds a fixture and a note rather than shipping a dead row. |
| Q2 | Tile density | Icon + stack count + duration arc. Detail is hover-only. |
| Q3 | Where does it live? | One `BuffUi.tscn`, instanced by both `src/ui/PlayerUI.tscn` and `src/ui/CharacterUI.tscn`, as today. |
| Q4 | Tile identity | The live effect node, not a stringified modifier dict. `ItemHolder._find_effect_node` already collapses duplicate effect scenes into one node (`src/Systems/Items/item_holder.gd:125`), so one `Buff` node *is* one buff and its `_active_stacks` is the count. |
| Q5 | Debuff identity | Needs a new back-reference: `Debuff` records the `DebuffSource` that spawned it, so debuffs of one kind group into one tile with a summed total. |
| Q6 | Colour channel | Border, never the icon. Buff tile border `COLOR_POSITIVE`, debuff tile border `COLOR_NEGATIVE`, gold `HOVER_BORDER` on hover. |
| Q7 | Tooltip host | `BuffUi` instantiates its own `TooltipUi` child. `CharacterUI` keeps its own for the gear grid; only one is ever visible, because each hides on `mouse_exited`. |

## Current behavior (evidence)

### The widget

- `src/ui/BuffUi.tscn` — a `Control` with two unstyled `PanelContainer`s, each
  holding an `HBoxContainer`. No stylebox, no icon, no hover, no size.
- `src/ui/buff_ui.gd:43-44` — one bare `Label` per buff, created in code.
- `src/ui/buff_ui.gd:127` — the whole readout is
  `lbl.text = "%s %s (%.1fs)" % [mods_text, stack_text, remaining]`, so a haste
  buff renders as `Attack_speed 0.5 x3 (2.4s)`.
- `src/ui/buff_ui.gd:102-106` — `_process` re-formats **every** label **every
  frame**. Ten tiles means ten `%.1f` string builds per frame for text that
  changes visibly maybe twice a second.
- `src/ui/PlayerUI.tscn:41-48` — placed at `offset_left = 200`, left-anchored,
  i.e. not centred and not below the stage timer at `src/ui/PlayerUI.tscn:50`.
- `src/ui/PlayerUI.tscn:58` — the `StageTimer` label with placeholder text
  `Sthgfhfghsfh sdf h 45`, still in the scene.

### Bugs in the current script, all fixed by the rewrite

| # | Bug | Where |
|---|---|---|
| B1 | `_clear()` frees only the buff row; debuff tiles survive a character swap | `src/ui/buff_ui.gd:186-189` |
| B2 | `_update_debuff_label()` is dead code and reads `active_buffs[id]["debuffs"]` — a key that does not exist | `src/ui/buff_ui.gd:160-182` |
| B3 | The debuff duration lookup **always fails**: it scans the `Debuff`'s children for a `Timer`, but `Debuff` parents its timer to the *target* | `src/ui/buff_ui.gd:152` vs `src/Systems/Items/Buffs/debuff_instance.gd:31` |
| B4 | Only the debuff path filters freed instances; the buff path can hold a freed `Buff` | `src/ui/buff_ui.gd:49-65` |
| B5 | `_get_buff_id()` stringifies the modifier dict, so two distinct buffs with identical modifiers collapse into one tile, and a buff whose modifiers change orphans its entry | `src/ui/buff_ui.gd:191-200` |
| B6 | `set_character()` calls `_ready()` again and re-subscribes, so every listener lands twice | `src/ui/buff_ui.gd:14` |

### The data model, and what is missing

`src/Systems/Items/Buffs/buff.gd`:

| Field | Present | Note |
|---|---|---|
| `trigger_event` | yes | `on_hit` by default |
| `duration` | yes | seconds |
| `max_stacks` | yes | FIFO eviction at the cap, `buff.gd:37-40` |
| `modifiers` | yes | the stat dictionary; the **only** source of an icon |
| `display_name` | **no** | |
| `tooltip_text` | **no** | |
| remaining time | **not exposed** | `_active_stacks` is private; each stack's `Timer` is a child of the `Buff`, so the data exists |

`src/Systems/Items/Buffs/debuff_source.gd` — `trigger_event`, `duration`,
`modifiers`, no display fields, **no `max_stacks`** (a debuff does not stack at
the source; every trigger spawns a separate `Debuff` node).

`src/Systems/Items/Buffs/debuff_instance.gd` — every field is a plain `var`, no
`@export`. `setup()` takes `(holder, target, modifiers, duration)` and the
`Debuff` **never learns which `DebuffSource` made it**. It also parents its
`Timer` to `target` and keeps no reference to it, which is what breaks B3.

### Icon art

There is no buff/debuff icon set, and `src/Assets/modifiers/` has no
`buff.png` / `debuffsource.png`. The one working path is
`Stats.get_stat_icon(stat_name)` (`src/Systems/stats/stats.gd:189-193`), driven
off the keys of the `modifiers` dict, which is exactly what
`ItemTooltip._append_stat_rows` already does for card rows
(`src/ui/item_tooltip.gd:164`). `_default.png` covers a stat with no art.

### Style to reuse, not reinvent

| Need | Reuse | Where |
|---|---|---|
| Palette, panel fill/border/radius/shadow | `ItemDisplayPanel` constants + `make_panel_stylebox()` | `src/ui/item_display_panel.gd:19-28`, `:213-221` |
| Tone → colour, card body BBCode | `ItemDisplayPanel.tone_color()` / `build_bbcode()` | `src/ui/item_display_panel.gd:157-196` |
| Humanized stat names, trigger text, stat hints | `ItemTooltip.humanize_effect_name()`, `humanize_trigger()`, `stat_hint()` | `src/ui/item_tooltip.gd:38-39`, `:565`, `:589` |
| Per-stat rows with tone and icon | `ItemTooltip.stat_rows()` | `src/ui/item_tooltip.gd:139` |
| Multi-icon composition | `ItemIconGenerator._create_composite_texture()` | `src/ui/ItemIconGenerator.gd:37-65` |
| Click-through recursion for the icon | `ItemDisplayPanel.set_mouse_ignore()` | `src/ui/item_display_panel.gd:201-205` |
| Hover tooltip, mouse-follow, edge-flip | `TooltipUi` | `src/ui/tooltip_ui.gd` |
| A fixed-size icon tile with a scale knob | `IconCard` as the pattern | `src/ui/icon_card.gd` |

Per `docs/visual_style.md:114`, colour signals buff/debuff through **border and
label**, never by tinting the icon art.

## Target design

### Scene tree

```
BuffUi (Control, top-wide, script BuffUi)
└── Margin (MarginContainer, 12 / 28 / 12 / 8)
    └── VBox (VBoxContainer, separation 6)
        ├── BuffsRow  (HBoxContainer, alignment 1 CENTER)
        ├── DebuffsRow (HBoxContainer, alignment 1 CENTER)
        └── Tooltip    (instance of src/ui/TooltipUi.tscn)
```

- `offset_top = 28` clears the `StageTimer` (`src/ui/PlayerUI.tscn:50-58`, 22px
  tall) instead of overlapping it.
- A row with no tiles is `visible = false`, so an empty debuff row reserves no
  gap. Both rows are always present in the tree so the layout never shifts.
- Anchored across the full width with `alignment = 1` (`ALIGNMENT_CENTER`),
  matching the centred offer row in the shop
  (`src/Scenes/menu/shop_menu.gd:9`).

The grid is **not** wrapped in a `ScrollContainer`. The padding rule in
`test/ui/test_icon_card.gd:169` exists because a tile's `shadow_size` shadow is
drawn outside its own rect and a `ScrollContainer` clips it — a HUD row is not
inside one, so that guard does not apply here and must not be copied.

### The tile

New scene `src/ui/BuffTile.tscn` + script `src/ui/buff_tile.gd`, `class_name
BuffTile`. Base size 32x32; every dimension a constant derived from `TILE_SIZE`,
as `IconCard` does.

| Part | Node | Spec |
|---|---|---|
| Plate | `PanelContainer` | `ItemDisplayPanel.make_panel_stylebox(border)` — fill `#262932`, radius 8, shadow 6. Border 2px: `COLOR_POSITIVE` on the buff row, `COLOR_NEGATIVE` on the debuff row, `HOVER_BORDER` gold on hover. |
| Icon | `Control` holding one `TextureRect` | `Stats.get_stat_icon(primary_stat)`, `expand_mode = EXPAND_IGNORE_SIZE`, `stretch_mode = STRETCH_KEEP_ASPECT_CENTERED`. 24x24 inside the 32x32 plate. Two or more stats composite through `ItemIconGenerator`. Made click-through so the tile, not the art, owns the hover. |
| Stack badge | `Label`, bottom-right | Font 10, `COLOR_HEADING` gold, on the icon-plate style from `src/Scenes/menu/ShopItemCard.tscn` plate so it reads over any art. **Hidden at 1 stack** — a `1` on every tile is noise, and `IconCard` already sets the precedent of hiding a redundant readout. |
| Duration arc | `Control` with `_draw()` | `draw_arc()` from -90 degrees, clockwise, sweep = `remaining / duration`, 2px, over the icon. Turns `COLOR_NEGATIVE` under 20% remaining so an expiring buff is visible without reading the number. Hidden entirely for a buff with no running timer. |
| Tooltip binding | — | `tooltip.bind_to_row(tile, ...)` so the whole opaque plate is the hover target. |

**The arc is the first `CanvasItem._draw()` in the UI layer.** The only `draw_*`
calls in `src/` today are in `src/Scripts/explosion.gd:34`. If that proves
awkward to test, the fallback is a shrinking `ColorRect` bar under the icon,
which needs no `_draw` and reads almost as well at 32px. Decide during step 4,
not before.

### The tooltip

`TooltipUi` is a `Resource`-driven widget (`src/ui/tooltip_ui.gd:30`), and a
`Buff` is a `Node`, so `show_for()` / `bind_to_row()` cannot take one. Add a
`show_buff()` path modelled on `show_text()` (`src/ui/tooltip_ui.gd:43`), plus
`bind_to_row_buff()`, both reusing `_bind_hover()`.

| Slot | Content | Source |
|---|---|---|
| `NameLabel` | `display_name` if set, else the humanized primary stat (`"Movement Speed"`) | new export, else `ItemTooltip.humanize_effect_name()` |
| `TypeBadge` | `BUFF` / `DEBUFF`, gold, uppercase | row |
| Icon plate | the same stat icon, 36x36 | `TooltipUi.HINT_ICON_SIZE` |
| Body | one toned row per stat, **at the summed total**, not per stack | `ItemTooltip.stat_rows()` fed with summed values |
| Body | `3 stacks (max 10)` | `Buff.max_stacks` |
| Body | `2.4s of 3.0s left` | remaining / duration |
| Body | `Triggers on hit` | `ItemTooltip.humanize_trigger()` |
| Body | the stat's own explanation | `ItemTooltip.stat_hint()` |

`TooltipUi` already calls `hug_body_content()` (`src/ui/tooltip_ui.gd:27`) and
`InfoLabel` already carries a `custom_minimum_size.x` of 164
(`src/ui/TooltipUi.tscn:56`), so the self-sizing wrap trap is already handled —
as long as `show_buff()` goes through `set_resource`-style plumbing rather than
setting `label.text` directly.

### One deliberate contradiction with the shop

`docs/systems/ui_shop_portal.md:15` records a settled decision: on a **shop
card**, a debuff payload renders **green**, because a debuff lands on the enemy
and is a gain to the player. In this widget a debuff lands on **you**, so it
renders **red**. Same word, opposite meaning, opposite colour. That is correct
and it must be called out in `docs/systems/ui_shop_portal.md` when this lands, or
the next reader will "fix" one of the two.

## Steps

Each step follows `AGENTS.md`: read, write the test, run it, read the failure,
fix, run again.

### Step 1 — give a buff an identity (data)

- `src/Systems/Items/Buffs/buff.gd`: add `@export var display_name: String` and
  `@export var tooltip_text: String`. Add read-only `stack_count()` and
  `remaining_time()` so the UI stops reaching into `_active_stacks`.
- `src/Systems/Items/Buffs/debuff_source.gd`: the same two exports.
- `src/Systems/Items/Buffs/debuff_instance.gd`: add `source: Node` (the
  `DebuffSource`), `timer: Timer` (the one it already creates), and pass
  `display_name` / `tooltip_text` through `setup()`. Parent the timer to
  **itself** instead of `target`, and free it from `_on_expire` — this is what
  B3 is.
- `src/Systems/Items/Buffs/debuff_source.gd`: pass `self` into `setup()`.
- `src/Scripts/event_contract.gd`: **no change**. All four events already carry
  everything needed (`buff` / `holder` / `id`, `debuff` / `holder` / `target`) —
  named explicitly so nobody widens a schema that is already sufficient.

This mirrors the display contract `docs/archive/item-tooltip-clarity.md`
established on `BaseModifier`; extending it to buffs is the same shape, not a new
idea.

### Step 2 — the presentation model

New `src/ui/buff_entry.gd`, `class_name BuffEntry`, a `RefCounted` mirroring
`src/ui/item_card_row.gd`: one active effect's worth of display state — the
grouping key, display name, tone, the summed modifier dictionary, stack count,
max stacks, remaining time, duration, trigger. Pure data plus two statics:

- `BuffEntry.total_modifiers(entries) -> Dictionary` — sums a stack set so the
  tooltip shows what the stat actually moved by, not one stack's worth.
- `BuffEntry.primary_stat(modifiers) -> String` — the icon key, first key in
  sorted order so it is stable between frames.

Keeping this out of the `Control` means every formatting rule is testable
without a scene tree.

### Step 3 — the tile

New `src/ui/BuffTile.tscn` + `src/ui/buff_tile.gd`. `set_entry(entry)` fills
icon, badge, arc and tooltip binding. `tick()` is the only per-frame work and it
only calls `queue_redraw()`.

### Step 4 — the grid

Rewrite `src/ui/buff_ui.gd` and `src/ui/BuffUi.tscn` to the tree above. Key tiles
by the effect node instance (Q4), not by a modifier string (fixes B5). Debuffs
group by `Debuff.source` (Q5). `_process` walks live tiles and calls `tick()` —
no string building per frame. Delete B1, B2, B6 outright.

Reposition the `BuffUi` instance in `src/ui/PlayerUI.tscn` to top-centre below
the stage timer, matching `src/ui/CharacterUI.tscn:26-33`.

### Step 5 — hosts and preview

- `src/ui/PlayerUI.tscn`: reposition. Replace the `StageTimer` placeholder text
  (`Sthgfhfghsfh sdf h 45`) with something honest or empty it.
- `src/ui/CharacterUI.tscn`: no structural change — it already instances the
  scene.
- New `test/tools/buff_ui_preview.gd` + `test/tools/buff_ui_preview.tscn`, on
  the pattern of `test/tools/shop_ui_preview.gd`. The character stub is copied
  from `test/tools/character_ui_preview.gd:44-71`. It pins: a 3-stack buff, a
  1-stack buff, a multi-stat buff (composite icon), and a debuff applied by
  directly calling `Debuff.setup()` on the character and emitting
  `on_debuff_added` — deterministic, no damage pipeline, no RNG. Then:
  `.\run_scene_shot.bat res://test/tools/buff_ui_preview.tscn`.

### Step 6 — make the second row reachable

The debuff row is correct code over an empty world until an enemy carries a
debuff item. Options, in order of cost:

1. **Leave it, and document it.** `docs/systems/items.md` gets a line saying the
   row fills when an enemy carries a `DebuffSource` item, and
   `src/Scripts/Enemy.gd:31` stays commented. Honest, zero risk, but the row is
   never seen in a real run.
2. **A debug scenario.** `test/scenarios/debug_scenario_menu.gd` gains a
   scenario whose `ScenarioSetup` gives one enemy a `MinusArmorOnHitDebuff`
   item. Follows `docs/systems/debug_scenarios.md`; keeps the change off the
   live enemy path.

Recommended: 2. Do **not** give every enemy a debuff item — that is a balance
change, and `docs/systems/balance.md` governs it.

## Tests

New `test/ui/test_buff_ui.gd`, covering the behaviours the current script gets
wrong and the new ones it has:

| Test | Asserts |
|---|---|
| `test_buff_event_adds_one_tile_to_row_one` | `on_buff_added` → one child of `BuffsRow`, none in `DebuffsRow` |
| `test_two_triggers_make_one_tile_with_a_stack_badge` | two `on_buff_added` on the same `Buff` node → one tile, badge text `2` |
| `test_two_distinct_buffs_with_equal_modifiers_get_two_tiles` | regression on B5 — the old modifier-string key merged them |
| `test_debuff_event_adds_one_tile_to_row_two` | `on_debuff_added` → a tile in `DebuffsRow`, and it is absent from `BuffsRow` |
| `test_two_debuffs_from_one_source_group_and_sum` | two `Debuff` nodes, same `source` → one tile, badge `2`, summed total in the tooltip |
| `test_debuff_timer_counts_down` | regression on B3 — the arc fraction falls as the debuff's own timer runs |
| `test_removing_the_last_stack_removes_the_tile` | tile gone, and `BuffsRow` still holds no freed node |
| `test_empty_row_is_hidden` | a row with no tiles is not visible |
| `test_tooltip_reports_the_summed_stat_change` | 3 stacks of `attack_speed +0.5` reads `+1.5`, not `+0.5` |
| `test_tooltip_names_the_trigger_and_the_stat` | `Triggers on hit`, and `ItemTooltip.stat_hint()` text present |
| `test_set_character_does_not_double_subscribe` | regression on B6 — one add after a rebind yields exactly one tile |
| `test_clear_frees_both_rows` | regression on B1 |

Plus pure-logic tests for `BuffEntry` (summing, primary-stat stability) that need
no tree, and they can live in the same suite.

Run with `.\run_tests_gdunit_custom.bat buff_ui`, then the full
`.\run_tests_gdunit.bat` — `TooltipUi` is shared with `CharacterUI` and
`ShopMenu`, so a change to the tooltip is a change to three screens.

## Docs to update when it lands

| Doc | Change |
|---|---|
| `docs/systems/items.md` | the new buff display fields, `Debuff.timer` / `Debuff.source`, and what the debuff row shows |
| `docs/systems/ui_shop_portal.md` | the new tile, and the buff-green / debuff-red contrast with the shop card |
| `docs/visual_style.md` | the tile as a UI asset class; note the first `CanvasItem._draw()` in the UI layer |
| `docs/systems/event_manager.md` | unchanged — say so explicitly rather than leaving a reader to wonder |

`docs/ai_overview.md` is **not** touched: `test/test_doc_links.gd:171` asserts it
does not reference `docs/plans/`.

When the work ships, move this file to `docs/archive/` and add the row to
`docs/archive/README.md`, per that directory's convention.

## Verification

1. `.\run_tests_gdunit_custom.bat buff_ui` — new suite green.
2. `.\run_tests_gdunit.bat` — no regressions; `TooltipUi` has three consumers.
3. `.\run_tests_gdunit_custom.bat doc_links` — green, and the allowlist entries
   for the new files are deleted in the same change.
4. Read `.gdunit.log`. The baseline is 6 warnings / 20 errors, all expected
   (`AGENTS.md`); anything else came from this change.
5. `.\run_scene_shot.bat res://test/tools/buff_ui_preview.tscn` — both rows, the
   stack badge, the arc, and the composite icon all legible at 32px.
6. Manual: pick up a buff item mid-run and confirm the tile appears, stacks, and
   the arc drains; hover it and confirm the tooltip matches the tile.

## Risks

| Risk | Mitigation |
|---|---|
| The arc's `_draw()` is untested territory in the UI layer | the shrinking-bar fallback is a one-node change, decided in step 4 |
| `Debuff` re-parenting its timer is a behaviour change, not just plumbing | it is the only way to read remaining time; step 1's test asserts the countdown, and no other code reads those timers |
| Adding display exports to `Buff` touches every buff `.tres` | the fields default to empty and fall back to the humanized stat name, so no `.tres` must be edited |
| The shared `TooltipUi` is used by three screens | full-suite run, plus the character-menu and shop tooltips are already covered by `test/ui/test_character_ui_tooltip.gd` |
| The debuff row ships empty | step 6 makes it reachable via a debug scenario rather than by changing enemy balance |