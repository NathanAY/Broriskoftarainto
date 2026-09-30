# Characters — Data & Integration

This document explains the new character system (data, UI, and integration points) and how to add new characters.

## Overview
- Characters are data-driven Resources (`CharacterData`) stored as `.tres` files in `Resources/characters/`.
- Selection UI: `Scenes/menu/CharacterSelect.tscn` lets the player pick a character at the start of a run.
- The chosen character is stored in the autoload `GlobalGameState.starting_character` and applied when the player `Character` instance is created.

## Files of interest
- `Systems/characters/CharacterData.gd` — Resource class for characters.
- `Resources/characters/*.tres` — character definitions (examples: `Warrior.tres`, `Rogue.tres`, `Tank.tres`).
- `Scenes/menu/CharacterSelect.tscn` + `Scenes/menu/character_select.gd` — character selection UI: a top `DetailPanel` showing the selected character, above a compact card grid of 10 columns so 15+ characters still fit, with the `ScrollContainer` scrolling for extra rows. A shared `TooltipUi` node shows the same stats on card hover, so details are visible without selecting.
- `ui/CharacterDetailPanel.tscn` + `ui/character_detail_panel.gd` (`class_name CharacterDetailPanel`) — the top panel. It inherits the shared `ui/ItemDisplayPanel.tscn` scene (the same base as `ShopItemCard` and `TooltipUi`) at a larger scale, so the character screen and the shop cannot drift apart visually. It adds nothing of its own beyond content: `set_character_display(CharacterData)` is an alias for `set_resource()`.
- `Scenes/menu/CharacterCard.tscn` + `Scenes/menu/character_card.gd` (`class_name CharacterCard`) — compact grid entry: icon + name only, whole card clickable (`selected` signal via `gui_input`/`select()`). The scene *inherits* `ui/IconCard.tscn` (`class_name IconCard`), the shared fixed-size tile, and the script adds only click handling and the selection highlight, so the character grid and the character menu's Items grid can never drift apart. It is not an `ItemDisplayPanel` subclass (it has no body) but borrows that class's palette via `ItemDisplayPanel.make_panel_stylebox()`, so the grid reads as part of the same UI. Selection is a gold border + gold name rather than a `modulate` tint, because tinting the whole card also recolours the character's own art.
- `ui/character_tooltip.gd` (`class_name CharacterTooltip`) — two builders over the same data:
  - `tooltip_lines(CharacterData)` — the original flat text (`name:`, `base <stat>:`, `starting item:` ...). Kept byte-identical; it is what any plain-text consumer reads.
  - `card_rows(CharacterData)` — the structured counterpart returning `ItemCardRow`s (`NAME` / `FLAVOR` / `STAT` / `EFFECT` / `GEAR`) with a tone each, so the detail panel and hover tooltip can colour each line. `_effect_head()` is shared by both builders so their wording cannot drift.
- `Scripts/autoload/global_game_state.gd` — holds `starting_character` (path or Resource).
- `Systems/characters/CharacterInitializer.gd` — applies character data to the `Stats` node on character spawn.
- `Systems/Character.tscn` — now contains a `CharacterInitializer` Node (instance) so application is automatic.

## CharacterData format
- `display_name` (String): shown in UI.
- `description` (String): short description.
- `base_stats` (Dictionary): the archetype's own stat block — the values that differ from the default `Stats` (`health`, `movement_speed`, `damage`, `attack_speed`, ...). Each key calls `Stats.set_base_stat(stat_name, value)`. `movement_speed` is in meters per second (200 px = 1 m). **Never** put a stat here that needs a modifier to do anything (e.g. `armor`) — see below.
- `modifiers` (Array): everything else that makes this character different, as one flat list of two entry kinds applied in order:
  - **Dictionary** — a value, passed to `Stats.add_modifier` as-is: `{"armor": {"flat": 4}}`, `{"damage": {"percent": 0.2}}`, `{"attack_speed": {"percent": 0.2}, "condition": {...}}`.
  - **PackedScene** — a behavior: a modifier scene from `Systems/Items/modifiers/*.tscn`, instantiated and wired to the character by `BaseModifier.attach` (e.g. `ArmorModifier.tscn`).
- `starting_items` (Array[Item]): `Item` resources equipped at spawn via the `ItemHolder`.
- `starting_weapons` (Array[BaseWeapon]): `BaseWeapon` resources (e.g. `res://src/Resources/weapons/Fist.tres`) equipped at spawn via the `WeaponHolder`.

Example (pseudo):
```
display_name = "Rogue"
base_stats = {"health": 35.0, "movement_speed": 0.35, "damage": 0.8}
modifiers = [{"armor": {"flat": 4}}, <ArmorModifier.tscn>, {"attack_speed": {"percent": 0.2}}]
```

## How selection and application works
1. Player picks a card in `CharacterSelect` (first character is pre-selected so the detail panel is never empty); the detail panel shows the full `CharacterTooltip` stats. On confirm the script sets `GlobalGameState.starting_character = "res://src/Resources/characters/Rogue.tres"` (string path).
2. The flow continues to `StarterMenu` to choose weapons/items; those values are also saved in `GlobalGameState`.
3. When the game scene creates the player `Character` (instancing `Systems/Character.tscn`), the `CharacterInitializer` node reads `GlobalGameState.starting_character`, loads the resource, and:
   - Calls `Stats.set_base_stat` for each entry in `base_stats` (overwrites base values).
   - Walks `modifiers` and dispatches each entry **by type** (`_apply_modifier`): a Dictionary goes to `Stats.add_modifier`, a PackedScene goes to `BaseModifier.attach` (instantiate + `attachEventManager` + one active stack, under the `ItemHolder`).
   - Calls `ItemHolder.add_item` for each entry in `starting_items`.
   - Calls `WeaponHolder.add_weapon` (deferred until the ready pass finishes) for each entry in `starting_weapons`.

This keeps character data separate from player logic and allows easy addition of new characters.

## One way to give a character armor (or any stat-driven behavior)
A stat on its own is inert: `armor` is just a number, and the
`10 / (10 + armor)` damage reduction lives in `ArmorModifier`'s
`before_take_damage` handler. Nothing subscribes to that event unless an
`ArmorModifier` node is attached, which is why a character needs **both** halves
of the declaration — and why both live in the same `modifiers` list:

```
modifiers = [{"armor": {"flat": 14}}, <ArmorModifier.tscn>]   # Wildling
modifiers = [{"armor": {"flat": 4}},  <ArmorModifier.tscn>]   # Brawler
```

Rules that keep this the only correct way:
- A behavior that needs a stat always declares the value as a Dictionary in
  `modifiers` and the listener as a modifier scene in the same list. Never a
  bare `armor` key in `base_stats` — that is the archetype stat block only.
- `CharacterInitializer` names no stat and no modifier. Adding a brand new
  behavior to a character is a data edit: drop that modifier's scene into
  `modifiers`. The same is true for items (`ItemHolder` goes through the shared
  `BaseModifier.instantiate_attached`).
- A modifier scene entry that is not a `BaseModifier`, or an entry of any other
  type, logs a warning instead of failing silently.
- Armor items picked up later bring their own `ArmorModifier` instance; the
  handler's "strongest armor source wins" guard (`ctx.armor_applied`) keeps a hit
  reduced exactly once no matter how many armor sources are live.

`CharacterTooltip` renders both halves: stat dicts as `armor flat: 4` and
modifier scenes as `effect: Armor — ... (Triggers on before take damage)`.

Note that `armor: {flat: 4}` and `ArmorModifier.armor_per_stack` are two
different numbers: the first is this character's baseline armor, the second is
what each held stack adds on top. Both show up in the panel, which is correct
but reads as a near-duplicate at a glance.

## How a character's stats are coloured
`base_stats` are **absolute** values that overwrite the `Stats` defaults, not
gains — a Ranger's `health: 35.0` replaces the default 10. So the panel shows
the absolute number and uses colour to say whether it beats the default:
- `Systems/stats/stats.gd` exposes `const DEFAULT_STATS` plus
  `static func default_stat(name)`, which is the single source of truth for the
  baseline. `@export var stats` is initialised from it, so there is one table,
  not two that can disagree.
- `CharacterTooltip._tone_vs_default()` compares each value against that default:
  above → green, below → red, equal → neutral.

Entries in `modifiers` are real deltas, so those keep the explicit `+`/`-` and
derive their tone from the value itself — same rule the shop cards use.

## Adding a new character
1. Create a new resource file in `Resources/characters/` using the `CharacterData` script as the resource type (or copy an existing `.tres`).
2. Set `display_name`, `description`, and `base_stats` (archetype stats only). Put everything else in `modifiers` — stat dicts and/or modifier scenes.
3. No code changes needed — `CharacterSelect` scans the folder and will display the new entry.

## Extensibility ideas
- Optional: merge a character's `starting_weapons`/`starting_items` into `GlobalGameState` on confirm so they still appear in the StarterMenu loadout; currently they are applied directly at spawn by `CharacterInitializer`.
