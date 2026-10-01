# Visual style

Reference for generating or editing game art. Use it with the `generate-image` skill (Bing Image Creator).

Status: the art pipeline is still a prototype. This document records the *direction* and the hard constraints that are already fixed, not a full asset spec.

## Art direction

Brotato-like top-down arena roguelite. Flat, cartoon, hand-drawn vector look:

- One bold, dark outline around the subject. No gradients inside the shape, no soft shading, no texture noise.
- Flat fills that are **desaturated and earthy**, under a very heavy near-black outline. See the measured numbers in "Palette".
- Chunky, rounded, slightly exaggerated proportions. Silhouette must stay readable at 48x48.
- Playful and grim-lite: monsters and weapons are threatening, but the shapes stay cartoon, never realistic or gory.
- No text, no letters, no numbers, no UI chrome, no border frames, no drop shadow baked into the PNG.

The existing assets were copied from a Brotato 3.6 decompile (`F:\programs\Godot projects\Brotato3.6\`). That is the reference for what "on style" means, and it is also the fastest source of new icons when mining is acceptable.

## Hard constraints

Every generated PNG must satisfy all of these or it will not load, or will render wrong:

| Constraint | Value |
| --- | --- |
| Background | Fully transparent. Bing usually returns a solid or checker background, so cut it out afterwards. |
| Canvas | Exact size for the asset class (table below). Square for icons and sprites; wide for menu background layers. Export lossless PNG. |
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
| Character face | `src/Assets/character/<id>/<id>_eyes.png` / `<id>_mouth.png` | 150x150 | overlaid on the shared body sprite |
| Menu background layer | `src/Assets/menu/parallax_<far\|mid\|near>.png` | 1616x832, 1676x832, 1764x832 | full-bleed, cover-fitted and swayed by `src/ui/menu_parallax_layer.gd` |

The three menu background layers are a different animal from everything else here, and the difference is not cosmetic:

- **They are not square, and not one canvas either.** Each is wider than the 1552px viewport by twice its layer's horizontal travel, because the layer slides sideways and art fitted to the bare window would uncover a gap on the first pixel of sway. The far layer needs 32px of extra width, mid 62px, near 106px.
- **They are generated at `3:2` and post-processed**, not `1:1`. See the template below.
- **Two of the three are keyed, not cut out.** The far layer is opaque and needs no transparency at all. Mid and near need a transparent margin on the left and right, which is what lets them slide without showing a hard edge.
- **They carry a shared style block verbatim across all three prompts.** Change it once and all three change, which is the only way three separately generated images read as one scene.

The width figures are asserted against the shipped PNGs by `test/Systems/menu/test_menu_parallax.gd`, and are derived from the `travel` and `mouse_travel` exports in `src/Scenes/menu/Main.tscn`. Change a layer's travel and its art has to be rebuilt, or the sway will show a gap.

The build is a script, not a manual step — `test/tools/parallax_postprocess.gd`, which keys white to alpha, grows each row by modal fill, pads the transparent overscan, and exports the PNGs.

The two binding rules:

- A stat icon filename **is** the stat key. `stats.gd` builds the path as `res://src/Assets/stats/%s.png % stat_name`. Any other name is never found.
- A modifier icon filename **is** the lowercase basename of the modifier `.tscn`. `src/ui/ItemIconGenerator.gd` derives it from `effect.resource_path`, so `PoisonModifier.tscn` would need `poisonmodifier.png` — which does not exist yet, see "Known gaps".

Fallbacks when a lookup fails: `src/Assets/stats/_default.png` and `src/Assets/modifiers/_default.png`.

Weapons and characters use an explicit `sprite` / `small_icon` field on the `.tres`, so the filename only needs to be `snake_case` and readable. An empty weapon `sprite` falls back to `src/Assets/weapons/_default.png`.

## Palette

Two palettes, and conflating them is the single easiest way to produce art that fights the game.

### The UI palette

This table is the **UI**, and it is the one that is bright. Colours here are semantic and come from the code, never from the art.

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

Anchored on `src/ui/item_display_panel.gd`.

Note: color in the UI is chosen by `ItemCardRow.Tone` and `BaseModifier.EffectKind`. Do not bake a green or red glow into an icon to signal a buff.

### The art palette

**The shipped art is desaturated, and the outline is heavy.** This is measured, not asserted:

| Asset | Near-black outline pixels | Mean saturation of non-outline pixels |
| --- | --- | --- |
| `src/Assets/tiles/tiles_1.png` | 4.3% | 25.9% |
| `src/Assets/weapons/pistol.png` | 64.0% | 19.3% |
| `src/Assets/enemies/spitter.png` | 48.7% | 36.3% |
| `src/Assets/character/brawler/brawler_icon.png` | 36.9% | 28.4% |

A saturation of 19-36% is muted by any measure. Two-thirds of `pistol.png` and half of `spitter.png` is near-black line work. There is essentially no internal shading: the shapes are a flat fill inside a thick outline, nothing else.

So when writing a prompt for art:

- Ask for **muted, desaturated, earthy** colour — dirt brown, tan, charcoal, dark olive, cream. Do not ask for saturated or bright.
- Ask for a **thick near-black outline around every shape**. This is the strongest single visual signature of the project.
- Ask for **completely flat** fills. Do not ask for a "cel-shaded highlight". Combined with a low sun or any directional light, that phrase produces a soft gradient poster rather than a flat cartoon, which is what happened on the first attempt at the menu background.
- Pin the **time of day**. A parallax stack generated in separate calls will otherwise come back in three different lights and read as three unrelated images stacked.

Art reads against the dark UI panels (`#262932` cards, `#343945` icon plate), so it does not need to fight them for brightness.

**This section previously said the opposite** — that the art is "more saturated than this list" and that fills should be bright. Following it is what produced a discarded first batch of menu-background art that matched neither the game nor itself. The table above measures what is actually shipped.

## Prompt templates

Bing Image Creator takes one flat prompt string. Fill the braces. Keep the trailing constraint block, it is what keeps output usable.

### Item / effect icon

```
{A single object, e.g. "a coiled metal spring"} as a game inventory icon, flat cartoon
vector illustration, bold dark outline, muted desaturated colors, completely flat fills, chunky rounded proportions, centered, filling the frame, plain
readable silhouette at small size. Transparent background, no text, no letters, no frame,
no border, no drop shadow, square 1:1, isolated single object.
```

### Stat icon

```
{A stat concept, e.g. "a clenched fist punching forward"} as a game stat icon, flat cartoon
vector illustration, bold dark outline, muted desaturated colors, simple iconic shape, centered,
filling the frame, readable at 24 pixels. Transparent background, no text, no letters, no
frame, no border, no drop shadow, square 1:1, isolated single object.
```

### Weapon icon

```
{A weapon, e.g. "a stubby silver pistol seen from the side"} as a top-down arena shooter weapon
icon, flat cartoon vector illustration, bold dark outline, muted desaturated colors, chunky
rounded proportions, side view, centered. Transparent background, no text, no frame, no border,
no drop shadow, square 1:1, isolated single object.
```

### Enemy sprite

```
{A creature, e.g. "a bloated green toad-like blob monster with a single glowing eye"} as a
top-down arena roguelite enemy, flat cartoon vector illustration, bold dark outline, flat
desaturated colors, chunky rounded exaggerated proportions, seen from directly above, centered,
filling the frame. Transparent background, no text, no frame, no border, no drop shadow, square
1:1, isolated single creature.
```

Aspect ratio: set `1:1` in the Bing composer for every icon and sprite template above. Bing's default is `3:2`, which produces a canvas the loader would have to crop. **There is no `16:9` option** — the composer offers only `1:1`, `3:2` and `2:3` — so the menu background template below uses `3:2` deliberately.

Mode: leave `Vivid and natural`. `Realistic` fights the art direction every time.

### Menu background layer

The one asset class that is a whole scene rather than one object. Fill `{layer}` with what the layer is for, then paste the shared style block in so all three match. Keep the shared block **verbatim and identical** across every layer — that is the mechanism, not a stylistic preference.

```
A {layer} of a cartoon arena field, as the {layer} of a parallax game menu. [describe the
contents: what occupies this depth, and that the rest is empty]. Every shape has a thick
near-black outline. Flat daytime lighting. Left and right edges are completely empty plain
pure white over the outer 15 percent of the width so the layer can slide sideways without
showing a hard edge. [SHARED STYLE BLOCK]
```

SHARED STYLE BLOCK — paste into all three, unchanged:

```
cartoon style background in the style of a brotato-like arena game, thick near-black
outline around every single shape, completely flat solid colour fills, no gradients, no
soft shading, no glow, no bloom, muted desaturated earthy palette of dirt brown, tan,
charcoal grey, dark olive green and cream, simple chunky rounded cartoon shapes, thick
bold lines, flat daytime lighting, wide landscape composition, no text, no letters, no
numbers, no UI chrome, no border, no frame, no watermark, no drop shadow, no realistic
shading, no 3d render, no isometric perspective, no detailed scenery
```

Four things about this template that are not obvious:

1. **Ask for plain pure white, not transparent.** Asking for "transparent" reliably returns white anyway; asking for it on purpose means the keying is deterministic. The backdrop is keyed back out in post, and the art contains no white of its own, so a white key is safe.
2. **The empty-edge instruction is load-bearing but not sufficient.** State it in the prompt *and* bake the margin in post. Never trust the prompt for the overscan alone; Bing will ignore it and the seam appears the moment the layer drifts.
3. **Say the layer is "not cropped by the edge"** for any object that needs padding around it. Asking for a shape that is deliberately cropped returns one sliced off at the canvas border, which is fatal for a layer that must be padded.
4. **Generate the far layer first and approve it before spending on the other two.** If the shared style block is wrong, fix the block. Generating three variations of a wrong look is the mistake the first batch of this art made — three layers in three different lights.

The far layer is the exception to the transparent-margin rule: it is the backdrop, so it is opaque and takes width instead of transparency.

### Negative phrasing

Bing rewards explicit exclusions. Keep `no text`, `transparent background`, and `no drop shadow` in every prompt. Add more when the subject invites it:

```
no gradients, no realistic shading, no 3d render, no isometric perspective, no watermark
```

The icon templates above no longer ask for a **cel-shaded highlight**. That phrase asks for a light source, and a light source on flat art produces a gradient poster instead of a flat cartoon. The shipped art has no internal shading at all — see the measured outline and saturation numbers in "Palette".

## Workflow

1. Check `F:\programs\Godot projects\Brotato3.6\` first. Mining an existing icon is faster and always more consistent than generating.
2. Otherwise write the prompt from a template above.
3. Run the `generate-image` skill. It saves to `~/Downloads` as `<prompt-slug>.jpg`.
4. Post-process outside the repo: cut out the background, resize to the exact canvas, export lossless PNG. For a **menu background layer** this step is scripted — `test/tools/parallax_postprocess.gd` does the keying, the grow and the transparent overscan, and writes the PNGs the scene loads:

   ```
   godot --headless --script res://test/tools/parallax_postprocess.gd
   ```

5. Move into the repo at the exact path from the asset-class table. Godot generates the `.import` on next open.
6. Wire the asset up: stat and modifier icons are found by filename, weapons and characters need the `sprite` / `small_icon` field set on the `.tres`.
7. Verify visually. Item icons only appear in `res://test/tools/shop_ui_preview.tscn`:

   ```
   .\run_scene_shot.bat res://test/tools/shop_ui_preview.tscn res://shop_shot.png
   ```

   Character icons only appear in `res://test/tools/character_ui_preview.tscn`. Neither fixture picks up a new asset unless it is added to the fixture's `SAMPLE_ITEMS`.

   **Menu background layers cannot be checked on the menu itself.** All three are full-bleed, so the one in front hides the ones behind. Use `res://test/tools/menu_parallax_preview.tscn`, which gives each layer its own clipped cell pinned to the extreme of its travel, which is where a gap first appears:

   ```
   .\run_scene_shot.bat res://test/tools/menu_parallax_preview.tscn res://parallax.png
   ```

8. Delete the screenshot PNGs afterwards, they are scratch output and not committed.

## Known gaps

- Only **2 of 25** modifier scenes have a matching icon — `BombOnHitModifier` and `SpinningOrbsModifier`. The other 23 all fall back to `_default.png`.
- **9 icons in `src/Assets/modifiers/` are orphaned**, because their names do not match any scene basename: `armormode` (a typo for `armormodifier`), `coil_icon`, `dynamite_icon`, `fairy_icon`, `glass_cannon_icon`, `rocket`, `shuriken`, `torch`. Either rename them to the lowercase scene basename or delete them.
- `Thorns.tres` has no `sprite` at all.
- `Knife.tres` points at `circular_saw.png`, which does not exist.
- No custom font. Everything uses the Godot built-in. Brotato used `Anybody-Medium.ttf` if a font is ever needed.
- No shaders anywhere in the project.
- The three raw `parallax_*.jpg` files in `src/Assets/menu/` are the unprocessed Bing downloads, staged rather than shipped. Nothing references them, and they should be deleted once the art is backed up off this machine — but they are currently the only copy of the accepted artwork, and `test/tools/parallax_postprocess.gd` cannot be re-run without them.
- The main menu's near layer may not earn its depth. It is a bottom-edge fringe of grass and two boulders rather than a framing device, so at 84px of travel it is worth eyeballing in place before keeping it.
- No art has been generated at `3:2` for a non-menu asset yet, so the composer's behaviour at that ratio is only confirmed for background layers.

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
| Art outline share and saturation | sampled directly from the shipped PNGs; see the table under "The art palette" |
| Menu layer canvases | derived from the `travel` and `mouse_travel` exports in `src/Scenes/menu/Main.tscn`, asserted against the PNGs by `test/Systems/menu/test_menu_parallax.gd` |