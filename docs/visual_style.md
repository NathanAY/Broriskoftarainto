# Visual style

Reference for generating or editing game art. Use it with the `generate-image` skill (Bing Image Creator).

Status: the art pipeline is still a prototype. This document records the *direction* and the hard constraints that are already fixed, not a full asset spec.

## Art direction

Brotato-like top-down arena roguelite. Flat, cartoon, hand-drawn vector look:

- One bold, dark outline around the subject. No gradients inside the shape, no soft shading, no texture noise.
- Flat saturated fills with a hard cel-shaded highlight and one darker shadow shape.
- Chunky, rounded, slightly exaggerated proportions. Silhouette must stay readable at 48x48.
- Playful and grim-lite: monsters and weapons are threatening, but the shapes stay cartoon, never realistic or gory.
- No text, no letters, no numbers, no UI chrome, no border frames, no drop shadow baked into the PNG.

The existing assets were copied from a Brotato 3.6 decompile (`F:\programs\Godot projects\Brotato3.6\`). That is the reference for what "on style" means, and it is also the fastest source of new icons when mining is acceptable.

## Hard constraints

Every generated PNG must satisfy all of these or it will not load, or will render wrong:

| Constraint | Value |
| --- | --- |
| Background | Fully transparent. Bing usually returns a solid or checker background, so cut it out afterwards. |
| Canvas | Square, exact size for the asset class (table below). Export lossless PNG. |
| Subject | One object, centered, filling roughly 75-85% of the canvas, with even padding on all four sides. |
| Mipmaps | Off. No size limit. Fix alpha border on. |
| Naming | `snake_case.png`, must match the path in the table below exactly. |

## Asset classes

| Class | Path and filename | Canvas | Rendered at |
| --- | --- | --- | --- |
| Stat icon | `src/Assets/stats/<stat_key>.png` | 96x96 | 24x24 in stat lists, 36-64x36 in item cards |
| Modifier / effect icon | `src/Assets/modifiers/<modifier_scene_basename>.to_lower()>.png` | 96x96 | 36x36 tooltip, 48x48 tile, 64x64 card |
| Weapon icon | `src/Assets/weapons/<snake_case>.png` | 80x80 | 64x64 card, and in-world as a Sprite2D |
| Enemy sprite | `src/Assets/enemies/<snake_case>.png` | 100x100 grunt, 225x225 boss | in-world, ~0.4x half-width is the collision radius |
| Character icon | `src/Assets/character/<id>/<id>_icon.png` | 96x96 | 64x88 card |
| Character face | `src/Assets/character/<id>/<id>_eyes.png` / `_mouth.png` | 150x150 | overlaid on the shared body sprite |

The two binding rules:

- A stat icon filename **is** the stat key. `stats.gd` builds the path as `res://src/Assets/stats/%s.png % stat_name`. Any other name is never found.
- A modifier icon filename **is** the lowercase basename of the modifier `.tscn`. `ItemIconGenerator.gd` derives it from `effect.resource_path`. `PoisonModifier.tscn` needs `poisonmodifier.png`.

Fallbacks when a lookup fails: `stats/_default.png` and `modifiers/_default.png`.

Weapons and characters use an explicit `sprite` / `small_icon` field on the `.tres`, so the filename only needs to be `snake_case` and readable. An empty weapon `sprite` falls back to `src/Assets/weapons/_default.png`.

## Palette

Anchored on the UI colors in `src/ui/item_display_panel.gd`. Art should read against the dark panels (`#262932` cards, `#343945` icon plate), so keep fills bright.

| Role | Hex |
| --- | --- |
| Positive / gain / buff | `#7ADE7A` |
| Negative / cost / damage | `#F37171` |
| Neutral body text | `#C8CDD8` |
| Muted flavor text | `#969DAD` |
| Gold accent, headings, prices | `#FFD35A` |
| Panel background | `#262932` |
| Icon plate background | `#343945` |
| Hover / selection accent | `#F9BA50` |
| Weapon card border | `#E77E28` |
| Locked offer border | `#5CB0E8` |

Use these as the tint range, not as a literal palette per asset. Enemy and weapon art in the project is more saturated than this list; the list is a floor for consistency, not a ceiling.

Note: color in the UI is semantic and comes from the code, not from the art. Green/red/gold on a card body is chosen by `ItemCardRow.Tone` and `BaseModifier.EffectKind`. Do not bake a green or red glow into an icon to signal a buff.

## Prompt templates

Bing Image Creator takes one flat prompt string. Fill the braces. Keep the trailing constraint block, it is what keeps output usable.

### Item / effect icon

```
{A single object, e.g. "a coiled metal spring"} as a game inventory icon, flat cartoon
vector illustration, bold dark outline, flat saturated colors, hard cel-shaded highlight and
one darker shadow shape, chunky rounded proportions, centered, filling the frame, plain
readable silhouette at small size. Transparent background, no text, no letters, no frame,
no border, no drop shadow, square 1:1, isolated single object.
```

### Stat icon

```
{A stat concept, e.g. "a clenched fist punching forward"} as a game stat icon, flat cartoon
vector illustration, bold dark outline, flat saturated colors, simple iconic shape, centered,
filling the frame, readable at 24 pixels. Transparent background, no text, no letters, no
frame, no border, no drop shadow, square 1:1, isolated single object.
```

### Weapon icon

```
{A weapon, e.g. "a stubby silver pistol seen from the side"} as a top-down arena shooter weapon
icon, flat cartoon vector illustration, bold dark outline, flat saturated colors, chunky
rounded proportions, side view, centered. Transparent background, no text, no frame, no border,
no drop shadow, square 1:1, isolated single object.
```

### Enemy sprite

```
{A creature, e.g. "a bloated green toad-like blob monster with a single glowing eye"} as a
top-down arena roguelite enemy, flat cartoon vector illustration, bold dark outline, flat
saturated colors, chunky rounded exaggerated proportions, seen from directly above, centered,
filling the frame. Transparent background, no text, no frame, no border, no drop shadow, square
1:1, isolated single creature.
```

Aspect ratio: set `1:1` in the Bing composer for everything above. Bing defaults to `3:2`, which produces a canvas the loader will have to crop.

Mode: leave `Vivid and natural`. `Realistic` fights the art direction every time.

### Negative phrasing

Bing rewards explicit exclusions. Keep `no text`, `transparent background`, and `no drop shadow` in every prompt. Add more when the subject invites it:

```
no gradients, no realistic shading, no 3d render, no isometric perspective, no watermark
```

## Workflow

1. Check `F:\programs\Godot projects\Brotato3.6\` first. Mining an existing icon is faster and always more consistent than generating.
2. Otherwise write the prompt from a template above.
3. Run the `generate-image` skill. It saves to `~/Downloads` as `<prompt-slug>.jpg`.
4. Post-process outside the repo: cut out the background, resize to the exact canvas, export lossless PNG.
5. Move into the repo at the exact path from the asset-class table. Godot generates the `.import` on next open.
6. Wire the asset up: stat and modifier icons are found by filename, weapons and characters need the `sprite` / `small_icon` field set on the `.tres`.
7. Verify visually. Item icons only appear in `res://test/tools/shop_ui_preview.tscn`:

   ```
   .run_scene_shot.bat res://test/tools/shop_ui_preview.tscn res://shop_shot.png
   ```

   Character icons only appear in `res://test/tools/character_ui_preview.tscn`. Neither fixture picks up a new asset unless it is added to the fixture's `SAMPLE_ITEMS`.

8. Delete the screenshot PNGs afterwards, they are scratch output and not committed.

## Known gaps

- Only 8 of 24 modifier scenes have a matching icon. The rest fall back to `_default.png`, and 8 icon files in `src/Assets/modifiers/` are orphaned because their names do not match any scene basename.
- `src/Assets/modifiers/armormode.png` is a typo for `armormodifier.png`.
- `Thorns.tres` has no `sprite` at all.
- `Knife.tres` points at `circular_saw.png`.
- No custom font. Everything uses the Godot built-in. Brotato used `Anybody-Medium.ttf` if a font is ever needed.
- No shaders anywhere in the project.

## Where the values come from

| Fact | Source |
| --- | --- |
| UI colors, panel stylebox | `src/ui/item_display_panel.gd:17-28`, `make_panel_stylebox()` |
| Stat icon lookup | `src/Systems/stats/stats.gd:189-193` |
| Modifier icon lookup | `src/ui/ItemIconGenerator.gd:22-32` |
| Icon display sizes | `src/ui/IconCard.tscn`, `src/ui/ItemDisplayPanel.tscn`, `src/ui/TooltipUi.tscn`, `src/ui/icon_card.gd` |
| Card plates | `src/Scenes/menu/ShopItemCard.tscn:6-54` |
| Tone semantics | `docs/systems/ui_shop_portal.md`, `docs/systems/modifiers.md` |
| Art provenance | `src/Systems/arena.gd:1-15` |
| Naming convention | `hidden.txt` at repo root |