extends Control
class_name ItemIconGenerator

## Generates a composite icon for an Item based on its stats and effects.
## Icons are combined into a grid.

const BASE_SIZE: Vector2 = Vector2(48, 48)

## The canvas modifier / effect art is authored on. `AssetSizes` owns the number;
## this is the vector shape the generator needs. A source larger than this is
## source-resolution art - the file keeps its authored size and is minified onto
## whatever plate the caller asks for, never re-exported down to it.
const SOURCE_CANVAS: Vector2 = Vector2(AssetSizes.MODIFIER_ICON, AssetSizes.MODIFIER_ICON)

## `icon_size` is the square the composite is laid out in: the small icons the grid
## is drawn from scale to fill it, so a caller can render the same item at the
## size of its own plate instead of always getting BASE_SIZE.
static func generate_icon(item: Item, icon_size: Vector2 = BASE_SIZE) -> Control:
    var icons: Array[Texture2D] = []

    # 1. Get icons for stat modifiers
    if item.modifiers:
        for mod in item.modifiers:
            var icon = Stats.get_stat_icon(mod)
            if icon:
                icons.append(icon)

    # 2. Get icons for effects
    if item.effect_scene:
        for effect in item.effect_scene:
            var icon_name = effect.resource_path.get_file().get_basename().to_lower()
            var path = "res://src/Assets/modifiers/" + icon_name + ".png"
            if ResourceLoader.exists(path):
                icons.append(load(path))

    # Fallback
    if icons.is_empty():
        icons.append(load("res://src/Assets/modifiers/_default.png"))

    return _create_composite_texture(icons, icon_size)


## Public entry to the compositor for callers that already have their icons.
## The buff tile needs this: there is no buff/debuff icon art, so it collects
## `Stats.get_stat_icon()` for every stat the effect touches and composites them
## into one tile, the same way an item's stats are.
static func make_composite_icon(icons: Array[Texture2D], icon_size: Vector2 = BASE_SIZE) -> Control:
    if icons.is_empty():
        icons.append(load("res://src/Assets/modifiers/_default.png"))
    return _create_composite_texture(icons, icon_size)


## Icons are combined into a grid.
static func _create_composite_texture(icons: Array[Texture2D], icon_size: Vector2 = BASE_SIZE) -> Control:
    var container = Control.new()
    container.custom_minimum_size = icon_size
    
    var count = icons.size()
    if count == 1:
        var rect := _make_icon_rect(icons[0])
        rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        container.add_child(rect)
    else:
        # Simple split layout
        var grid = GridContainer.new()
        grid.columns = int(ceil(sqrt(count)))
        grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        container.add_child(grid)
        
        for icon in icons:
            var rect := _make_icon_rect(icon)
            rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
            grid.add_child(rect)
            
    return container


## One icon, scaled to fill whatever plate it is put in.
##
## A source-resolution icon is minified on every plate the UI draws, so it is
## sampled with mipmaps - without them the downscale aliases and shimmers, which
## is the same trap the portal art needed fixing for.
static func _make_icon_rect(icon: Texture2D) -> TextureRect:
    var rect := TextureRect.new()
    rect.texture = icon
    rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    if icon != null and icon.get_width() > int(SOURCE_CANVAS.x):
        rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    return rect
