extends Control
class_name MenuParallaxLayer

## One layer of the main menu's parallax background stack.
##
## A layer is art that does two things at once: it covers whatever window it is
## in, and it slides sideways. Each is trivial alone; together they are the whole
## problem. Art fitted to cover a window is exactly as wide as that window, so
## the first pixel of sway uncovers a gap down one side. The fix is to fit
## against the window *plus the layer's entire horizontal travel*, and every
## other decision here follows from that.
##
## So a layer needs:
##   - art wider than the window by twice its travel, with transparent margins
##     baked into the left and right edges, or the sway shows a hard seam
##   - horizontal-only motion; vertical drift reads as a camera bob, not depth
##   - a period different from its neighbours', or three layers read as one
##     rigid object wobbling
##
## The maths is static and takes plain numbers so it can be asserted without a
## viewport. See test/Systems/menu/test_menu_parallax.gd.
##
## Until the artwork exists the `Art` child is a flat `ColorRect` laid out by
## the same fit. That is deliberate: a cover-fit mistake shows up as a gap, and
## a gap is far easier to see on a solid rectangle than on artwork.

# --- motion -----------------------------------------------------------------

## Pixels of sway travel at one end of the cycle. Set per layer, increasing
## toward the camera.
@export var travel: float = 48.0:
    set(value):
        travel = maxf(0.0, value)
        _apply()

## Seconds for one full out-and-back cycle. Different per layer.
@export var sway_period: float = 10.0:
    set(value):
        sway_period = maxf(0.001, value)
        _apply()

## Fraction of the cycle this layer starts at, 0.0 to 1.0. What keeps
## neighbouring layers out of step.
@export var sway_phase: float = 0.0

## Extra horizontal shift at the mouse's full deflection. Small enough that the
## mouse never reverses the sway.
@export var mouse_travel: float = 14.0

## Seconds for the mouse offset to reach its target. Never zero, so the layers
## lean after the cursor instead of snapping to it.
@export var mouse_follow: float = 0.35

# --- art --------------------------------------------------------------------

## The canvas size to fit when `Art` has no texture yet.
@export var placeholder_size: Vector2 = Vector2(1920, 1080)

## Art is a `TextureRect` once it exists and a `ColorRect` until then. Both are
## `Control`s, and the same fit drives either.
const ART_PATH := "Art"

var _shift: float = 0.0

## Total horizontal excursion this layer can reach, sway plus mouse. The
## cover-fit reserves this much slack on *each* side, and the art has to be wide
## enough to pay for it.
var margin: float:
    get:
        return travel + mouse_travel


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    # A full-rect Control under a CanvasLayer resizes with the window, and the
    # viewport has no stretch mode set, so this is the only signal that the
    # window changed shape.
    resized.connect(refit)
    refit()


# --- geometry ---------------------------------------------------------------


## The rect the art should occupy, at the current shift, in the layer's local
## coordinates. The layer is full-rect and un-offset, so these are viewport
## coordinates.
func art_rect() -> Rect2:
    var fitted := cover_fit(art_size(), size, margin)
    return Rect2(fitted.position + Vector2(_shift, 0.0), fitted.size)


## Size of the art being fitted: the texture's own size once there is one, and
## the placeholder canvas until then.
func art_size() -> Vector2:
    var art := get_node_or_null(ART_PATH) as TextureRect
    if art != null and art.texture != null:
        return art.texture.get_size()
    return placeholder_size


## Fit `art` over `viewport` so that it still covers the viewport after sliding
## `margin` pixels in *either* direction.
##
## This is the load-bearing function. `margin` is folded into the width the fit
## has to satisfy, so the returned rect is always at least `margin` wider than
## the viewport on each side once it is centred. Centring is what splits that
## slack evenly; fitting to the bare window and then offsetting by hand is how
## the slack ends up on one side only.
static func cover_fit(art: Vector2, viewport: Vector2, margin: float) -> Rect2:
    if art.x <= 0.0 or art.y <= 0.0:
        return Rect2(Vector2.ZERO, viewport)
    var slack := maxf(0.0, margin)
    var needed := Vector2(viewport.x + slack * 2.0, viewport.y)
    var scale := maxf(needed.x / art.x, needed.y / art.y)
    var shown := art * scale
    return Rect2((viewport - shown) * 0.5, shown)


## How wide the art has to be so that a layer with this margin can cover the
## window at both ends of its travel. The number the artwork is padded to.
static func required_art_width(viewport_width: float, margin: float) -> float:
    return viewport_width + maxf(0.0, margin) * 2.0


# --- motion -----------------------------------------------------------------


## Sway offset in pixels at `elapsed`, including this layer's phase.
func sway_at(elapsed: float) -> float:
    return sway_offset(travel, sway_period, elapsed + sway_phase * sway_period)


## Sway offset in pixels, in `[-travel, travel]`.
##
## A ping-pong across the cycle, run through a smoothstep so the velocity is zero
## at both turns. That dwell is the easing: the layer arrives at each end slowly
## and leaves it slowly, where a linear ping-pong reads as a stutter and an
## un-eased one reads as a bounce.
static func sway_offset(travel: float, period: float, elapsed: float) -> float:
    if travel <= 0.0 or period <= 0.001:
        return 0.0
    var cycle := fposmod(elapsed / period, 1.0)
    var triangle := 1.0 - absf(cycle * 2.0 - 1.0)
    var eased := triangle * triangle * (3.0 - 2.0 * triangle)
    return travel * (eased * 2.0 - 1.0)


## Current horizontal shift in pixels.
func get_shift() -> float:
    return _shift


## Shift the layer horizontally. Clamped to the margin the cover-fit reserved,
## because overshooting it is the one thing that puts a gap on screen.
func set_shift(px: float) -> void:
    var clamped := clampf(px, -margin, margin)
    if is_equal_approx(clamped, _shift):
        return
    _shift = clamped
    _apply()


# --- layout -----------------------------------------------------------------


## Re-fit and reposition the art. Called on window resize and on any change to
## the motion exports.
func refit() -> void:
    _apply()


func _apply() -> void:
    var art := get_node_or_null(ART_PATH) as Control
    if art == null:
        return
    var rect := art_rect()
    art.position = rect.position
    art.size = rect.size
