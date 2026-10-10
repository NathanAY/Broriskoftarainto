extends RefCounted
class_name ItemCardRow
## One styled line inside a `ShopItemCard`.
##
## `ItemTooltip.tooltip_lines()` returns flat strings for hover tooltips.
## Cards need the same information split into parts so each line can be
## colored and get its own stat icon. `ItemTooltip.card_rows()` builds
## these; the card script turns them into BBCode.

enum Kind {
    NAME,     ## Item / weapon display name (rendered in the card header)
    FLAVOR,   ## Clean description text, no mechanical meaning
    EFFECT,   ## "effect: ..." payload from the modifier
    BUFF,     ## "buff: ..." payload, always a gain
    DEBUFF,   ## "debuff: ..." payload, always a loss
    TRADEOFF, ## "tradeoff: ..." payload, always a loss
    STAT,     ## flat / percent modifier on a stat
    WEAPON,   ## weapon damage / range / attack speed / built-in effect
    GEAR,     ## starting item / weapon a character begins the run with
}

enum Tone {
    NEUTRAL,
    POSITIVE,
    NEGATIVE,
}

var kind: Kind = Kind.STAT
var tone: Tone = Tone.NEUTRAL
## Display label, e.g. "Base Damage". Empty for rows that are pure prose.
var label: String = ""
## Numeric payload, e.g. "+5" or "-0.14". Empty for prose rows.
var value: String = ""
## Full sentence for prose rows (FLAVOR / EFFECT).
var text: String = ""
## Stat icon for STAT rows, `null` when the stat has no dedicated icon.
var icon: Texture2D = null
## Stat key before humanization, e.g. "item_base_damage". Used to look up `icon`.
var stat_name: String = ""


## Human-readable line used in tooltips and tests.
func to_line() -> String:
    match kind:
        Kind.FLAVOR, Kind.EFFECT:
            return text
        Kind.NAME:
            return "name: " + label
        _:
            return "%s: %s" % [label, value]


## The complete sentence shown inside a card body.
func to_display() -> String:
    match kind:
        Kind.FLAVOR, Kind.EFFECT:
            return text
        Kind.NAME:
            return label
        Kind.GEAR, Kind.WEAPON:
            # Label-first reads right for both: "Passive Regen Starting Item",
            # and a weapon's own "Damage: 5" / "Attack Speed: 0.8 attack/sec".
            return "%s: %s" % [label, value]
        _:
            if value.is_empty():
                return label
            return "%s %s" % [value, label]
