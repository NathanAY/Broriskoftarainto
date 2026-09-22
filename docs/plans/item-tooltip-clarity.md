# Item Tooltip Clarity Plan

> Status: IMPLEMENTED — see `src/ui/item_tooltip.gd`, `src/Systems/Items/item_factory.gd`,
> pilot `display_name`/`tooltip_text` on `projectile_bounce_modifier.gd` + `explosive_shot_modifier.gd`,
> and `test/ui/test_character_ui_tooltip.gd`.

## Goal

Fix `ItemTooltip.tooltip_lines()` (`src/ui/item_tooltip.gd`) clarity problems raised against
`test/ui/test_character_ui_tooltip.gd`, without changing game logic:

1. Weapons: drop useless `description: Pistol` line (duplicates `name`).
2. Stat items: stop doubling `description: Increases damage by 5` + `damage flat: 5.0`.
3. Effect items: stop showing PascalCase `effects: ProjectileBounceModifier`; use human-readable
   modifier-owned text. Note: factory description (`src/Systems/Items/item_factory.gd:92-127`)
   will differ from current test literals — plan covers the new source.
4. Buff/debuff items: remove nonsensical empty `effects: ` line and surface the real payload
   hidden inside the packed `Buff`/`DebuffSource` instance.
5. Introduce modifier display contract: `display_name` + `tooltip_text`.

Implementation must follow AGENTS.md:
read code → read testing docs → write test → run → fix → rerun.

## Settled decisions (grill rounds 1–2)

- Q1 Weapon description: drop unconditionally from tooltip.
- Q2 Stat items: option A — `name + modifier lines` only, no description line.
- Q3 Effect items: option C with A — modifier owns text; `Item.description` dropped for
  effect display; tradeoff shown via `modifier_lines`.
- Q4 Buff/debuff: option A — suppress blank line, surface payload by peeking into packed
  instance, prefix payload vs tradeoff.
- Q5 Modifier variable: option B — two fields: `display_name` + `tooltip_text`.
- Q6 Weapon field fate: A — leave `BaseWeapon.description` field + `.tres` untouched;
  tooltip just ignores it.
- Q7 Stat plumbing: A — tooltip ignores `description` for stat items; builder/factory
  signatures unchanged in this step; factory stops embedding raw dicts.
- Q8 Reading mechanism: C steady state (factory/build-time resolved text, tooltip never
  instantiates per hover) with A fallback (temp instantiate + `queue_free`, cached).
- Q9 Line format: A — explicit `buff:` / `tradeoff:` (or `effect:` / `tradeoff:`) prefixes;
  description carries flavor + trigger only, never raw dicts.
- Q10 Migration scope: A — pilot on `projectile_bounce_modifier.gd` (+ 1–2 more,
  e.g. `explosive_shot_modifier.gd`); remaining ~18 use humanized fallback.
- Q11 Plan file: this file — `docs/plans/item-tooltip-clarity.md`.

## Current behavior (evidence)

- `src/ui/item_tooltip.gd:8-14` — weapon: `name/damage/range/attack speed/[description]`.
- `src/ui/item_tooltip.gd:15-18` — item: `name/[description]`.
- `src/ui/item_tooltip.gd:25-29` — effects: `scene.resource_path.get_file().get_basename()`
  → `ProjectileBounceModifier`; packed buff scenes from `ItemBuilder.pack_instance()`
  (`src/Systems/Items/item_builder.gd:43-46`) have empty `resource_path` → `"effects: "`.
- `Pistol.tres:16-17` — `name = "Pistol"`, `description = "Pistol"`.
- `PlusDamageItem.tres:8-13` — `description = "Increase damage by 5"` + `damage flat 5.0`.
- `item_factory.gd:88` — `"Increases %s for %s\nDecreasese %s for %s"` (typo + raw dicts).
- `item_factory.gd:100-120` — `"Grants special effect: %s[ (Triggers on %s)]\nDecreasese %s for %s"`.
- `item_factory.gd:148-149,166-172` — buff/debuff descriptions mix flavor + tradeoff dicts.
- `projectile_bounce_modifier.gd:1-9`, `explosive_shot_modifier.gd` — no display fields.
- Payload hiding: `Buff.modifiers` (`src/Systems/Items/Buffs/buff.gd:7-10`) and
  `DebuffSource.modifiers` (`src/Systems/Items/Buffs/debuff_source.gd:7`) live inside the
  packed instance, never rendered; tooltip only renders `Item.modifiers` (tradeoff).

## Target behavior

### Weapons (`BaseWeapon`)

```
name: Pistol
damage: 5.0
range: 400.0
attack speed: 0.8
pierce: 1
knockback: 120.0
```

- Rule: never emit `description` for `is BaseWeapon`, even if non-empty (Q6-A: field stays,
  tooltip ignores).
- Rule: weapons that declare built-in effects in `BaseWeapon.modifiers` append one
  human-readable line per effect (`WeaponBuiltinEffects.builtin_tooltip_lines`), e.g.
  `pierce: 1`, `knockback: 120.0`, `poison: 50% chance, 3.0s`. Weapons without built-ins
  stay at the four base lines.

### Stat items (`effect_scene` empty, no buff/debuff meta)

```
name: Damage Amulet
damage flat: 5.0
```

- Rule: `name + modifier_lines(item.modifiers)`; ignore `item.description` (Q7-A).
- `PlusDamageItem.tres` keeps its `description` field on disk; tooltip ignores it.
- Factory `_generate_stat_item` stops building `"Increases...Decreasese..."`; it still
  returns `{chosen: value, negative: negative_value}` — tooltip renders both lines.

### Effect items

```
name: Bounce
effect: Projectile Bounce — Projectiles bounce to 3 extra targets (Triggers on hit)
tradeoff: armor flat: -1.0
```

- `effect:` prefix (not `effects:` plural; singular per item — factory only ever attaches one).
- Effect head comes from modifier contract (below), NOT from `Item.description`.
- `Item.description` ignored for effect items in tooltip (Q3-C).
- Trigger text (`trigger_event`, cf. `item_factory.gd:104-112`) appended humanized
  (`on_hit` → `on hit`) inside the effect line, not as a separate concatenated sentence.
- Fallback when modifier lacks fields: humanize basename
  (`ProjectileBounceModifier` → `Projectile Bounce`): split PascalCase, `capitalize()`.
  Never show raw PascalCase.

### Buff / debuff items

```
name: Haste Buff
Grants temporary haste on hit (3s)        # flavor+trigger only, no dicts
buff: attack_speed flat: 0.1
tradeoff: armor flat: -1.0
```

- Never emit `effects:` when resolved name list is empty (fixes blank line).
- Payload: peek into packed `Buff`/`DebuffSource` instance `modifiers`, render with
  `buff:` / `debuff:` prefix. Tradeoff from `Item.modifiers` rendered with `tradeoff:` prefix (Q9-A).
- Exact prefix strings (`buff:` vs `debuff:` vs shared `effect:`) are an implementation
  detail — pick one and apply consistently; tests assert the chosen one.
- Factory `_generate_buff_item` / `_generate_debuff_item` must stop appending
  `"\nDecreasese %s for %s" % [stat, dict]` to description.

## Changes (for the implementation)

### 1. `src/ui/item_tooltip.gd`

- Weapon branch: delete `if resource.description` append.
- Add type predicates:
  - `is_stat_item(item)`: `item.effect_scene.is_empty()` and no `buff`/`debuff` meta.
  - `is_buff_item / is_debuff_item`: via `get_meta("type")` (as `item_builder.gd:24,33` sets).
- Stat branch: `name + modifier_lines`, skip description.
- Effect branch: `name + effect_line + tradeoff_lines`, skip description.
- Buff/debuff branch: `name + flavor_description? + payload_lines + tradeoff_lines`, skip
  empty effects line. Flavor `description` shown ONLY if it contains no raw-dict pattern
  (transitional); long-term factory writes clean flavor.
- Replace effects basename logic with `resolve_effect_display(scene) -> Dictionary{name, text, trigger}`:
  - Steady state (Q8-C): prefer pre-resolved values cached on item (factory writes at build
    time); tooltip does not instantiate per hover.
  - Fallback (Q8-A): temp instantiate, read `display_name`/`tooltip_text`/`trigger_event`,
    `queue_free()`, cache result per `resource_path`.
  - Humanize helper: `humanize(s)`: `replace("_"," ")`, split PascalCase, `capitalize()`.
- Guard: never append `effects:`/`effect:` line when resolved name is empty (packed-scene case).

### 2. Modifier contract (Q5-B, Q10-A pilot)

Add to `projectile_bounce_modifier.gd` (+ `explosive_shot_modifier.gd` as second pilot):

```gdscript
@export var display_name: String = "Projectile Bounce"
@export_multiline var tooltip_text: String = "Projectiles bounce to N extra targets."
```

- `display_name`: short user-facing noun (`Bounce` style allowed if item name already says it —
  keep `display_name` noun-like, `Item.name` stays the title).
- `tooltip_text`: one sentence, no numbers-duplication beyond what modifiers need;
  may use `@export` params (`max_bounces`) in text manually (no runtime interpolation required
  in this step).
- Other ~18 modifiers: untouched; tooltip uses humanized fallback. Follow-up checklist
  (not this task): add fields to all `src/Systems/Items/Modifiers/*.gd`.

### 3. `src/Systems/Items/item_factory.gd` + `item_builder.gd`

- Signatures unchanged (Q7-A).
- `_generate_stat_item`: stop formatting dicts into description (or write generic flavor
  that tooltip will ignore for stat items anyway).
- `_generate_effect_item`: description becomes flavor + trigger only OR removed; tradeoff
  dict stays in `modifiers` for tooltip lines. Fix `Decreasese` typo wherever touched.
- `_generate_buff_item` / `_generate_debuff_item`: same — description = flavor + trigger,
  no ` % [dict]` interpolation.
- Optional (Q8-C): factory resolves `display_name`/`tooltip_text`/`trigger_event` at build
  time (it already instantiates in `_configure_dynamic_modifier`) and stores on item
  (e.g. meta or description-clean fields) so tooltip avoids per-hover instantiate.

### 4. Data (deferred, not required for tests)

- Leave `Pistol.tres`, `PlusDamageItem.tres`, all modifier `.tscn` untouched in this step
  (Q6-A). Optional later cleanup: clear `description = "Pistol"` dups.

## Test rewrite (`test/ui/test_character_ui_tooltip.gd`)

All 8 tooltip-content tests must be updated; hover/shop/global tests unchanged
(`test_hover_shows_and_hides_tooltip`, `test_tooltip_ui_bind_to_row`,
`test_shop_menu_character_info_tooltips`, `test_freeing_character_clears_global`).

| Test | Current assert (to remove) | New assert |
|---|---|---|
| `test_weapon_tooltip_lines` | `description: Pistol`, size 5 | `name/damage/range/attack speed` only, size 4, `not contains "description:"` |
| `test_item_tooltip_lines` (PlusDamage) | `description: Increase damage by 5`, size 3 | `name: Damage Amulet` + `damage flat: 5.0`, size 2, no description |
| `test_stat_item_tooltip_lines_via_builder` | `description: Increases damage by 5`, size 4 | `name + damage flat: 5.0 + movement_speed flat: -2.0`, size 3, no description |
| `test_stat_item_positive_and_negative_mirroring_factory` | `description: + item.description`, size 4 | `name + damage flat: 0.08 + movement_speed flat: -0.05`, size 3 |
| `test_effect_item_tooltip_lines_via_builder` | `description: Grants bouncing...`, `effects: ProjectileBounceModifier`, size 4 | `name: Bounce` + `effect:` humanized line containing `Projectile Bounce` (not PascalCase `ProjectileBounceModifier`) + `armor flat: -1.0` with `tradeoff:` prefix per Q9; size per chosen format (3–4); assert `not contains "ProjectileBounceModifier"` |
| `test_effect_item_with_negative_stat_mirroring_factory` | same pattern + raw-dict description | same as above with `-0.1` tradeoff; description reflects factory `_generate_effect_item` flavor+trigger only |
| `test_buff_item_tooltip_lines_via_builder` | `description: Grants a temporary...`, `effects: ` (blank), size 3 | `name` + flavor (no dicts) + `buff: attack_speed flat: 0.1` payload + tradeoff if present; assert `not contains "effects: "` (no blank line) |
| `test_debuff_item_tooltip_lines_via_builder` | `description: Grants an armor...`, `effects: ` (blank), size 3 | `name` + flavor + `debuff: armor flat: -10.0` payload; assert no blank effects line |

Note: effect/buff/debuff tests use `ItemBuilder.make_*` directly with hardcoded literals —
new tests must construct the same way but assert the NEW line sets above, not the old
`description`/`effects:` literals. Factory-mirroring tests keep hardcoded tradeoff dicts
(`{"flat": -0.05}`, `{"flat": -0.1}`) but drop raw-dict-in-description assertions.

## Verification

1. `.\run_tests_gdunit_custom.bat test_character_ui_tooltip.gd` — all pass.
2. Full suite `.\run_tests_gdunit.bat` — no regressions (tooltip is shared by CharacterUI + ShopMenu).
3. Manual: hover item/weapon rows in CharacterUI and ShopMenu character info — no `description:`
   dup on weapons/stats, no PascalCase, no blank `effects:` line.
4. Per AGENTS.md: test → run → read failure → fix → rerun.

## Out of scope / follow-ups

- Removing `BaseWeapon.description` / `Item.description` fields or migrating `.tres` data.
- Adding `display_name`/`tooltip_text` to all ~18 remaining modifiers.
- Styled tooltip layout, icons, colors; runtime-computed damage.
- Fixing `Decreasese` typo everywhere (only where touched) and weapon `range` vs
  `weapon_range` `.tres` caveat (see `docs/plans/character-ui-item-tooltip.md`).
