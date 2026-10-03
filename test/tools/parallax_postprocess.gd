extends SceneTree

## One-shot post-process for the main menu's parallax background art.
##
## Step 4 of docs/archive/main_menu_parallax_background.md. Bing hands back a
## 1248x832 `Format24bppRgb` JPEG: no alpha, narrower than the 1552px viewport,
## and with no overscan. This turns each one into the PNG `Main.tscn` loads.
##
##     godot --headless --script res://test/tools/parallax_postprocess.gd
##
## A tool rather than part of the project: it writes assets, runs once per art
## change, and is skipped by the test runners because it is not named `test_*.gd`.
##
## ## Why any of this is necessary
##
## Because of `MenuParallaxLayer.cover_fit`. A layer fitted to cover the window is
## exactly the window wide, so the first pixel of sway uncovers a gap down one
## side. The fix is to fit against the window plus the layer's whole horizontal
## travel, which means the PNG has to carry that much slack itself.
##
## ## Why grow rather than resize
##
## The plan called for an upscale to the target width, because Bing's 3:2 output
## is 1248px against a 1552px viewport. Growing by modal fill instead is
## strictly better and costs nothing: the art keeps its native pixels, and the
## horizontal features the plan wanted extended anyway - the mid layer's fence,
## the ground bands, the near layer's grass - continue rather than being
## resampled into a blur and then padding cuts through. The art is flat colour
## with hard outlines, so a pixel-exact canvas at the window's own width is the
## right target; `cover_fit` scales it by 1.03 and no further.
##
## `grow` is opaque continuation of the scene, `pad` is transparent overscan that
## the sway eats into. Both are per side. Together they are the layer's margin,
## and total width is `CONTENT_WIDTH + 2 * margin` = the plan's
## `required_art_width`.

## Project viewport width from project.godot. The content canvas is this wide,
## because that is the size the fit shows one-to-one at the default window.
const CONTENT_WIDTH := 1552

## Layers, far to near. `margin` is each layer's `travel + mouse_travel` and must
## stay in step with the exports in src/Scenes/menu/Main.tscn, which
## test/Systems/menu/test_menu_parallax.gd asserts against the same numbers.
## The far layer is opaque, so all of its margin is `grow`: it has to be *wider*
## than the window rather than transparent beside it.
const LAYERS := [
	{"name": "far", "margin": 32.0, "grow": 184.0, "pad": 0.0, "keyed": false},
	{"name": "mid", "margin": 62.0, "grow": 152.0, "pad": 62.0, "keyed": true},
	{"name": "near", "margin": 106.0, "grow": 152.0, "pad": 106.0, "keyed": true},
]

## White-key thresholds on a pixel's darkest channel, in 0-255.
##
## The generated background sits at 248-255, the faintest JPEG ringing around it
## reaches about 232, and the palest real content is the mid layer's fence rail
## at 172. There is a clear gap to key against and nothing to punch a hole in by
## accident. Inside it the colour is unpremultiplied: a pixel that is 90% white
## and 10% outline becomes 10% alpha over that outline, which is what stops a
## white rim appearing around every shape.
const KEY_CLEAR := 246.0
const KEY_SOLID := 224.0

const DEBUG_SHEET := "res://parallax_processed.png"
const DEBUG_WIDTH := 760


func _initialize() -> void:
	var stack := Image.create(DEBUG_WIDTH, 1, false, Image.FORMAT_RGBA8)
	stack.fill(Color(0.05, 0.05, 0.07, 1.0))
	for layer in LAYERS:
		var name: String = layer["name"]
		var margin := int(layer["margin"])
		var image := _load("res://src/Assets/menu/parallax_%s.jpg" % name)

		if layer["keyed"]:
			image = _key_white(image)
		image = _grow_and_pad(image, int(layer["grow"]), int(layer["pad"]))

		var output_path := "res://src/Assets/menu/parallax_%s.png" % name
		var err := image.save_png(output_path)
		print("  %s: %dx%d -> %s (error %d, needs %d)" % [
			name, image.get_width(), image.get_height(), output_path, err,
			roundi(MenuParallaxLayer.required_art_width(CONTENT_WIDTH, margin))])
		stack = _stack_below(stack, _over_magenta(image))

	stack.save_png(DEBUG_SHEET)
	print("  debug sheet: ", DEBUG_SHEET)
	quit()


func _load(path: String) -> Image:
	var image := Image.load_from_file(path)
	if image == null:
		push_error("parallax_postprocess: cannot read " + path)
		quit(1)
		return Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.convert(Image.FORMAT_RGBA8)
	return image


# --- white key ---------------------------------------------------------------


## Punches the keyed background out to transparent, unpremultiplying the pixels
## in the soft band so their colour is the shape's rather than the shape plus
## white.
func _key_white(image: Image) -> Image:
	var data := image.get_data()
	var span := KEY_CLEAR - KEY_SOLID
	for index in range(0, data.size(), 4):
		var darkest := mini(data[index], mini(data[index + 1], data[index + 2]))
		if darkest >= KEY_CLEAR:
			data[index + 3] = 0
		elif darkest <= KEY_SOLID:
			data[index + 3] = 255
		else:
			var coverage := (KEY_CLEAR - darkest) / span
			data[index + 3] = clampi(int(round(coverage * 255.0)), 0, 255)
			var carried := (1.0 - coverage) * 255.0
			for channel in 3:
				var value := (float(data[index + channel]) - carried) / coverage
				data[index + channel] = clampi(int(round(value)), 0, 255)
	return Image.create_from_data(
		image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, data)


# --- overscan ----------------------------------------------------------------


## Widens a layer to `CONTENT_WIDTH + 2 * (grow + pad)` by adding `grow` opaque
## scene pixels and then `pad` transparent pixels on each side.
##
## The fill is each row's most common pixel, which is what continuing a full-bleed
## feature looks like: the fence carries on as more fence, the grass as more
## grass, and a row that is mostly sky stays sky. It invents nothing, and a
## feature that only occupies part of a row - a fence post, a boulder - is left
## where it is instead of being smeared across the margin.
func _grow_and_pad(image: Image, grow: int, pad: int) -> Image:
	var width := image.get_width()
	var height := image.get_height()
	var source := image.get_data()
	var grown_width := width + grow * 2
	var out_width := grown_width + pad * 2
	print("    %dx%d source -> grow %dpx + pad %dpx per side -> %dx%d" % [
		width, height, grow, pad, out_width, height])

	var out_data := PackedByteArray()
	out_data.resize(out_width * height * 4)
	for y in height:
		var row := y * width * 4
		var out_row := y * out_width * 4
		for x in pad:
			_write_pixel(out_data, out_row + x * 4, PackedByteArray([0, 0, 0, 0]))
		for x in grown_width:
			_write_pixel(out_data, out_row + (x + pad) * 4,
				source.slice(row + clampi(x - grow, 0, width - 1) * 4,
					row + clampi(x - grow, 0, width - 1) * 4 + 4))
		for x in pad:
			_write_pixel(out_data, out_row + (grown_width + pad + x) * 4,
				PackedByteArray([0, 0, 0, 0]))
	return Image.create_from_data(out_width, height, false, Image.FORMAT_RGBA8, out_data)


func _write_pixel(out: PackedByteArray, at: int, pixel: PackedByteArray) -> void:
	for channel in 4:
		out[at + channel] = pixel[channel]


# --- debug sheet -------------------------------------------------------------


## Flattens a layer onto magenta, so transparent overscan reads as magenta and any
## hole punched in the art reads as a hole in the layer. Deleted after eyeballing;
## nothing references it.
func _over_magenta(layer: Image) -> Image:
	var flat := layer.duplicate() as Image
	flat.convert(Image.FORMAT_RGBA8)
	var pixels := flat.get_data()
	for index in range(0, pixels.size(), 4):
		var alpha := float(pixels[index + 3]) / 255.0
		var green := float(pixels[index + 1]) * alpha
		pixels[index] = clampi(
			int(round(float(pixels[index]) * alpha + 255.0 * (1.0 - alpha))), 0, 255)
		pixels[index + 1] = clampi(int(round(green)), 0, 255)
		pixels[index + 2] = clampi(
			int(round(float(pixels[index + 2]) * alpha + 255.0 * (1.0 - alpha))), 0, 255)
		pixels[index + 3] = 255
	var height := maxi(
		1, roundi(float(flat.get_height()) * float(DEBUG_WIDTH) / float(flat.get_width())))
	flat.resize(DEBUG_WIDTH, height, Image.INTERPOLATE_NEAREST)
	return flat


func _stack_below(stack: Image, strip: Image) -> Image:
	var grown := Image.create(stack.get_width(), stack.get_height() + strip.get_height() + 2,
		false, Image.FORMAT_RGBA8)
	grown.fill(Color(0.85, 0.2, 0.7, 1.0))
	grown.blit_rect(stack, Rect2i(0, 0, stack.get_width(), stack.get_height()), Vector2i.ZERO)
	grown.blit_rect(strip, Rect2i(0, 0, strip.get_width(), strip.get_height()),
		Vector2i(0, stack.get_height() + 2))
	return grown