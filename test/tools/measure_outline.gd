extends SceneTree

## One-off: ink band width as a share of the object's bounding box.
## godot --headless --path . -s res://test/tools/measure_outline.gd

const DIRS := [
	"res://src/Assets/modifiers",
	"res://src/Assets/stats",
]
const FILES := [
	"res://src/Assets/enemies/spitter.png",
	"res://src/Assets/enemies/diplocaulus.png",
	"res://src/Assets/enemies/bulwark.png",
	"res://src/Assets/character/brawler/brawler_icon.png",
	"res://src/Assets/character/potato.png",
	"res://src/Assets/portal.png",
]


func _init() -> void:
	var paths: Array[String] = []
	for d in DIRS:
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".png"):
				paths.append(d + "/" + f)
	paths.append_array(FILES)
	for path in paths:
		_analyze(path)
	quit()


func _ink(img: Image, x: int, y: int) -> bool:
	var c := img.get_pixel(x, y)
	if c.a < 0.5:
		return false
	return maxf(c.r, maxf(c.g, c.b)) * 255.0 <= 90.0


func _solid(img: Image, x: int, y: int) -> bool:
	return img.get_pixel(x, y).a >= 0.5


func _analyze(path: String) -> void:
	var img := Image.load_from_file(path)
	if img == null:
		print("MISSING\t", path)
		return
	var w := img.get_width()
	var h := img.get_height()
	var minx := w
	var maxx := -1
	var miny := h
	var maxy := -1
	for y in h:
		for x in w:
			if _solid(img, x, y):
				minx = mini(minx, x)
				maxx = maxi(maxx, x)
				miny = mini(miny, y)
				maxy = maxi(maxy, y)
	if maxx < 0:
		print("EMPTY\t", path)
		return
	var bw := maxx - minx + 1
	var bh := maxy - miny + 1

	var bands: Array[int] = []
	for y in range(miny, maxy + 1):
		var l := -1
		for x in range(minx, maxx + 1):
			if _solid(img, x, y):
				l = x
				break
		if l < 0:
			continue
		var r := -1
		for x in range(maxx, minx - 1, -1):
			if _solid(img, x, y):
				r = x
				break
		var run := 0
		while l + run <= r and _ink(img, l + run, y):
			run += 1
		if run > 0 and run < (r - l + 1):
			bands.append(run)
		run = 0
		while r - run >= l and _ink(img, r - run, y):
			run += 1
		if run > 0 and run < (r - l + 1):
			bands.append(run)
	for x in range(minx, maxx + 1):
		var t := -1
		for y in range(miny, maxy + 1):
			if _solid(img, x, y):
				t = y
				break
		if t < 0:
			continue
		var b := -1
		for y in range(maxy, miny - 1, -1):
			if _solid(img, x, y):
				b = y
				break
		var run := 0
		while t + run <= b and _ink(img, x, t + run):
			run += 1
		if run > 0 and run < (b - t + 1):
			bands.append(run)
		run = 0
		while b - run >= t and _ink(img, x, b - run):
			run += 1
		if run > 0 and run < (b - t + 1):
			bands.append(run)

	if bands.is_empty():
		print("%-34s %4dx%-4d bbox %3dx%-3d   NO INK AT ALL" % [
			path.get_file(), w, h, bw, bh])
		return
	bands.sort()
	var n := bands.size()
	var med: int = bands[int(0.5 * (n - 1))]
	var p25: int = bands[int(0.25 * (n - 1))]
	var p75: int = bands[int(0.75 * (n - 1))]
	print("%-34s %4dx%-4d bbox %3dx%-3d   band p25=%d med=%d p75=%d   med=%.1f%% of width  (%.1f%% of height)" % [
		path.get_file(), w, h, bw, bh, p25, med, p75,
		100.0 * med / bw, 100.0 * med / bh])
