extends ItemDisplayPanel
class_name CharacterDetailPanel

## The top half of CharacterSelect: the chosen character's portrait, name and
## full stat block.
##
## It is the same `ItemDisplayPanel` the shop card and hover tooltip use, at a
## larger scale, so the character screen and the shop cannot drift apart. All the
## content comes from `set_resource()`: the header from
## `ItemTooltip.card_rows()` and the body from the same rows turned into BBCode.
##
## Only the parts a character needs live here - no price plate, no buttons.
## Picking a character is the grid card's job.
##
## The panel hugs its stats rather than stretching to fill the top of the
## screen; the leftover height goes to the character grid. That only works
## because `InfoLabel` carries a `custom_minimum_size.x` wrap-width floor -
## `autowrap` at width 0 would break every word onto its own line and inflate
## the measured height.
##
## That floor is a trade-off, not a free win. It is the width the height is
## predicted at, so too small over-predicts the height and leaves dead space
## under the stats; too large forces the whole panel to be at least that wide.
## 900 is wide enough that the longest stat line stays on one line at this
## font size, and narrow enough to fit any normal window.

const EMPTY_HINT := "Select a character to see their stats."


func _ready() -> void:
	super()
	# The panel itself is display-only, so clicks fall through to whatever is
	# behind it. The body scroll is left interactive on purpose.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Hug the stats instead of stretching to fill the top half of the screen:
	# the leftover space is given back to the character grid below.
	hug_body_content()
	clear()


## Shows a blank panel with a hint. Used before anything is selected.
func clear() -> void:
	_clear_icon()
	icon_plate.visible = false
	separator.visible = false
	name_label.text = ""
	name_label.text = EMPTY_HINT
	info_label.text = ""


## Character-specific alias so the select screen keeps its vocabulary.
func set_character_display(character: CharacterData) -> void:
	set_resource(character)
