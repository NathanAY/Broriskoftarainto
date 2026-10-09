extends RefCounted
class_name BuffEntry

## One active effect's worth of display state, gathered from the live `Buff` /
## `Debuff` nodes behind a single tile. The `Control` side of the buff grid
## (`buff_ui.gd`) only reads this, and `BuffTile` only renders it, so every
## formatting rule is testable without a scene tree.
##
## This is the buff counterpart of `ItemCardRow`: a `Resource`-shaped record the
## UI draws rather than recomputes. It holds no node references except `key`,
## which is *the* identity of the effect and has to survive the node.

## The live effect node, or the `DebuffSource` several `Debuff` nodes share.
## This is the grouping key: one node is one tile, so two buffs with identical
## modifiers stay two tiles and a buff whose modifiers change stays one.
var key: Object = null
## `display_name` off the effect if it set one, else the humanized primary stat.
var name: String = ""
## The summed modifier dictionary across every stack in this tile.
var modifiers: Dictionary = {}
## How many stacks or instances are behind the tile. One tile per buff node, so
## this is `Buff.stack_count()`; a grouped debuff tile counts its instances.
var stack_count: int = 1
## 0 for a debuff, which does not stack at its source. Only meaningful for a
## buff, and only when `stack_count > 1`.
var max_stacks: int = 0
## Seconds left on the soonest stack / instance, so the arc runs out when the
## first thing actually does.
var remaining: float = 0.0
## Full duration of one stack, the arc's denominator. 0.0 means "no running
## timer", which hides the arc rather than drawing a full circle.
var duration: float = 0.0
## Raw event name ("on_hit"), humanized by the tooltip.
var trigger: String = ""
## The effect's own `tooltip_text`, or "" for none.
var tooltip_text: String = ""
## False for the debuff row. Also drives the tile border and the tooltip badge.
var is_debuff: bool = false


## Sums a stack set's modifier dictionaries, so the tooltip reports what the
## stat actually moved by rather than one stack's worth. `flat` and `percent`
## are added independently, and a stat present in some stacks but not others
## keeps only the stacks that touched it.
static func total_modifiers(per_stack: Array) -> Dictionary:
    var total: Dictionary = {}
    for entry in per_stack:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        for stat_name in entry:
            var values: Dictionary = entry[stat_name]
            if typeof(values) != TYPE_DICTIONARY:
                continue
            var sums: Dictionary = total.get(stat_name, {})
            for kind in values:
                sums[kind] = float(sums.get(kind, 0.0)) + float(values[kind])
            total[stat_name] = sums
    return total


## One stack's modifiers multiplied by how many stacks are running. A `Buff`
## applies the *same* dictionary once per stack (`Stats.add_modifier` per trigger),
## so three stacks of `attack_speed: {flat: 0.5}` really do move the stat by 1.5 -
## and that is the number the tooltip has to report, not 0.5.
static func scaled_modifiers(modifier_dict: Dictionary, stacks: int) -> Dictionary:
    var total: Dictionary = {}
    for stat_name in modifier_dict:
        var values: Dictionary = modifier_dict[stat_name]
        if typeof(values) != TYPE_DICTIONARY:
            continue
        var scaled: Dictionary = {}
        for kind in values:
            scaled[kind] = float(values[kind]) * float(stacks)
        total[stat_name] = scaled
    return total


## The icon key: the first stat in sorted order, so the tile's art does not
## flicker between frames on a dictionary whose key order varies.
static func primary_stat(modifier_dict: Dictionary) -> String:
    var names: Array = modifier_dict.keys()
    if names.is_empty():
        return ""
    names.sort()
    return str(names[0])


## What the tile's duration arc is currently filled to, clamped to 0..1.
## 0.0 means "no running timer": the arc is hidden rather than drawn full.
func arc_fraction() -> float:
    if duration <= 0.0:
        return 0.0
    return clampf(remaining / duration, 0.0, 1.0)


## The arc turns red under this fraction, so a buff about to lapse is visible
## without reading the number in the tooltip.
const EXPIRING_FRACTION := 0.2

func is_expiring() -> bool:
    if duration <= 0.0:
        return false
    return arc_fraction() < EXPIRING_FRACTION


## The name to show when the effect sets none: the humanized primary stat, or
## "Buff" / "Debuff" when there is no modifier to name.
func resolved_name() -> String:
    if not name.is_empty():
        return name
    var stat := primary_stat(modifiers)
    if stat.is_empty():
        return "Debuff" if is_debuff else "Buff"
    return ItemTooltip.humanize_effect_name(stat)
