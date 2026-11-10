extends Node2D

## Dev-only fixture: the enemy roster, rendered in a row on a plain backdrop,
## so the whole set can be eyeballed in one shot:
##
##     run_scene_shot.bat res://test/tools/enemy_gallery_preview.tscn res://enemies.png
##
## A roster row is added here as it ships. The enemy scenes are the real ones,
## not mock-ups, so what the shot shows is what the arena shows.
##
## Not part of the game: nothing loads this scene.

## The roster, in the order it is meant to be read: the basic enemy the others
## are compared against, then the roster types.
const ROSTER := [
	{"name": "Grunt", "scene": "res://src/Systems/enemies/Enemy.tscn"},
	{"name": "Bulwark", "scene": "res://src/Systems/enemies/EnemyBulwark.tscn"},
	{"name": "Gunner", "scene": "res://src/Systems/enemies/EnemyGunner.tscn"},
	{"name": "Slimeling", "scene": "res://src/Systems/enemies/EnemySlimeling.tscn"},
	{"name": "Lancer", "scene": "res://src/Systems/enemies/EnemyLancer.tscn"},
	{"name": "Toadstinker", "scene": "res://src/Systems/enemies/EnemyToadstinker.tscn"},
	{"name": "Blink", "scene": "res://src/Systems/enemies/EnemyBlink.tscn"},
	{"name": "Shieldbearer", "scene": "res://src/Systems/enemies/EnemyShieldbearer.tscn"},
	{"name": "Swarmer", "scene": "res://src/Systems/enemies/EnemySwarmer.tscn"},
]

## How far apart two enemies stand, in pixels. Comfortably more than the
## crowd separation radius, so the enemies in the row do not shove each other
## apart before the shot.
const SPACING := 220.0

## The roster is wider than one screen, so it wraps into rows.
const PER_ROW := 5

## Vertical distance between two rows, in pixels.
const ROW_SPACING := 190.0

## The backdrop, the same dark panel the UI draws on.
const BACKDROP := Color(0.149, 0.161, 0.196)

## Label colour, the UI's neutral body text.
const LABEL_COLOUR := Color(0.784, 0.804, 0.847)


func _ready() -> void:
	_add_backdrop()
	var centre := get_viewport_rect().size * 0.5
	var count := ROSTER.size()
	for index in count:
		var entry: Dictionary = ROSTER[index]
		var row := int(index / float(PER_ROW))
		var column: int = index % PER_ROW
		var in_row := mini(PER_ROW, count - row * PER_ROW)
		var x := centre.x + (float(column) - (float(in_row) - 1.0) * 0.5) * SPACING
		var y := centre.y + (float(row) - 0.5) * ROW_SPACING
		_add_enemy(entry, x, y - 60.0)
		_add_label(entry, x, y + 70.0)


## A full-screen backdrop behind the row.
func _add_backdrop() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = BACKDROP
	backdrop.size = get_viewport_rect().size
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)


func _add_enemy(entry: Dictionary, x: float, y: float) -> void:
	var enemy := load(entry["scene"]).instantiate() as Enemy
	enemy.name = entry["name"]
	add_child(enemy)
	# After `add_child`: an unparented Node2D has no parent transform to
	# compose, so writing `global_position` first would store the world
	# position as a local one.
	enemy.global_position = Vector2(x, y)


func _add_label(entry: Dictionary, x: float, y: float) -> void:
	var label := Label.new()
	label.name = "%sLabel" % entry["name"]
	label.text = entry["name"]
	label.add_theme_color_override("font_color", LABEL_COLOUR)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# A fixed width centred on the enemy, so the name sits under it rather
	# than hanging off to one side.
	label.size = Vector2(200.0, 24.0)
	label.position = Vector2(x - 100.0, y)
	add_child(label)
