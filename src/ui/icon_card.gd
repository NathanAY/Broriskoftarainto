extends PanelContainer
class_name IconCard

## Fixed-size icon + name tile for compact grids. The character select screen
## (`CharacterCard`) and the character menu's Items / Weapons grids are the same
## widget, so a card can never look different from one screen to the next;
## subclasses only add their own chrome (click handling, selection border).
##
## There is no stat body here - that is `ItemDisplayPanel`'s job, which the
## hover tooltip already uses. `set_display()` fills the tile from any resource
## (`CharacterData` / `Item` / `BaseWeapon`) through the same
## `ItemDisplayPanel.make_icon()` / `display_name()` helpers the big cards use,
## so tile and card always agree on art and naming.
##
## `apply_scale()` shrinks the whole tile in one step, so a denser grid reuses
## this same scene at a smaller size instead of needing a second one.
##
## Call `apply_scale()` / `set_display()` after the tile has entered the tree
## (see CharacterSelect, which adds the card first and fills it second).

## Sizes at full scale. Everything below is derived from these, so the card and
## its internals cannot drift apart.
const CARD_SIZE := Vector2(108, 124)
const PLATE_SIZE := Vector2(72, 72)
const ICON_SIZE := Vector2(64, 64)
const MARGIN := 8
const SEPARATION := 6
const NAME_FONT_SIZE := 13

## The name is the one thing that does not scale linearly: below this it stops
## being readable, and a longer name simply truncates further instead.
const MIN_NAME_FONT_SIZE := 10

## The scale the *gear* grids use - the character menu's Items and Weapons
## lists, and the shop's Collected Items and Weapons lists. A run holds far more
## items than there are characters to choose from, so those screens trade
## name length for density and leave the full name to the hover tooltip.
## Character select keeps the full size, because its whole job is comparing a
## handful of names side by side.
const COMPACT_SCALE := 0.75

@onready var margin: MarginContainer = $Margin
@onready var vbox: VBoxContainer = $Margin/VBox
@onready var icon_holder: CenterContainer = $Margin/VBox/IconHolder
@onready var name_label: Label = $Margin/VBox/NameLabel

var scale_factor: float = 1.0

## Kept so `apply_scale()` can rebuild the art at the new size instead of
## leaving a stale icon behind.
var _resource: Resource = null


func _ready() -> void:
	_apply_scale()
	set_border_color(ItemDisplayPanel.PANEL_BORDER)
	set_name_color(ItemDisplayPanel.COLOR_NEUTRAL)


## Shrinks (or grows) the whole tile - card, plate, art, margins, gaps and name
## font - in one step. Called before the tile enters the tree; calling it later
## re-lays out and rebuilds the current art at the new size.
func apply_scale(factor: float) -> void:
	scale_factor = maxf(factor, 0.1)
	if is_node_ready():
		_apply_scale()


## The scene literals are editor previews only; these are the real sizes.
func _apply_scale() -> void:
	custom_minimum_size = CARD_SIZE * scale_factor
	icon_holder.custom_minimum_size = PLATE_SIZE * scale_factor

	var inset := roundi(MARGIN * scale_factor)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, inset)
	vbox.add_theme_constant_override("separation", roundi(SEPARATION * scale_factor))
	name_label.add_theme_font_size_override("font_size",
		maxi(roundi(NAME_FONT_SIZE * scale_factor), MIN_NAME_FONT_SIZE))
	# A smaller tile has room for one name line, not two.
	name_label.max_lines_visible = 1 if scale_factor < 1.0 else 2

	if _resource != null:
		set_display(_resource)


## Fills the tile from a resource: its icon above, its humanized name below.
func set_display(resource: Resource) -> void:
	_resource = resource
	if not is_node_ready():
		return
	clear_icon()
	if resource == null:
		name_label.text = ""
		return
	set_icon(ItemDisplayPanel.make_icon(resource, ICON_SIZE * scale_factor))
	set_card_name(ItemDisplayPanel.display_name(resource))


## Replaces the plate's icon. The icon is decorative - the card owns the hover -
## so it is made click-through.
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


func set_card_name(text: String) -> void:
	if not is_node_ready():
		return
	name_label.text = text


func set_border_color(color: Color) -> void:
	add_theme_stylebox_override("panel", ItemDisplayPanel.make_panel_stylebox(color))


func set_name_color(color: Color) -> void:
	if not is_node_ready():
		return
	name_label.add_theme_color_override("font_color", color)
