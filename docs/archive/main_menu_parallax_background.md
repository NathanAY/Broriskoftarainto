# Main menu parallax background

Status: all seven steps done. Steps 4-7 are described below as they were actually carried out, which differs from the original plan in several places, each noted inline. One thing is still open: the staged `.jpg` files in `src/Assets/menu/` should be deleted once the art is backed up off this machine.

## Goal

Replace the flat translucent black `ColorRect` in `src/Scenes/menu/Main.tscn` with a layered background that drifts on its own and leans slightly with the mouse. Three layers, far to near.

**Iteration 1 scope:** the rig plus three moving layers. `TitleLabel` and the three buttons stay exactly as they are. No button restyle, no logo, no layout change.

## Non-goals

- Mouse *follow* parallax where the scene only looks alive while the mouse moves.
- Matching Brotato's art. This is our own background.
- Any change to `project.godot` display settings (see the resolution decision below).
- Reusing the parallax rig for the arena. It is a menu-only rig.

## Is "generate the art first" the right order?

No, not as the first step. Two reasons, both of which this plan works around rather than argues with.

1. **The art contract depends on the rig, not the other way round.** How far each layer travels decides how much transparent overscan the PNG needs baked into its edges. Generate art first and you either regenerate it when the sway numbers change, or you ship a background that shows a hard edge when it drifts.
2. **Bing output is not usable as-is.** The skill downloads a `.jpg`. JPEG has no alpha channel, so layers 2 and 3 cannot composite over layer 1 until the background is cut out by hand. `docs/visual_style.md` already lists this as step 4 of its workflow ("post-process outside the repo"), and for three full-canvas layers that is the most expensive part of the task, not the generation.

So the order is **rig first with flat placeholder rectangles, tune the motion, then generate art to a spec the rig already defines.** Generation still happens, just not first.

## Current state

| Fact | Where |
| --- | --- |
| Root is a `CanvasLayer` with a full-rect `Control` | `src/Scenes/menu/Main.tscn:7-15` |
| Background is one `ColorRect`, `Color(0, 0, 0, 0.6)` | `src/Scenes/menu/Main.tscn:18-25` |
| Buttons live in `Control/VBoxContainer`, paths are hard-coded | `src/Scenes/menu/main_menu.gd:3-5` |
| Viewport is 1552x861 | `project.godot:36-37` |
| `display/window/stretch/mode` is `disabled` | `project.godot` (queried via `ProjectSettings`, not written in the file) |
| No `Parallax*` node exists anywhere in the project yet | grep for `Parallax` is empty |

`stretch/mode=disabled` means the viewport resizes to the real window and nothing is scaled. A `Control` anchored full-rect still tracks the window, so a `ColorRect` background is safe at any size — but a fixed-size `TextureRect` background will letterbox or show its edge the moment the window is dragged. That is the one real technical constraint on this task and it is handled in the cover-fit step below.

## Layer stack

Three layers, plus the existing UI on top. Values are starting points, not decisions.

| Layer | Travel (px) | Mouse (px) | Margin | Period | Phase | Art |
| --- | --- | --- | --- | --- | --- | --- |
| `FarLayer` | 24 | 8 | 32 | 14.0 s | 0.0 | **Opaque** backdrop: sky and far silhouettes. Moves least. |
| `MidLayer` | 48 | 14 | 62 | 10.0 s | 0.35 | Transparent: ground plane, mid props. Horizon anchor. |
| `NearLayer` | 84 | 22 | 106 | 7.0 s | 0.7 | Transparent: foreground framing, cropped by the screen edge. |

Margin is travel plus mouse nudge, and it is what the cover-fit reserves slack for. See "Cover-fit and overscan".

Rules that make it read as depth rather than as three things sliding:

- **Different periods, not different amplitudes only.** Same period with different amplitude looks mechanical. Coprime-ish periods make the loop long enough that the pattern does not visibly repeat.
- **Far layer drifts more slowly than near.** Amplitude and period both increase toward the camera.
- **Sway is horizontal only.** Vertical drift on a background layer reads as a bug or a camera bob, not as parallax.
- **Easing dwells at the turns.** The sway is a ping-pong run through a smoothstep, so its velocity is zero at each end: a layer arrives slowly and leaves slowly. A linear ping-pong reads as a stutter, an un-eased one as a bounce. *Note: this section originally specified asymmetric time-warped easing; a symmetric smoothstep already produces the dwell that the rule was after, so the implementation is the simpler curve and this line is the corrected wording.*

Mouse nudge is additive on top of sway, eased toward the mouse so it never snaps. Each layer's `set_shift` clamps the sum to its own margin, so the mouse cannot push a layer past the slack the cover-fit reserved.

## Cover-fit and overscan

This is the crux, and it is the reason art comes after the rig.

Each layer is a `Control` anchored full-rect that covers the window at any aspect. The texture is fitted by cover semantics, but against the window **plus twice the layer's margin**: `cover_fit()` folds the margin into the width the fit must satisfy, then centres. Centring is what splits the slack evenly between the two sides. Fitting to the bare window and offsetting by hand puts all the slack on one side, and the layer uncovers a gap the moment it travels the other way.

**The far layer is the exception, and the first draft of this plan got it wrong.** It is opaque — it is the backdrop, nothing is behind it — so it needs no transparent margin. It needs to be *wider* than the window instead. Only `MidLayer` and `NearLayer` need transparent margins, and only at the left and right edges; there is no vertical sway, so the top and bottom are covered by the fit alone.

| Layer | Canvas must be at least | Left/right margin |
| --- | --- | --- |
| `FarLayer` | `required_art_width(1552, 32)` = 1616 px | none, it is opaque |
| `MidLayer` | `required_art_width(1552, 62)` = 1676 px | 62 px transparent |
| `NearLayer` | `required_art_width(1552, 106)` = 1764 px | 106 px transparent |

The 1764 px figure is the number that governs every layer. This plan originally said 1720 px, which was wrong twice: it ignored the mouse nudge (44 px short for the near layer) and it assumed the far layer needed transparency it does not need.

Generation produces neither the required width nor the transparent margins. Bing's 16:9 output is roughly 1344x768, narrower than the project's 1552 px viewport, so every layer is upscaled in post — about 1.15x on screen for the far layer and 1.31x for the near layer. Tolerable for flat cartoon fills, not for thin line work. Both the upscaling and the transparent margins are step 4, and both are why the rig has to be settled first.

## Planned files

```
src/Scenes/menu/Main.tscn                    edited: layer stack inserted behind Control
src/Scenes/menu/main_menu.gd                 edited: owns the sway + mouse drive
src/ui/menu_parallax_layer.gd                new: one layer, cover-fit + overscan
src/Assets/menu/parallax_far.jpg             raw Bing output, opaque backdrop, staging
src/Assets/menu/parallax_mid.jpg             raw Bing output, still needs keying, staging
src/Assets/menu/parallax_near.jpg            raw Bing output, still needs keying, staging
src/Assets/menu/parallax_far.png             step 4: the file the scene actually loads
src/Assets/menu/parallax_mid.png             step 4
src/Assets/menu/parallax_near.png            step 4
test/Systems/menu/test_menu_parallax.gd      new: 26 cases
test/tools/menu_parallax_preview.tscn       new: visual check, one layer per cell
test/tools/menu_parallax_preview.gd        new
test/tools/parallax_postprocess.gd         new: step 4, the art build
```

The `.jpg` files are the raw Bing downloads, moved out of `~/Downloads` and renamed to `snake_case` so they are tracked and identifiable. **They are staging, not assets.** They are 1248x832, `Format24bppRgb`, no alpha, no overscan, and named after the prompt. Nothing references them; `Main.tscn` holds the processed `.png` files. They are still in the repo and should be deleted once the art is backed up somewhere off this machine — see step 4.

`main_menu.gd` already exists and already owns the menu's behaviour, so the sway driver belongs there rather than in a new autoload. It now also grows the mouse tracking. It is 62 lines, which is at the split threshold this plan set, so the next change that touches the menu should move the parallax driver into its own script rather than add to it.

The test suite lives at `test/Systems/menu/`, not in a `ui` folder as first drafted, because `test_main_menu.gd` is already there and a second menu suite in a different folder would be found by neither a reader nor the fuzzy runner.

### The preview fixture, and why the menu render cannot do this job

The menu cannot verify its own background. All three layers are full-bleed, so the one in front hides the ones behind — correct for the finished art, where the near layers are transparent PNGs with sparse content, and useless for the rig, where each layer is a flat rectangle. Three stacked translucent rectangles composite to one muddy colour.

`test/tools/menu_parallax_preview.tscn` gives each layer its own clipped full-bleed cell and pins it to the extreme of its travel, alternating direction, so one render shows both the left-edge and right-edge risk at the exact shift where a gap first appears. Clipping is load-bearing rather than cosmetic: an over-fitted layer is larger than its cell, and without `clip_contents` the overflow spills across the window and repaints the neighbouring cells.

## Steps

Each step ends in something you can look at. Do not start step N+1 until step N is verified.

### Step 0 — Rig with placeholders, no art — done

Three full-rect `MenuParallaxLayer` nodes inserted before the existing `Control`, each with a flat `ColorRect` placeholder, driven from `main_menu.gd`.

The placeholders are **not** all 60% alpha as first specified. The far layer is opaque and the two in front of it are translucent, because three translucent layers over black composite to a single muddy colour and the stack cannot be read off a render at all — which defeats the entire reason for checking on flat colours. A backdrop has nothing behind it, so opaque is also what the finished art will be.

One thing the render cannot do, and the reason a preview fixture was needed: the menu cannot show its own background. All three layers are full-bleed, so the one in front hides the ones behind. Correct for finished art, useless for the rig.

### Step 1 — Cover-fit the layers to the window — done

`cover_fit()` in `src/ui/menu_parallax_layer.gd` fits to the window plus twice the layer's margin, then centres; the layer refits off its own `resized` signal, which is the only signal that the window changed shape given `stretch/mode=disabled`.

Verified two ways. `test_no_gap_at_every_edge_across_the_whole_sway_range` sweeps 65 shifts across the full travel for three layers at five window sizes, including one far taller than 16:9, and asserts no gap at any of the four edges. And `test/tools/menu_parallax_preview.tscn` renders all three layers at once, one per clipped cell, pinned to the extreme of their travel in alternating directions. Its cells are a 0.63 aspect, so the height-driven direction — the one a width-only fit would get wrong — is the one being looked at.

### Step 2 — Write the prompts — done

One prompt per layer, from `docs/visual_style.md` templates. That file's templates are all `1:1` for isolated objects on transparent backgrounds; a menu background layer is a new asset class and needs its own template, a `16:9` aspect ratio in the Bing composer, and one prompt that is deliberately *not* transparent. Both changes to `docs/visual_style.md` belong in step 7, not silently in a prompt file.

The theme is a flat cartoon arena field in daylight, matching the shipped art rather than inventing a mood. The existing assets are flat mid-brown dirt with tiny near-black-outlined rocks and dark-olive plants, charcoal weapons, a muted purple enemy and pale cream characters, so the background is built from the same vocabulary: dirt brown, tan, charcoal, dark olive green and cream, all under a very heavy near-black outline.

*Corrected after the first generation.* The theme was originally a dusk farm field with a low sun. That produced three layers in three different lights — a sunset sky, a flat daytime strip and a near-black silhouette — which read as unrelated images stacked. It also put the near layer at the opposite end of the palette from everything else in the project. Everything is flat daytime now.

#### Shared style block

Paste verbatim into all three. Any change here changes all three, which is the point — it is what keeps the layers matched.

```
cartoon style background in the style of a brotato-like arena game, thick near-black
outline around every single shape, completely flat solid colour fills, no gradients, no
soft shading, no glow, no bloom, muted desaturated earthy palette of dirt brown, tan,
charcoal grey, dark olive green and cream, simple chunky rounded cartoon shapes, thick
bold lines, flat daytime lighting, wide landscape composition, no text, no letters, no
numbers, no UI chrome, no border, no frame, no watermark, no drop shadow, no realistic
shading, no 3d render, no isometric perspective, no detailed scenery
```

Mode: `Vivid and natural`. Aspect ratio: **`3:2`**, because `16:9` does not exist — Bing offers only `1:1`, `3:2` and `2:3`. See the corrections below.

#### Why the style block changed after the first generation

The first attempt followed `docs/visual_style.md` literally — "flat saturated fills with a hard cel-shaded highlight", and its palette table's "keep fills bright". It produced bright saturated sunset art that matched neither the other two layers nor the shipped game. Three specific causes:

1. **The doc describes the wrong palette.** It claims "enemy and weapon art in the project is more saturated than this list". The shipped art is the opposite: `src/Assets/tiles/tiles_1.png` is flat mid-brown dirt with near-black rocks, `src/Assets/weapons/pistol.png` is charcoal, `src/Assets/enemies/spitter.png` is muted purple, and the potato and brawler are pale cream. Every one of them is desaturated with a very heavy near-black outline. Saturated brights belong to the **UI**, not the art. Correcting that line in `docs/visual_style.md` is step 7 work.
2. **"Cel-shaded highlight" and "dusk lighting" fought each other.** A glowing low sun produced a soft gradient poster, not a flat cartoon. The block now says *completely flat*, and the scene is flat daylight.
3. **Three different times of day.** The old block asked for dusk; the far layer came back sunset, the mid layer came back flat daytime, and the near layer came back a near-black moody silhouette. A parallax stack has to agree on the light or it reads as three unrelated images. Everything is now flat daytime, same direction.

Two further fixes came out of the first batch: the near layer's "cropped hard by the frame" phrasing produced a tree sliced off at the canvas edge, which is fatal for a layer that must be padded; and asking for "transparent" reliably returns **white**, so the prompts now ask for white on purpose and step 4 keys it out.

#### Far layer — opaque backdrop

```
A wide empty cartoon arena backdrop, viewed from a low camera angle across the field.
The upper two thirds is a completely flat pale cream and light dusty blue sky with three
or four simple chunky rounded cartoon clouds. Along the bottom third there is a distant
flat dark olive green treeline and low hills, drawn as one simple silhouette shape with
a thick near-black outline. Nothing in the foreground at all, the whole area below the
treeline is flat empty tan dirt ground. Very simple, low detail, low contrast, reads as
far away. The left and right edges are plain empty sky with no cloud or hill touching
them. [STYLE BLOCK]
```

Opaque, full bleed, no transparent margin. Canvas at least 1616 px wide.

#### Mid layer — white keyed to transparent, horizon anchor

```
The middle distance of a cartoon arena field, as the middle layer of a parallax game
menu. A low flat wooden fence running horizontally across the frame, with a few chunky
rounded cartoon bushes and small dark rocks sitting on flat tan dirt ground, plus one
simple round cartoon hay bale. The whole upper two thirds is completely empty plain
pure white with nothing in it at all. Every shape has a thick near-black outline. Simple
chunky shapes, only a handful of them, lots of empty space. Left and right edges are
completely empty plain pure white over the outer 12 percent of the width so the layer
can slide sideways without showing a hard edge. [STYLE BLOCK]
```

White keyed to transparent. Canvas at least 1676 px wide, outer 62 px fully transparent on both sides.

#### Near layer — white keyed to transparent, foreground framing

```
The immediate foreground of a cartoon arena field, as the near layer of a parallax game
menu. Only a fringe of chunky rounded cartoon grass tufts in muted dark olive green
along the very bottom edge, and two simple rounded cartoon boulders in flat tan sitting
at the bottom left and bottom right corners, each one fully inside the frame with clear
empty space around it, not cropped by the edge and not touching the border. Everything
above the bottom quarter is completely empty plain pure white with nothing in it at all.
Every shape has a thick near-black outline. The same muted colours as the rest of the
scene, not darker, not a silhouette. Left and right edges are completely empty plain
pure white over the outer 15 percent of the width so the layer can slide sideways
without showing a hard edge. [STYLE BLOCK]
```

White keyed to transparent. Canvas at least 1764 px wide, outer 106 px fully transparent on both sides.

#### Order of work

Generate the far layer first and check it before spending credits on the other two. If the shared style block does not produce the look, fix the block rather than generating three variations of a wrong look — that is exactly the mistake the first batch made.

Expect Bing's `3:2` output at 1248x832, narrower than the project's 1552 px viewport, so every layer is upscaled in step 4: about 1.30x for the far layer and 1.41x for the near one.

### Step 3 — Generate — done

Run the `generate-image` skill once per layer. Save to `~/Downloads`, confirm each file landed, and check the file sizes differ so you know you did not download the same image three times.

### Step 4 — Post-process — done

Done by `test/tools/parallax_postprocess.gd`, run headless:

```
godot --headless --script res://test/tools/parallax_postprocess.gd
```

A Godot script rather than a Python one because this machine has neither Python nor ImageMagick installed, and Godot is already the thing that has to read the result. It is not named `test_*.gd`, so the runners skip it.

Two decisions differ from what this plan originally specified:

1. **Grew the width by modal fill rather than upscaling.** The plan called for an upscale to 1616/1676/1764 from Bing's 1248. Each row is instead filled out to 1552 px with *that row's most common pixel*, then the transparent overscan is added outside it. This is strictly better on both counts the plan was worried about: the art keeps its native pixels so the outlines stay crisp instead of going soft, and the horizontal features the plan wanted extended anyway — the fence, the ground bands, the grass — continue rather than being resampled and then sliced. It also generalises the fence-extension bullet the plan called out separately, so that is no longer a special case. A feature occupying only part of a row, like a fence post or a boulder, is left alone rather than smeared into the margin.
2. **The far layer gets width, not transparency.** As the plan already concluded, it is opaque and needs no transparent margin; all 32 px of its margin is grown content. Mid and near each get 152 px grown plus 62/106 px transparent.

Result, all three hitting `required_art_width` exactly: far 1616x832, mid 1676x832, near 1764x832.

The white key runs on a pixel's darkest channel between 224 and 246, unpremultiplying inside that band so edges do not get a white rim. The generated background sits at 248-255 and the palest real content is the fence rail at 172, so the gap between them is wide and nothing gets punched out by accident.

**The `.jpg` files are still in place.** The plan says to delete them after step 4, and they should go eventually, but `~/Downloads` only holds the *discarded* dusk batch — these three are the only copy of the accepted art on the machine, and the tool cannot be re-run without them. Back them up somewhere first.

### Step 5 — Wire the art in — done

Each `ColorRect` placeholder became a `TextureRect` with `expand_mode = EXPAND_IGNORE_SIZE` and `stretch_mode = STRETCH_SCALE`. Not `KEEP_ASPECT_COVERED`: `cover_fit` already returns a rect at exactly the texture's aspect ratio, so plain scale is what actually applies cover semantics here, and asking the TextureRect to do it a second time only adds a mode that could disagree with the fit.

**The `Control/ColorRect` 60% black scrim was deleted.** It is the flat backdrop this whole plan set out to replace, and at 0.6 alpha over daylight art it turned the whole menu into a bruise. The title and buttons were not restyled, so the pale title now sits on cream sky — legible, but only because the art is light. If it stops being legible, the fix is a scrim *behind the VBoxContainer only*, not the full-rect one that was here.

Seams re-verified: `menu_parallax_preview.tscn` now loads the real textures instead of flat fills, and one render at the extreme of each layer's travel in alternating directions shows no gap at any edge in any cell.

### Step 6 — Tests and visual check — done

26 cases in `test/Systems/menu/test_menu_parallax.gd`, up from 22. All 427 project tests pass.

The two placeholder tests were replaced rather than kept, because iteration 1 no longer has placeholders — asserting a `ColorRect` where a texture now lives would fail on purpose. In their place:

- every layer's `Art` is a `TextureRect` with a non-null texture, so a missing asset fails loudly instead of rendering as a flat rectangle that looks deliberate
- `expand_mode`/`stretch_mode` are what the fit needs
- **each texture is at least `required_art_width(VIEWPORT.x, layer.margin)` wide**, asserted against the shipped pixels rather than a number in a table
- the mid and near layers' outer `margin` columns are fully transparent on both edges — if that regresses the sway shows a hard edge
- the far layer has no transparent sample points, since it is the backdrop
- the artwork is positioned and sized by the cover-fit, and the fit sizes from the texture

Two existing tests had to change. `test_no_gap_at_either_edge_across_the_whole_sway_range` and `test_shift_never_moves_a_layer_vertically` computed their expected fit from `placeholder_size`, which is now wrong — they use `art_size()`. That failure was real signal: it is exactly the class of bug where a layer is checked against a canvas it no longer has.

The size assertion is approximate to a pixel, not exact. Godot rounds a `Control`'s size to whole pixels and `cover_fit` divides, so exact equality is not achievable and was never the claim.

Visual check done, PNG deleted afterwards:

```
.\run_scene_shot.bat res://src/Scenes/menu/Main.tscn res://menu_shot.png
.\run_scene_shot.bat res://test/tools/menu_parallax_preview.tscn res://parallax.png
```

### Step 7 — Docs — done

`docs/visual_style.md`:

- **New "Menu background layer" asset class** with the path, all three canvases, and the four facts that make it unlike every other class: not square and not one size, generated at `3:2` and post-processed, two of three keyed rather than cut out, and one shared style block pasted verbatim across all three prompts. It points at `test/tools/parallax_postprocess.gd` as the build step and notes that the widths are asserted against the shipped PNGs by `test/Systems/menu/test_menu_parallax.gd`, so changing a layer's travel means rebuilding its art.
- **New prompt template** for that class, with the shared style block as a separate paste-once block and the four non-obvious rules: ask for plain white rather than transparent, state the empty edge *and* bake the margin, never ask for an edge-cropped object, and generate the far layer first.
- **Corrected the palette section**, which was the doc bug this whole plan tracked. It now separates the UI palette (bright, semantic, from code) from the art palette (desaturated, heavy outline), and the art claims are measured rather than asserted. See below.
- **Corrected the blanket `1:1` aspect-ratio instruction**, which was wrong in two directions: the icon templates do want `1:1`, but Bing has no `16:9` at all — only `1:1`, `3:2` and `2:3` — so the menu template uses `3:2` on purpose. The Canvas row in the constraints table no longer says "square".
- **Dropped "cel-shaded highlight"** from the icon templates and noted why. It asks for a light source; a light source on flat art produces a gradient poster. Following it is part of what caused the discarded first batch.
- Workflow steps 4 and 7 gained the scripted build command and the menu-layer preview fixture, with the reason the menu cannot check its own background.
- Three new entries under "Known gaps": the staged `.jpg` files, the unproven near layer, and the unconfirmed behaviour of `3:2` for non-menu assets.

`docs/ai_overview.md`: one row for `docs/visual_style.md` in the orientation table, widened to mention the two palettes and menu background layers. No row for this plan — the link test asserts the index never mentions the plans directory, and it only indexes the systems and decisions trees.

`test/test_doc_links.gd`: removed six stale allowlist entries. Four named the parallax files as "not yet written", and one named a test path under a `ui` folder that was drafted before the suite moved to `test/Systems/menu/` and never existed there. The allowlists exist to excuse names a doc cites that are deliberately not on disk; keeping entries for files that now exist would stop the suite from catching a rename.

Move this file to `docs/archive/` when the work ships, and drop its rows rather than editing them.

## What the palette correction changed

The doc's claim that shipped art is "more saturated" than the UI list was not a judgement call to be argued about, so it was measured. Sampling every other pixel of four shipped assets:

| Asset | Near-black outline | Mean saturation of non-outline pixels |
| --- | --- | --- |
| `src/Assets/tiles/tiles_1.png` | 4.3% | 25.9% |
| `src/Assets/weapons/pistol.png` | 64.0% | 19.3% |
| `src/Assets/enemies/spitter.png` | 48.7% | 36.3% |
| `src/Assets/character/brawler/brawler_icon.png` | 36.9% | 28.4% |

19-36% saturation is muted by any measure, and two-thirds of the pistol is near-black line work. The doc said "keep fills bright" and that the art was more saturated than the UI palette; the shipped art is neither. The generated menu background measured 16-36% against the same definition, which is the check that confirmed it belongs to this project.

The probe was throwaway and has been deleted; the numbers live in the doc.

## Risks

| Risk | Why it hurts | Mitigation |
| --- | --- | --- |
| Bing returns solid backgrounds | Mid and near layers cannot composite over far | Cut out by hand, step 4. Unavoidable with JPEG. |
| Layers generated separately do not match | Reads as three unrelated images stacked | One shared style block across all three prompts; generate far first and approve before spending the rest. **This happened on the first batch** — three layers came back in three different lights. Fixed by naming Brotato, pinning flat daytime, and dropping "cel-shaded". |
| Bing ignores the overscan instruction | Hard seam appears the moment a layer drifts | Bake the transparent margin in post, step 4. Never trust the prompt for this. |
| The mid layer's fence runs full-bleed | Padding it leaves the fence chopped in mid-air at both ends | Extend the rail pixels into the margin in step 4. Not regenerating for it. |
| Upscaling 1248 px art to 1764 px | Softer outlines than the shipped icons | Accepted. Flat fills survive it; thin line work would not, so keep shapes chunky. |
| Amplitudes and periods are guesses | Motion may be wrong in a way that is obvious once art is in | Step 0 exists to be iterated with flat colours. |
| Cover-fit misjudges aspect | Letterbox or gap | Step 2 verifies across aspect ratios before any art exists. |
| `main_menu.gd` grows two jobs | Navigation and animation coupled | Split the driver out if it passes roughly 60 lines. |

## Known doc bug found along the way — fixed in step 7

`docs/visual_style.md` described the art palette as bright and saturated, and stated that "enemy and weapon art in the project is more saturated than this list". The shipped art is the opposite, and the numbers are in "What the palette correction changed" above. Following the doc as written is what produced the discarded first batch. It has been corrected.

## Reference

Brotato 3.6 does this exact effect and the decompile is on this machine at `F:\programs\Godot projects\Brotato3.6\ui\menus\title_screen\title_screen_background\`. Worth opening as a reference even though the art is not being reused: six layers at 2070x1080, of which four are the background stack, each a full-canvas texture rather than a cropped strip, animated by `AnimationPlayer` sliding `rect_position` horizontally by up to 150px over 6 seconds with the front and back mist layers running in opposite phase.

Two things it confirms and this plan adopts: travel is horizontal only, and opposite-phase layers read as depth. One thing it does not answer: its mist layers are opaque edge to edge, so it appears to lean on the 2070-wide canvas against a ~1920-wide viewport for slack rather than on transparent overscan. This plan uses transparent overscan, which is more robust at a window size nobody chose.

## Open questions

1. Should the near layer be blurred? Brotato's front mist reads as depth-of-field. In-engine that means a `BackBufferCopy` plus a blur shader, and `docs/visual_style.md` records that the project has no shaders at all. Cheap to skip for iteration 1. Note the new near layer is a bright foreground fringe, not a mist, so blur may not even be wanted.
2. Should sway respect a reduced-motion accessibility setting? Not currently in the project.
3. `src/Assets/tiles/tiles_1.png` already exists and is an on-style arena floor. Could the far layer reuse it as a starting composition instead of generating one? It is a tile sheet, not a backdrop, so it likely cannot, but it is free to look at. The generated far layer's dirt band is close to it in colour, which is why the three read together.
4. The near layer is now a bottom-edge fringe of grass and two boulders rather than a framing device. It may not register as a distinct depth at 84 px of travel. Worth looking at it in place before deciding whether it earns its layer.