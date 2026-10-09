extends PanelContainer
class_name BuffTile

## One active buff or debuff, as a fixed 32x32 tile: the stat's icon on a panel,
## a stack badge, and a duration arc drawn over the plate. Everything else - the
## full stat change, the trigger, the stat's own explanation - is hover-only and
## lives in the shared `TooltipUi` (see `TooltipUi.show_buff()`).
##
## A tile holds no reference to the effect node. `set_entry()` takes a
## `BuffEntry` snapshot and `tick()` re-reads only the two numbers that change
## every frame, so nothing here can reach into `Buff._active_stacks`.
##
## The border carries the polarity - green on the buff row, red on the debuff
## row, gold on hover - and never the icon art, per `docs/visual_style.md`.

## Sizes at full scale. Everything below is derived from these, so the tile and
## its internals cannot drift apart.
const TILE_SIZE := Vector2(32, 32)
const ICON_SIZE := Vector2(24, 24)
const BADGE_FONT_SIZE := 10
## Inset of the arc from the tile edge. The plate's 2px border sits under it.
const ARC_MARGIN := 3.0
const ARC_WIDTH := 2.0
## Gold, matching `ShopItemCard.HOVER_BORDER`, so a hover reads the same here as
## it does on a shop card.
const HOVER_BORDER := Color(0.976471, 0.729412, 0.313726, 1)

@onready var icon_holder: Control = $Stack/IconHolder
@onready var stack_badge: Label = $Stack/StackBadge
@onready var arc: BuffArc = $Stack/Arc

## The last entry set on this tile. `tick()` re-reads the timing fields off it.
var entry: BuffEntry = null

var _hovered: bool = false
var _is_debuff: bool = false


func _ready() -> void:
    # The scene literals are editor previews only; these are the real sizes.
    custom_minimum_size = TILE_SIZE
    arc.margin = ARC_MARGIN
    arc.width = ARC_WIDTH
    _refresh_border()


## Fills the tile from an entry: icon, badge, arc and border. Safe to call with
## `null` to blank the tile.
##
## The icon is rebuilt every call, which is why the grid calls this only when the
## stack count or the identity changes - not once per frame.
func set_entry(new_entry: BuffEntry) -> void:
    entry = new_entry
    if not is_node_ready():
        return
    if new_entry == null:
        _is_debuff = false
        clear_icon()
        stack_badge.visible = false
        arc.visible = false
        _refresh_border()
        return

    _is_debuff = new_entry.is_debuff
    clear_icon()
    set_icon(_build_icon(new_entry))
    # A `1` on every tile is noise, and IconCard already hides a redundant
    # readout, so the badge appears from the second stack onwards.
    stack_badge.text = str(new_entry.stack_count)
    stack_badge.visible = new_entry.stack_count > 1
    tick()
    _refresh_border()


## The tile's only per-frame work: two numbers off the entry and a redraw.
## Deliberately no string building - the old readout re-formatted every label
## every frame, which is ten `%.1f` builds a frame for text that changes visibly
## about twice a second.
func tick() -> void:
    if entry == null or not is_node_ready():
        return
    # The badge can change without an identity change, when a second stack lands.
    if entry.stack_count > 1 and str(entry.stack_count) != stack_badge.text:
        stack_badge.text = str(entry.stack_count)
        stack_badge.visible = true

    # duration 0 means nothing is counting, so the arc is hidden rather than
    # drawn as a full circle.
    arc.visible = entry.duration > 0.0
    arc.fraction = entry.arc_fraction()
    arc.color = ItemDisplayPanel.COLOR_NEGATIVE if entry.is_expiring() else ItemDisplayPanel.COLOR_HEADING
    arc.queue_redraw()


## The stat's own art. Two or more stats composite through the shared generator,
## so a multi-stat buff shows every stat it touches in one 24x24 tile.
func _build_icon(new_entry: BuffEntry) -> Control:
    var stat := BuffEntry.primary_stat(new_entry.modifiers)
    var icons: Array[Texture2D] = []
    for stat_name in new_entry.modifiers:
        icons.append(Stats.get_stat_icon(str(stat_name)))
    if icons.is_empty():
        # `_default.png` covers a stat with no art, and an entry with no stats.
        icons.append(Stats.get_stat_icon(stat))
    return ItemIconGenerator.make_composite_icon(icons, ICON_SIZE)


## Replaces the plate's icon, click-through so the tile itself owns the hover
## rather than the art being a hole in the middle of it.
func set_icon(icon: Control) -> void:
    if icon == null or not is_node_ready():
        return
    icon_holder.add_child(icon)
    ItemDisplayPanel.set_mouse_ignore(icon)


func clear_icon() -> void:
    if not is_node_ready():
        return
    # Immediate free, not queued: a re-display must not stack icons in the plate.
    for child in icon_holder.get_children():
        child.free()


## Called by the grid's hover wiring, or by the tile itself if the host binds the
## hover. Kept a method so the border refresh has one place.
func set_hovered(value: bool) -> void:
    _hovered = value
    _refresh_border()


## Border colour only. The icon art is never tinted: per `docs/visual_style.md`
## colour signals polarity through border and label, not through a glow baked
## into a PNG.
func _refresh_border() -> void:
    if not is_node_ready():
        return
    var color := ItemDisplayPanel.COLOR_NEGATIVE if _is_debuff else ItemDisplayPanel.COLOR_POSITIVE
    if _hovered:
        color = HOVER_BORDER
    add_theme_stylebox_override("panel", ItemDisplayPanel.make_panel_stylebox(color))
