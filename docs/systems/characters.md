# Characters — Data & Integration

This document explains the new character system (data, UI, and integration points) and how to add new characters.

## Overview
- Characters are data-driven Resources (`CharacterData`). Each one lives in its own folder under `src/Assets/character/`, named `<Id>.tres` next to its art — e.g. `src/Assets/character/ranger/Ranger.tres`.
- The six characters today are **Brawler, Multitasker, Ranger, Soldier, Tycoon, Wildling**. Multitasker is the default (`GlobalGameState.DEFAULT_CHARACTER`). Each owns a distinct attack archetype: Multitasker (Fist, baseline), Brawler (Fist melee bruiser), Ranger (Pistol + Spread, glass-cannon gunner), Soldier (Shotgun, armored mid-range), Wildling (Thorns contact, berserker), Tycoon (SMG, the economy character: starting stock, less coin per kill, and a Credit Line that lets him spend into debt — see `docs/systems/economy.md`). The power budget for the roster lives in `docs/systems/balance.md` §5.
- Selection UI: `src/Scenes/menu/CharacterSelect.tscn` lets the player pick a character at the start of a run. It scans `src/Assets/character/` and picks up any new `.tres` without a code change.
- The chosen character is stored in the autoload `GlobalGameState.starting_character` and applied when the player `Character` instance is created.

## Files of interest
- `src/Systems/characters/CharacterData.gd` — Resource class for characters.
- `src/Systems/characters/CharacterSprites.gd` — composes a character from its art parts for both the in-world rig and the UI portrait (see "Character art" below).
- `src/Assets/character/<id>/<Id>.tres` — character definitions.
- `src/Scenes/menu/CharacterSelect.tscn` + `src/Scenes/menu/character_select.gd` — character selection UI: a top `DetailPanel` showing the selected character, above a compact card grid with a `ScrollContainer` for extra rows, so a roster well past the current five still fits. A shared `TooltipUi` node shows the same stats on card hover, so details are visible without selecting.
- `src/ui/CharacterDetailPanel.tscn` + `src/ui/character_detail_panel.gd` (`class_name CharacterDetailPanel`) — the top panel. It inherits the shared `src/ui/ItemDisplayPanel.tscn` scene (the same base as `ShopItemCard` and `TooltipUi`) at a larger scale, so the character screen and the shop cannot drift apart visually. It adds nothing of its own beyond content: `set_character_display(CharacterData)` is an alias for `set_resource()`.
- `src/Scenes/menu/CharacterCard.tscn` + `src/Scenes/menu/character_card.gd` (`class_name CharacterCard`) — compact grid entry: icon + name only, whole card clickable (`selected` signal via `gui_input`/`select()`). The scene *inherits* `src/ui/IconCard.tscn` (`class_name IconCard`), the shared fixed-size tile, and the script adds only click handling and the selection highlight, so the character grid and the character menu's Items grid can never drift apart. It is not an `ItemDisplayPanel` subclass (it has no body) but borrows that class's palette via `ItemDisplayPanel.make_panel_stylebox()`, so the grid reads as part of the same UI. Selection is a gold border + gold name rather than a `modulate` tint, because tinting the whole card also recolours the character's own art.
- `src/ui/character_tooltip.gd` (`class_name CharacterTooltip`) — two builders over the same data:
  - `tooltip_lines(CharacterData)` — the original flat text (`name:`, `base <stat>:`, `starting item:` ...). Kept byte-identical; it is what any plain-text consumer reads.
  - `card_rows(CharacterData)` — the structured counterpart returning `ItemCardRow`s (`NAME` / `FLAVOR` / `STAT` / `EFFECT` / `GEAR`) with a tone each, so the detail panel and hover tooltip can colour each line. `_effect_head()` is shared by both builders so their wording cannot drift.
- `src/Scripts/autoload/global_game_state.gd` — holds `starting_character` (path or Resource).
- `src/Systems/characters/CharacterInitializer.gd` — applies character data to the `Stats` node on character spawn.
- `src/Systems/Character.tscn` — now contains a `CharacterInitializer` Node (instance) so application is automatic.

## CharacterData format
- `display_name` (String): shown in UI.
- `description` (String): short description.
- `base_stats` (Dictionary): the archetype's own stat block — the values that differ from the default `Stats` (`health`, `movement_speed`, `damage`, `attack_speed`, ...). Each key calls `Stats.set_base_stat(stat_name, value)`. `movement_speed` is in meters per second (`PIXELS_PER_METER` = 300, so base 1.0 m/s = 300 px/s). `armor` is a plain stat too and goes here — see below.
- `modifiers` (Array): everything else that makes this character different, as one flat list of two entry kinds applied in order:
  - **Dictionary** — a value, passed to `Stats.add_modifier` as-is: `{"damage": {"percent": 0.2}}`, `{"attack_speed": {"percent": 0.2}, "condition": {...}}`.
  - **PackedScene** — a behavior: a modifier scene from `Systems/Items/modifiers/*.tscn`, instantiated and wired to the character by `BaseModifier.attach` (e.g. `FlatRegenModifier.tscn`).
- `starting_items` (Array[Item]): `Item` resources equipped at spawn via the `ItemHolder`.
- `starting_weapons` (Array[BaseWeapon]): `BaseWeapon` resources (e.g. `res://src/Resources/weapons/Fist.tres`) equipped at spawn via the `WeaponHolder`.
- `body`, `eyes`, `mouth` (Texture2D): the layered art parts, drawn bottom to top. See "Character art" below.

Example (pseudo):
```
display_name = "Brawler"
base_stats = {"health": 35.0, "movement_speed": 0.35, "damage": 0.8, "armor": 4.0}
modifiers = [<FlatRegenModifier.tscn>, {"attack_speed": {"percent": 0.2}}]
```

## Character art

A character is **not one image**. It is a blank body plus face overlays, all authored on the same 150x150 canvas, so a face from one character can be dropped onto another character's body:

```
body   src/Assets/character/potato.png          (shared default body, no face)
eyes   src/Assets/character/<id>/<id>_eyes.png
mouth  src/Assets/character/<id>/<id>_mouth.png
```

`CharacterSprites` is the one implementation of the order and fallback:

- `layers(CharacterData)` returns `[slot, texture]` bottom to top, skipping a missing overlay. A character with no `body` falls back to `CharacterSprites.DEFAULT_BODY` (`src/Assets/character/potato.png`), never to a baked icon.
- `apply_to_rig()` puts the body on `Node2D/Sprite2D` and adds one child `Sprite2D` per overlay, named after its slot. The overlays inherit `flip_h`, the idle/move scale animation and the hit-flash `modulate` from the parent.
- `make_icon()` builds the UI portrait from the same stack, one `TextureRect` per layer. Every layer shares one crop: the square union of their opaque pixels, so the face stays on the body while the transparent margins around the art are removed. Without that crop the body fills under half its 150x150 canvas and the card portrait reads tiny. `CharacterDetailPanel` also asks for its full 88px plate via `_icon_size()`.

Reuse is just pointing two `.tres` files at the same texture. `src/Assets/character/<id>/<id>_icon.png` is no longer drawn by either path; a character with no parts still renders the shared body.

## How selection and application works
1. Player picks a card in `CharacterSelect` (first character is pre-selected so the detail panel is never empty); the detail panel shows the full `CharacterTooltip` stats. On confirm the script sets `GlobalGameState.starting_character = "res://src/Assets/character/ranger/Ranger.tres"` (string path).
2. The flow continues to `StarterMenu` to choose weapons/items; those values are also saved in `GlobalGameState`.
3. When the game scene creates the player `Character` (instancing `src/Systems/Character.tscn`), the `CharacterInitializer` node reads `GlobalGameState.starting_character`, loads the resource, and:
   - Calls `Stats.set_base_stat` for each entry in `base_stats` (overwrites base values).
   - Walks `modifiers` and dispatches each entry **by type** (`_apply_modifier`): a Dictionary goes to `Stats.add_modifier`, a PackedScene goes to `BaseModifier.attach` (instantiate + `attachEventManager` + one active stack, under the `ItemHolder`).
   - Calls `ItemHolder.add_item` for each entry in `starting_items`.
   - Calls `WeaponHolder.add_weapon` (deferred until the ready pass finishes) for each entry in `starting_weapons`.

This keeps character data separate from player logic and allows easy addition of new characters.

## Armor is a plain stat
`armor` is in `Stats.DEFAULT_STATS` (default 0) and is read by the damage
pipeline itself (`Damage.apply_armor`, run by `Health.apply_damage()` before any
listener), so the value alone reduces every hit by `10 / (10 + armor)` — see
`docs/systems/damage.md`. An armored character just sets it in `base_stats`:

```
base_stats = {..., "armor": 5.0}   # Soldier
base_stats = {..., "armor": 4.0}   # Brawler
```

Rules:
- Every armor source (base stat, stat items, rolled stats) sums into the one
  `armor` stat, so a hit is reduced exactly once.
- There is no armor modifier. An armor item is a stat item (`ArmorPlate.tres`),
  and the item factory rolls armor like any other stat.
- `CharacterInitializer` names no stat and no modifier. Adding a brand new
  behavior to a character is a data edit: drop that modifier's scene into
  `modifiers`. The same is true for items (`ItemHolder` goes through the shared
  `BaseModifier.instantiate_attached`).
- A modifier scene entry that is not a `BaseModifier`, or an entry of any other
  type, logs a warning instead of failing silently.

## When the amount lives on the modifier, not on a stat
Unlike armor, a regen amount is not a stat: `FlatRegenModifier` exports
`health_delta` on the scene, because a regen tick is not a stat and nothing
reads a `regen` value out of `Stats`.

So a character that wants its own regen rate declares a **configured variant**
of the shared scene — a `.tscn` that instances the modifier and overrides the
exports. Nothing else changes; the script, the timer, the signed-delta routing
and the tooltip all stay shared.

```
src/Assets/character/wildling/WildlingRegenModifier.tscn
    instances FlatRegenModifier.tscn with health_delta = 1.0

Wildling.tres:  modifiers = [<WildlingRegenModifier.tscn>]
```

Rules that keep this the only correct way:
- Put the variant next to the character's own `.tres`, **not** in
  `Systems/Items/modifiers/`. Everything in that folder is offerable in the shop
  (`test/Systems/Items/test_offerable_modifier_scenes.gd` sweeps it), so a
  character-only variant dropped there would be sold as an item card.
- The character card is built by reflecting on the scene, so it prints the
  **configured** number, not the script's export default. If the card and the
  in-game tick disagree, the override was not applied to the variant.
- Prefer this over a second copy of the script. A variant scene inherits every
  behavior change to the modifier automatically.

## Where armor shows up during a run
`armor` is a base stat, so every stat panel lists it (`Stats.display_stat_names()`,
read by `src/ui/character_ui.gd`, `src/ui/player_ui.gd` and the shop's
`src/Scenes/menu/shop_menu.gd`). Brawler shows `Armor: 4.00`, a character with
none shows `Armor: 0.00`, and the row tracks armor items as they are picked up
and sold. That number is the one the damage formula reads.
`test/Systems/Items/test_armor_stat_visibility.gd` pins it.

`src/Scenes/menu/configure_panel.gd` walks `DEFAULT_STATS` to build its editor
rows, so armor is editable there too.

## How a character's stats are coloured
`base_stats` are **absolute** values that overwrite the `Stats` defaults, not
gains — a Ranger's `health: 30.0` replaces the default 10. So the panel shows
the absolute number and uses colour to say whether it beats the default:
- `src/Systems/stats/stats.gd` exposes `const DEFAULT_STATS` plus
  `static func default_stat(name)`, which is the single source of truth for the
  baseline. `@export var stats` is initialised from it, so there is one table,
  not two that can disagree.
- `CharacterTooltip._tone_vs_default()` compares each value against that default:
  above → green, below → red, equal → neutral.

Entries in `modifiers` are real deltas, so those keep the explicit `+`/`-` and
derive their tone from the value itself — same rule the shop cards use.

## Adding a new character
1. Create `src/Assets/character/<id>/<Id>.tres` using the `CharacterData` script as the resource type, next to the character's art (or copy an existing one and rename).
2. Set `display_name`, `description`, and `base_stats` (archetype stats only). Put everything else in `modifiers` — stat dicts and/or modifier scenes.
3. If the behavior's amount is an export rather than a stat, declare a configured variant scene next to the `.tres` (see above).
4. No code changes needed — `CharacterSelect` scans the folder and will display the new entry.

## Extensibility ideas
- Optional: merge a character's `starting_weapons`/`starting_items` into `GlobalGameState` on confirm so they still appear in the StarterMenu loadout; currently they are applied directly at spawn by `CharacterInitializer`.
