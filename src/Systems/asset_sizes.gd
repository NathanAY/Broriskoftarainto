class_name AssetSizes

## The size each art class is drawn at in game, in pixels.
##
## A source PNG keeps its authored resolution and is scaled to its class size at
## draw time, the way `src/Assets/portal.png` already works: a 512px enemy sprite
## and a 100px one are the same creature on screen. Never re-export a file down to
## the size it is drawn at - that throws away the detail the minification needs,
## and it is why the first 96px portal bake read as soft.
##
## The canvas proportions these sizes describe live in the asset-class table in
## `docs/visual_style.md`; this file is where the drawn size itself lives.

## The roster canvas. Every enemy sprite is drawn on a 100px square whatever its
## file resolution, so the shared body collider stays matched to the art.
const ENEMY_SPRITE := 100.0

## The character canvas: the body and the face parts are authored on it. A body
## wider than this is scaled down to it in the scene.
const CHARACTER_SPRITE := 150.0

## The boss is a larger canvas and is drawn at its own size.
const BOSS_SPRITE := 225.0

## The widest a weapon sprite is drawn while orbiting its holder. A wider source
## is scaled down to this; a narrower one keeps its own size (the 80px pistol
## predates this constant and is unchanged), so a high-resolution weapon needs no
## per-weapon scale. Matches the pistol's canvas.
const WEAPON_SPRITE := 80.0

## The canvas a modifier / effect icon is authored on. The UI draws the same art
## smaller (36 tooltip, 48 item panel, 64 card), so a source at or above this is
## only ever minified.
const MODIFIER_ICON := 96.0


## Uniform scale that draws `texture` `drawn_size` pixels across.
static func scale_for(texture: Texture2D, drawn_size: float) -> float:
	if texture == null or texture.get_width() <= 0:
		return 1.0
	return drawn_size / float(texture.get_width())
