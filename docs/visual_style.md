# Visual style

Reference for generating or editing game art. Use it with the `generate-image` skill (Bing Image Creator).

Status: the art pipeline is a prototype. The direction below is settled and has been generated against — every prompt in "Prompt templates" is one that produced art worth keeping. The asset spec is not complete; see "Known gaps".

## Art direction

Top-down arena roguelite. The look is **hand-painted cel-shaded comic book art, the Borderlands 2 / Borderlands 3 / Tiny Tina's Wonderlands style, rendered in 2D**. The shorthand for it is "Borderlands, but flat and top-down".

Name the style by its references, not by the game it is imitating. The first version of this doc said "Brotato-like", which failed: Brotato is a small enough title that image models have little training data for it, so the prompt degraded into generic cartoon. Borderlands is one of the most heavily represented art styles in the training set of every image model, so naming it lands on the right thing immediately. **When writing a prompt, name Borderlands. Do not name Brotato.**

What the style actually is, in terms you can put in a prompt:

- **Heavy inked black outline** around every single shape, with a hand-drawn brush quality. This is the strongest signal and it is on every asset.
- **Painterly colour fills** with visible brush strokes and cross-hatching on background art. Flat solid fills on sprites — see "Two style blocks" below.
- **Chunky, exaggerated cartoon proportions.** Big heads, big hands, absurd weapon greebles. Not cute, not realistic.
- **Playful and grim-lite.** Monsters and weapons are threatening, but the shapes stay cartoon, never realistic or gory.

### Two style blocks

Background layers and sprites do not get the same style wording, and using one for both is a mistake that has already been made once.

| | Background layers | Sprites and icons |
| --- | --- | --- |
| Fills | `painterly textured colour fills with visible brush strokes and cross-hatching` | `completely flat solid colour fills with only one flat darker tone used for shading` |
| Why | At 832px tall, texture is the charm. The mid layers get all their character from hatch strokes inside each shape. | At 80x80, cross-hatching is noise. One flat shadow tone keeps the silhouette readable. |

The shared block is "two blocks" because the flat/painterly split is the one thing that must not be blurred. Getting it wrong produces either a muddy sprite or a boring backdrop.

### Two rules that are not obvious and cost real generations

1. **Flat fill is not the same as no detail.** The two good mid layers are flat *colour* with dense *linework* inside each shape — plank grain on the boards, hatch strokes in every bush, crack lines in the rock. That interior ink is where the character lives. Asking for "completely flat" and never asking for interior hatching in its place produces empty silhouettes, which is exactly what happened on the first far-layer attempt.
2. **Never write "very simple, low detail" as a blanket instruction.** In the far-layer prompt this was meant as "keep the composition empty" and was read as "draw less of everything" — the result was three flat cloud ovals over one green blob over a tan band. The working phrasing is **`Very simple composition, low detail`** with the interior-ink requirement stated separately per shape. Composition simplicity and shape detail are independent dials.

## Hard constraints

Every generated PNG must satisfy all of these or it will not load, or will render wrong:

| Constraint | Value |
| --- | --- |
| Background | Fully transparent, except menu background layers. Bing usually returns solid white or a fake checkerboard, so cut it out afterwards. |
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
| Character body | `src/Assets/character/potato.png` | ~100x100 | in-world, shared by every character |
| Character face | `src/Assets/character/<id>/<id>_eyes.png` / `<id>_mouth.png` | 150x150 | overlaid on the shared body sprite |
| Character icon | `src/Assets/character/<id>/<id>_icon.png` | 96x96 | 64x88 card |
| Menu background | `src/Assets/menu/parallax_far.png` | 1564x1042 | full-bleed, cover-fitted, static |

**There is no buff or debuff art, and none is needed.** `BuffTile` has no PNG of its own: it shows the *stat's* icon, from the same `src/Assets/stats/<stat_key>.png` a stat row uses, composited through `ItemIconGenerator.make_composite_icon()` when the effect touches two or more stats. A buff is identified by which stat it moves, not by a picture of the buff, so a buff.png / debuffsource.png pair would duplicate what the stat icon already says. (Neither name is backticked on purpose: they do not exist, and `test/test_doc_links.gd` checks every backticked bare filename against the project.)

The menu background is a single static image that covers the entire window. It is generated at `3:2` and post-processed to the exact canvas size needed. The background is now a plain `TextureRect` with `expand_mode = 1` and `stretch_mode = 1` (scale to fill).

The two binding rules:

- A stat icon filename **is** the stat key. `stats.gd` builds the path as `res://src/Assets/stats/%s.png % stat_name`. Any other name is never found.
- A modifier icon filename **is** the lowercase basename of the modifier `.tscn`. `src/ui/ItemIconGenerator.gd` derives it from `effect.resource_path`, so `PoisonModifier.tscn` would need `poisonmodifier.png` — which does not exist yet, see "Known gaps".

Fallbacks when a lookup fails: `src/Assets/stats/_default.png` and `src/Assets/modifiers/_default.png`.

Weapons and characters use an explicit `sprite` / `small_icon` field on the `.tres`, so the filename only needs to be `snake_case` and readable. An empty weapon `sprite` falls back to `src/Assets/weapons/_default.png`.

### The character rig, and why character art must have no face

The playable character is **not one sprite**. `src/Systems/Character.tscn` composes it:

```
Node2D/Sprite2D          src/Assets/character/potato.png   (blank body, heavy outline)
  +-- eyes               src/Assets/character/<id>/<id>_eyes.png
  +-- mouth              src/Assets/character/<id>/<id>_mouth.png
Node2D/Legs/LegL, LegR   src/Assets/character/legs.png     (hframes = 2, behind the body)
```

The body carries no facial features at all — every character shares one body texture and all identity comes from the two overlays. This is deliberate: it means one body can carry many expressions, and a new expression is a 150x150 sprite rather than a new character.

**Consequences for prompts, all of them learned the hard way:**

- A character prompt that asks for a face produces art that cannot be used. If a generated body has eyes painted on it, the overlay eyes land on top of them.
- A character prompt that asks for a portrait produces art that cannot be used *in-world*. A head-and-shoulders crop is the wrong shape entirely for a top-down arena. Character **bodies** and character **card icons** are different asset classes and need different prompts — the card icon wants the oval portrait frame, matching the existing art, and the body wants no frame and no face.
- A character prompt that asks for arms or legs produces art that fights the rig. `legs.png` is a separate sprite positioned by the scene.

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

**Buff and debuff signal through the border and the label, never the icon art.** The HUD's buff tiles carry `Positive / gain / buff` green and its debuff tiles `Negative / cost / damage` red on a 2px plate border, gold on hover — the icon between them is the plain stat art, unmodulated. A shop card's debuff payload is green, which is the opposite and is not a contradiction: there the debuff lands on the enemy and is a gain to the player. See `docs/systems/ui_shop_portal.md`.

### The art palette

The shipped art is desaturated, and the outline is heavy. This is measured, not asserted:

| Asset | Near-black outline pixels | Mean saturation of non-outline pixels |
| --- | --- | --- |
| `src/Assets/tiles/tiles_1.png` | 4.3% | 25.9% |
| `src/Assets/weapons/pistol.png` | 64.0% | 19.3% |
| `src/Assets/enemies/spitter.png` | 48.7% | 36.3% |
| `src/Assets/character/brawler/brawler_icon.png` | 36.9% | 28.4% |

A saturation of 19-36% is muted by any measure. Two-thirds of `pistol.png` and half of `spitter.png` is near-black line work.

**This section previously said the opposite** — that the art is "more saturated than this list" and that fills should be bright. Following it is what produced a discarded first batch of menu-background art that matched neither the game nor itself. The table above measures what is actually shipped.

So when writing a prompt:

- Name the **muted dusty frontier palette**: pale dusty blue, cream, charcoal grey, dark olive green, warm tan, rust brown, gunmetal. Desert, not farmland.
- Ask for a **thick inked black outline around every shape**.
- Ask for **interior ink detail on every shape** — hatch strokes, grain lines, crack lines. This is what separates a readable cartoon from an empty silhouette. See "Two rules that are not obvious" above.
- Ask for **one saturated hero colour per object** on sprites. Uniform palette across a set is what made the first weapon sheet six variations of one black rifle.
- **Pin the time of day and the light direction.** A parallax stack generated in separate calls will otherwise come back in three different lights and read as three unrelated images stacked. Long soft shadow strokes under each object is the cheapest way to keep the light consistent across separately generated layers.
- **Do not ask for a cel-shaded highlight.** That phrase asks for a light source, and on a low sun it produces a soft gradient poster instead of a flat cartoon. That is what caused the discarded first batch.

Art reads against the dark UI panels (`#262932` cards, `#343945` icon plate), so it does not need to fight them for brightness.

## Prompt templates

Bing Image Creator takes one flat prompt string. Fill the braces. Keep the trailing constraint block, it is what keeps output usable.

### Item / effect icon

```
{A single object, e.g. "a coiled metal spring"} as a game inventory icon, 2D cel-shaded
comic book game art in the style of Borderlands 2 and Tiny Tina's Wonderlands, heavy inked
black outline, visible hatching inside every shape, muted dusty frontier colours,
completely flat fills, chunky exaggerated proportions, centered, filling the frame, plain
readable silhouette at small size. Transparent background, no text, no letters, no frame,
no border, no drop shadow, square 1:1, isolated single object.
```

### Stat icon

```
{A stat concept, e.g. "a clenched fist punching forward"} as a game stat icon, 2D
cel-shaded comic book game art in the style of Borderlands 2, heavy inked black outline,
muted dusty frontier colours, simple iconic shape with hatching inside it, centered,
filling the frame, readable at 24 pixels. Transparent background, no text, no letters, no
frame, no border, no drop shadow, square 1:1, isolated single object.
```

### Weapon icon

Single weapon, if you only need one. For a set, use the sprite sheet template below — it is measurably better, see "Sprite sheets".

```
{A weapon, e.g. "a stubby silver pistol seen from the side"} as a top-down arena shooter
weapon icon, 2D cel-shaded comic book game art in the style of Borderlands 2 and Tiny Tina's
Wonderlands, heavy inked black outline, one saturated hero colour, exaggerated cartoon
proportions, taped-on and riveted parts, completely flat fills, side view, barrel pointing
right, centered. Transparent background, no text, no frame, no border, no drop shadow,
square 1:1, isolated single object.
```

### Enemy sprite

Single enemy, if you only need one. For a set, use the sprite sheet template below.

```
{A creature, e.g. "a bloated green toad-like blob monster with a single glowing eye"} as a
top-down arena roguelite enemy seen from directly above, 2D cel-shaded comic book game art
in the style of Borderlands 2, heavy inked black outline, visible hatching inside the body,
completely flat muted dusty frontier colours, chunky rounded exaggerated cartoon proportions,
centered, filling the frame. Transparent background, no text, no frame, no border, no drop
shadow, square 1:1, isolated single creature.
```

Aspect ratio: set `1:1` in the Bing composer for every icon and sprite template above. Bing's default is `3:2`, which produces a canvas the loader would have to crop. **There is no `16:9` option** — the composer offers only `1:1`, `3:2` and `2:3` — so the menu background template below uses `3:2` deliberately.

Mode: leave `Vivid and natural`. `Realistic` fights the art direction every time.

### Sprite sheets

One Bing image can hold several assets, which is the only practical way to get a consistent set — a set generated one image at a time drifts. Bing output is roughly 1024px, so a 2x2 grid gives ~512px cells and a 3x2 grid ~340px. Prefer 2x2 when the subjects need room to survive downscaling to 80x80.

**The grid will not be clean, and the extraction must not assume it is.** Observed across four accepted weapon sheets: rows sit at different heights, cell sizes vary by roughly 40%, and on one sheet two weapons actually touch. So extraction has to detect each shape's bounding box per cell and resize to the exact target canvas, not slice the sheet into equal rectangles. Where two cells touch, extract by hand.

#### Sprite sheet rules

1. **Say the grid and the separation, then say "no two alike" for sets.** `Every weapon has a completely different silhouette and a completely different dominant colour, no two alike` is the single line that turns six-of-a-kind into a set.
2. **Name a hero colour per subject, inline.** `a stubby revolver with a fat orange body`, `a sci-fi rifle with a glowing cyan energy cell`. Colour is the strongest per-object differentiator and it must be spelled out or the set collapses to one palette.
3. **Do not list six variations of one silhouette.** Six gun types are all long horizontal dark shapes and the model returns six long horizontal dark shapes. Break the shape family — include a melee weapon or a tool.
4. **Ask for pure white, never transparent.** Asking for transparent reliably returns white anyway; asking for it on purpose makes the keying deterministic. None of these subjects contain white.
5. **Ban drop shadow explicitly.** Sheets have come back with a soft grey shadow under every object, which keys into a grey halo.
6. **Ban the thing that went wrong last time.** For character bodies that means `no oval frame, no portrait crop, no head and shoulders`. For a flat-fills sprite set that means `no cross-hatching`.

#### Weapon sprite sheet

```
A sprite sheet of six separate 2D top-down arena shooter weapon icons arranged in a clean
3 by 2 grid with even spacing and identical cell sizes. Each weapon is drawn side-on in
clean side profile, horizontal, barrel pointing right, completely separated from the
others with plain empty space between them and nothing overlapping or touching. Every
weapon has a completely different silhouette and a completely different dominant colour,
no two alike. The six are: a stubby revolver with a fat orange body and an oversized
hammer, a long shotgun with a thick red barrel shroud and a wooden stock, a sci-fi
rifle with a glowing cyan energy cell and a chunky blue casing, a heavy green rocket
launcher with a wide red flared muzzle, a chunky yellow and black chainsaw-like
flamethrower with a visible fuel tank and glowing orange pilot light, and a rust-red
hatchet-shaped melee weapon with a metal spike. Each weapon has an exaggerated cartoon
proportions, one saturated hero colour, taped-on and riveted parts, vent slots and
hazard stripes. Heavy inked black outline around every shape, flat solid colour fills,
thick bold line work, readable silhouette at 64 pixels. Small elemental glow accents
only. Plain pure white background, no text, no letters, no numbers, no labels, no UI
chrome, no border, no frame, no watermark, no drop shadow, no gradients, no realistic
shading, no 3d render, no isometric perspective, square 1:1.
```

Produces far more interesting weapons than the single-weapon template. Note that `Small elemental glow accents only` is the one sanctioned exception to "no glow" — elemental glow is the strongest Borderlands weapon signal, and carving out that narrow exception is cheaper than losing it.

#### Character body sprite sheet

The body must have no face and no frame. See "The character rig".

```
A sprite sheet of four separate 2D top-down arena roguelite playable character bodies
arranged in a clean 2 by 2 grid with even spacing and identical cell sizes, each a simple
rounded egg-shaped potato-like blob body with a heavy inked black outline, seen from a high
three-quarter angle looking down at it, each one completely separated from the others with
plain empty space between them. The four bodies are: a pale cream egg body, a dusty orange
egg body with a small stubby arm nub on each side, a mossy green rounded square-ish body,
and a pale grey egg body with two small pointy ear nubs on top. Completely blank and
featureless bodies with absolutely no faces, no eyes, no mouths and no facial features of
any kind, just smooth empty body shapes. Flat solid colour fills, chunky exaggerated
cartoon proportions, thick bold line work. Plain pure white background, no text, no
letters, no numbers, no labels, no oval frame, no portrait crop, no head and shoulders,
no border, no frame, no watermark, no drop shadow, no gradients, no realistic shading,
no 3d render, square 1:1.
```

#### Character eyes and mouth sprite sheet

Only relevant while the overlay rig exists. Target 150x150 per cell.

```
A sprite sheet of eight separate 2D cartoon facial feature sprites arranged in a clean 4 by
2 grid with even spacing and identical cell sizes, each cell containing exactly one small
flat feature with nothing else in it. Top row, left to right: a pair of wide round white
eyes with black pupils, a pair of angry slanted eyes, a pair of narrow smug half-closed
eyes, a pair of round glowing goggles. Bottom row, left to right: a wide toothy grin, a
small round open mouth, a flat straight line mouth, a crooked wavy nervous mouth. Heavy
inked black outline around every shape, completely flat solid colour fills, chunky bold
cartoon proportions, thick bold line work. Plain pure white background, no text, no
letters, no numbers, no labels, no face, no head, no body, no oval frame, no border, no
frame, no watermark, no drop shadow, no gradients, no realistic shading, square 1:1.
```

Say **a pair of** eyes for every eye cell. The `eyes` node is a single `Sprite2D` centred on the body, so a lone eye lands off-centre.

#### Enemy sprite sheet

```
A sprite sheet of six separate 2D top-down arena roguelite enemy creatures arranged in a
clean 3 by 2 grid with even spacing and identical cell sizes, all seen from directly
above, each one completely separated from the others with plain empty space between them
and nothing overlapping. The six are: a bloated four-legged purple slug monster with a
single huge glossy eye and a drooling mouth, a spiked dark green turtle with a shell of
rusted iron plates, a squat grey goblin with enormous pointed ears and a wide grin, a
floating translucent green jellyfish-like blob with three stubby tentacles, a long
segmented crimson worm with a yellow underbelly and a needle mouth, and a fat orange
toad monster with pustules and a toothy crooked smile. Every shape has a heavy inked black
outline, flat solid muted colour fills, chunky rounded exaggerated cartoon proportions,
thick bold line work, threatening but cartoon and not gory. Plain pure white background,
no text, no letters, no numbers, no labels, no UI chrome, no border, no frame, no
watermark, no drop shadow, no gradients, no realistic shading, no 3d render, no isometric
perspective, square 1:1.
```

Two shape rules for enemies, both learned from the sheet this template produced:

- **Avoid a hole in the silhouette.** The generated worm was a closed curl with the arena floor visible through the middle, while the collision shape is a circle at ~0.4x half-width. Either ask for a shallow S, or accept the mismatch.
- **Avoid translucency.** The generated jellyfish is see-through, so it reads as a hole in the arena rather than a creature.
- **"Seen from directly above" gets ignored for anything humanoid.** Radially symmetric blobs and toads read fine at any angle; a front-facing goblin in a top-down arena looks like it is lying down. Ask for asymmetric top-down silhouettes for anything with a face or limbs.

### Menu background layer

The one asset class that is a whole scene rather than one object. Fill `{layer}` with what the layer is for, then paste the shared style block in so all three match. Keep the shared block **verbatim and identical** across every layer — that is the mechanism, not a stylistic preference.

```
A {layer} of a cartoon desert wasteland arena field, as the {layer} of a parallax game
menu. [describe the contents: what occupies this depth, and that the rest is empty]. Every
shape has a heavy inked black outline with visible hatching and grain lines inside it. Very
simple composition, low detail. Flat even daytime lighting with soft shadow strokes under
every object. Left and right edges are completely empty plain pure white over the outer 15
percent of the width so the layer can slide sideways without showing a hard edge. [SHARED
STYLE BLOCK]
```

SHARED STYLE BLOCK — the **background** variant, paste into all three, unchanged:

```
2D cartoon game art in the style of Borderlands 2 and Tiny Tina's Wonderlands, heavy inked
black outline around every single shape, painterly textured colour fills with visible
brush strokes and cross-hatching, muted dusty frontier palette of pale dusty blue, cream,
charcoal grey, dark olive green and warm tan, chunky exaggerated cartoon proportions, thick
bold line work, flat even daytime lighting, wide landscape composition, no text, no letters,
no numbers, no UI chrome, no border, no frame, no watermark, no drop shadow, no
photorealistic shading, no 3d render, no isometric perspective, no detailed scenery
```

The **sprite** variant is in "Two style blocks" above — swap `painterly textured colour fills with visible brush strokes and cross-hatching` for `completely flat solid colour fills with only one flat darker tone used for shading`.

Four things about this template that are not obvious:

1. **Ask for plain pure white, not transparent.** Asking for "transparent" reliably returns white anyway; asking for it on purpose means the keying is deterministic. The backdrop is keyed back out in post, and the art contains no white of its own, so a white key is safe.
2. **The empty-edge instruction is load-bearing but not sufficient.** State it in the prompt *and* bake the margin in post. Never trust the prompt for the overscan alone; Bing will ignore it and the seam appears the moment the layer drifts.
3. **Say the layer is "not cropped by the edge"** for any object that needs padding around it. Asking for a shape that is deliberately cropped returns one sliced off at the canvas border, which is fatal for a layer that must be padded. A generated mid layer came back with the fence cut mid-post at both edges, which modal-fill grow then smeared into the margin.
4. **Generate the far layer first and approve it before spending on the other two.** If the shared style block is wrong, fix the block. Generating three variations of a wrong look is the mistake the first batch of this art made.

The far layer is the exception to the transparent-margin rule: it is the backdrop, so it is opaque and takes width instead of transparency.

#### Far layer — opaque backdrop

The one layer with a fully written prompt rather than a template. Generated at `3:2`, opaque, canvas at least 1564px wide.

```
A wide empty cartoon desert wasteland arena backdrop, viewed from a low camera angle across
the field. The upper two thirds is a pale dusty blue sky with a warm cream glow low on the
horizon, with four or five big chunky exaggerated cartoon clouds drawn as rounded flat
cream shapes with heavy inked black outlines and short black hatch strokes on their
undersides. Along the horizon there is a distant dark olive green treeline of chunky
rounded cartoon desert trees and bushes, every bush drawn with visible black hatch strokes
inside it, and behind them four or five flat tan mesa rock formations with heavy inked
black outlines and vertical crack lines inside them. Below the horizon the ground is flat
warm tan dirt with a few scattered small dark rocks and sparse dry grass tufts, and long
soft shadow strokes under each object. Nothing in the foreground at all. Very simple
composition, low detail, reads as far away and hazy. The left and right edges are plain
empty sky with no cloud or hill touching them. 2D cartoon game art in the style of
Borderlands 2 and Tiny Tina's Wonderlands, heavy inked black outline around every single
shape, painterly textured colour fills with visible brush strokes and cross-hatching,
muted dusty frontier palette of pale dusty blue, cream, charcoal grey, dark olive green and
warm tan, chunky exaggerated cartoon proportions, thick bold line work, flat even
daytime lighting, wide landscape composition, no text, no letters, no numbers, no UI
chrome, no border, no frame, no watermark, no drop shadow, no photorealistic shading, no
3d render, no isometric perspective, no detailed scenery
```

Three clauses in there are doing specific work and should not be cut when adapting it:

| Clause | Why |
| --- | --- |
| `every bush drawn with visible black hatch strokes inside it`, `vertical crack lines inside them` | The interior-ink rule. Without it the horizon is two flat silhouettes. |
| `Very simple composition, low detail` | Means empty layout, not empty shapes. See "Two rules that are not obvious". |
| `long soft shadow strokes under each object` | Pins the light direction so three separately generated layers agree. |

Do **not** add a sun, light rays, lens flare or a vignette. A first attempt at this layer came back with a bright glow at the horizon centre, which is what turned the sky into a gradient poster and made it clash with the mid layers. The `warm cream glow low on the horizon` is the sanctioned substitute.

### Negative phrasing

Bing rewards explicit exclusions. Keep `no text`, `transparent background`, and `no drop shadow` in every prompt. Add more when the subject invites it:

```
no gradients, no realistic shading, no 3d render, no isometric perspective, no watermark
```

The icon templates no longer ask for a **cel-shaded highlight**. That phrase asks for a light source, and a light source on flat art produces a gradient poster instead of a flat cartoon.

## Workflow

1. Check `F:\programs\Godot projects\Brotato3.6\` first. Mining an existing icon is faster and always more consistent than generating. Note that its art is *flat* — the Borderlands direction above is a deliberate departure from it, so a mined asset and a generated one will not match. That tension is unresolved.
2. Otherwise write the prompt from a template above.
3. Run the `generate-image` skill. It saves to `~/Downloads` as `<prompt-slug>.jpg`.
4. Post-process outside the repo: cut out the background, resize to the exact canvas, export lossless PNG. For a **menu background** this is a simple resize to 1564x1042 (no keying or overscan needed since it's a single static layer). For a **sprite sheet** this step is not scripted yet. It needs per-cell bounding-box detection rather than a fixed slice, per "Sprite sheets" above.
5. Move into the repo at the exact path from the asset-class table. Godot generates the `.import` on next open.
6. Wire the asset up: stat and modifier icons are found by filename, weapons and characters need the `sprite` / `small_icon` field set on the `.tres`.
7. Verify visually. Item icons only appear in `res://test/tools/shop_ui_preview.tscn`:

   ```
   .\run_scene_shot.bat res://test/tools/shop_ui_preview.tscn res://shop_shot.png
   ```

   Character icons only appear in `res://test/tools/character_ui_preview.tscn`. Neither fixture picks up a new asset unless it is added to the fixture's `SAMPLE_ITEMS`.

   The menu background can be checked directly on the main menu:

   ```
   .\run_scene_shot.bat res://src/Scenes/menu/Main.tscn res://menu_shot.png
   ```

   **Weapons, enemies and character bodies can only be judged in-game.** They render at 80x80 and 100x100; a sheet that looks great at 1024px can turn to noise on the way down. Check detail level at size before rejecting art, and check the title's legibility over the far layer's pale sky at the same time.

8. Delete the screenshot PNGs afterwards, they are scratch output and not committed.

## Known gaps

- Only **2 of 25** modifier scenes have a matching icon — `BombOnHitModifier` and `SpinningOrbsModifier`. The other 23 all fall back to `_default.png`.
- **9 icons in `src/Assets/modifiers/` are orphaned**, because their names do not match any scene basename: `armormode` (a typo for `armormodifier`), `coil_icon`, `dynamite_icon`, `fairy_icon`, `glass_cannon_icon`, `rocket`, `shuriken`, `torch`. Either rename them to the lowercase scene basename or delete them.
- `Thorns.tres` has no `sprite` at all.
- `DeathAura.tres` borrows `circular_saw.png`, which suits the aura behaviour but is not a Death Aura icon of its own.
- **There is no per-character body.** Every character shares `src/Assets/character/potato.png`, hardcoded in `src/Systems/Character.tscn`. Generated bodies exist but are not wired, and adding them means changing the scene to point at a per-id texture. Not started.
- **No arena props.** `src/Assets/tiles/` is a single tile sheet. A generation run intended for the mid layer ignored the empty-upper-two-thirds instruction and produced a clean prop sheet instead — crates, dry trees, barrels, rocks, fence panels — which is on-style and currently the only arena decoration the project has. Worth promoting to a real asset class.
- **No custom font.** Everything uses the Godot built-in. Brotato used `Anybody-Medium.ttf` if a font is ever needed.
- **No shaders anywhere in the project.**
- **The main menu title will lose legibility** against the far layer's pale sky, now that the dark full-rect scrim has been deleted. The fix is a scrim behind the `VBoxContainer` only, not a full-rect one.
- **Mined Brotato art and generated Borderlands art will not match.** The decompile is flat with almost no texture; the direction above is painterly. Every asset in `src/Assets/` today is mined, so the project currently has no art in its own style.

## Reference art

Generated art from the sessions that settled these prompts is kept under `docs/plans/images/`, with accepted far-layer candidates in `docs/plans/images/far_layer/`. It is reference material for judging a new generation, not shipped art. `docs/plans/` is otherwise a retired tree — see `test/test_doc_links.gd`, which fails if `docs/ai_overview.md` points at it.

## Where the values come from

| Fact | Source |
| --- | --- |
| UI colors, panel stylebox | `src/ui/item_display_panel.gd:17-28`, `make_panel_stylebox()` |
| Stat icon lookup | `src/Systems/stats/stats.gd:203-207` |
| Modifier icon lookup | `src/ui/ItemIconGenerator.gd:22-32` |
| Icon display sizes | `src/ui/IconCard.tscn`, `src/ui/ItemDisplayPanel.tscn`, `src/ui/TooltipUi.tscn`, `src/ui/icon_card.gd`, `src/ui/BuffTile.tscn` |
| Buff / debuff border colours | `src/ui/buff_tile.gd` (`COLOR_POSITIVE` / `COLOR_NEGATIVE`, gold on hover) |
| Buff tile duration arc | `src/ui/buff_arc.gd` — the first `CanvasItem` custom `_draw()` in the UI layer |
| Card plates | `src/Scenes/menu/ShopItemCard.tscn:6-54` |
| Tone semantics | `docs/systems/ui_shop_portal.md`, `docs/systems/modifiers.md` |
| Character body / eyes / mouth / legs composition | `src/Systems/Character.tscn:36-66` |
| Art provenance | `src/Systems/arena.gd:1-15` |
| Naming convention | `hidden.txt` at repo root |
| Art outline share and saturation | sampled directly from the shipped PNGs; see the table under "The art palette" |
