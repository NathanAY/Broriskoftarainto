extends CanvasLayer
class_name SandboxMenu

## Dev-only sandbox panel, opened from the pause menu of the Sandbox scenario.
##
## The whole of it: three numbers and a Spawn button. `spawn_configured()` puts an
## enemy into the arena with exactly the health and movement speed that were typed
## in, which is what a balance or mechanics test needs - a real `Enemy.tscn`, so
## weapons, damage and death all behave normally, but with stats a designer chose
## rather than stats the wave scaling picked.
##
## Nothing ships: `ScenarioSetup` builds this node and a pause-menu button for it,
## and only when a scenario sets `sandbox = true`.
##
## Built in code rather than as a `.tscn` so a dev panel cannot drift out of sync
## with the script that drives it, and so it needs no hand-written scene file.

const ENEMY_SCENE := preload("res://src/Systems/Enemy.tscn")

## Distance from the player the spawned enemies appear at. A ring, so a batch of
## them lands spread out instead of stacked on one pixel.
const SPAWN_RADIUS := 320.0

## Upper bounds on the spinboxes. Health is generous because "effectively immortal"
## (100k+) is the point of the panel; speed stops at 20 m/s so a typo cannot fling
## an enemy across the arena.
const MAX_HEALTH := 1_000_000.0
const MAX_MOVEMENT_SPEED := 20.0
const MAX_AMOUNT := 100

## Defaults are the case the panel exists for: a huge, stationary target.
const DEFAULT_HEALTH := 100_000.0
const DEFAULT_MOVEMENT_SPEED := 0.0
const DEFAULT_AMOUNT := 1

## Where enemies go. `StageManager/EnemySpawner` reads the same node in its own
## `_ready()`, so a spawned enemy lands in the arena the stage manager watches.
var enemies_node: Node = null
var character: Character = null

var _health_box: SpinBox
var _speed_box: SpinBox
var _amount_box: SpinBox


## Wires the panel to the running game. Called before the node enters the tree, so
## it also sets `process_mode`: the panel is opened from the pause menu, where the
## tree is paused, and a panel that stops processing there cannot be used at all.
func setup(p_enemies_node: Node, p_character: Character) -> void:
	enemies_node = p_enemies_node
	character = p_character
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var panel := PanelContainer.new()
	panel.name = "Panel"
	var centered := CenterContainer.new()
	centered.name = "Center"
	centered.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centered)
	centered.add_child(panel)

	var rows := VBoxContainer.new()
	rows.name = "Rows"
	panel.add_child(rows)

	rows.add_child(_make_header())
	_health_box = _add_number_row(rows, "Health", 0.0, MAX_HEALTH, 1000.0, DEFAULT_HEALTH)
	_speed_box = _add_number_row(rows, "Movement speed", 0.0, MAX_MOVEMENT_SPEED, 0.1, DEFAULT_MOVEMENT_SPEED)
	_amount_box = _add_number_row(rows, "Amount", 1.0, float(MAX_AMOUNT), 1.0, float(DEFAULT_AMOUNT))
	rows.add_child(_make_buttons())

	# Hidden until the pause menu opens it, the way `OptionsMenu` is hidden there.
	visible = false


## Shows the panel and hides the pause menu behind it, mirroring how the pause
## menu opens `OptionsMenu`.
func open() -> void:
	visible = true
	var pause_menu := _pause_menu()
	if pause_menu != null:
		(pause_menu.get_node_or_null("Control") as Control).visible = false


## Hides the panel and gives the pause menu its button list back.
func close() -> void:
	visible = false
	var pause_menu := _pause_menu()
	if pause_menu != null:
		(pause_menu.get_node_or_null("Control") as Control).visible = true


func _make_header() -> Control:
	var title := Label.new()
	title.name = "Title"
	title.text = "Sandbox"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return title


## One `Label` plus one `SpinBox`, returned so the caller keeps a reference. The
## label is the row's name in code, which is why the tests can address a row.
func _add_number_row(rows: VBoxContainer, label_text: String, min_value: float,
		max_value: float, step: float, default_value: float) -> SpinBox:
	var row := VBoxContainer.new()
	row.name = "%sRow" % label_text.replace(" ", "")

	var label := Label.new()
	label.name = "Label"
	label.text = label_text
	row.add_child(label)

	var box := SpinBox.new()
	box.name = "Box"
	box.min_value = min_value
	box.max_value = max_value
	box.step = step
	box.value = default_value
	row.add_child(box)

	rows.add_child(row)
	return box


func _make_buttons() -> Control:
	var row := HBoxContainer.new()
	row.name = "Buttons"
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var spawn_button := UiMenuButton.new()
	spawn_button.name = "SpawnButton"
	spawn_button.text = "Spawn"
	spawn_button.pressed.connect(_on_spawn_pressed)
	row.add_child(spawn_button)

	var close_button := UiMenuButton.new()
	close_button.name = "CloseButton"
	close_button.text = "Close"
	close_button.pressed.connect(_on_close_pressed)
	row.add_child(close_button)

	return row


func _on_spawn_pressed() -> void:
	spawn_configured()


func _on_close_pressed() -> void:
	close()


## Spawns `amount` enemies with exactly the typed health and movement speed, and
## returns them so a test can read the result back. Split out of the button
## handler so spawning is checkable without going through the UI.
##
## The stats are set before the enemy joins the tree: `Health._ready()` reads
## `max_health` off `Stats` and copies it into `current_health`, so a value written
## after `add_child()` would raise the ceiling and leave the enemy already dead.
## No stage scaling is applied either - a sandbox asks for a number and gets it.
func spawn_configured() -> Array[Enemy]:
	if enemies_node == null or character == null:
		push_warning("SandboxMenu: no enemies node or character, spawning nothing.")
		return []

	var spawned: Array[Enemy] = []
	var amount := int(_amount_box.value)
	for index in range(amount):
		var enemy: Enemy = ENEMY_SCENE.instantiate()
		var stats := enemy.get_node("Stats") as Stats
		stats.set_base_stat("health", _health_box.value)
		stats.set_base_stat("movement_speed", _speed_box.value)
		enemies_node.add_child(enemy)
		# After `add_child()`, so the arena's own transform is in the way. The ring
		# spreads a batch instead of stacking it on the player.
		enemy.global_position = character.global_position + Vector2.from_angle(
			TAU * float(index) / float(maxi(amount, 1))
		) * SPAWN_RADIUS
		enemy.set_target_position(character)
		spawned.append(enemy)
	return spawned


func _pause_menu() -> CanvasLayer:
	var scene := get_tree().current_scene
	return scene.get_node_or_null("UI/PauseMenu") as CanvasLayer if scene != null else null