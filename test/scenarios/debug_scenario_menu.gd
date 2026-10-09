extends CanvasLayer

## Debug scenario picker, opened by the main menu's "Debug scenarios" button.
##
## Dev-only: every scene it lists lives under `test/scenarios/`, and none of it
## ships. The default way to play is still the main menu's "New game" button ->
## character select -> `StarterMenu.tscn` -> `Game.tscn`; this is the shortcut
## for jumping straight to a state that would take a full run to reach.
##
## A row is generated per entry rather than authored in the scene, so adding a
## scenario is one dict here plus one `scenario_*.tscn`, and the list cannot drift
## out of sync with the scenes on disk.

const MAIN_MENU_SCENE := "res://src/Scenes/menu/Main.tscn"

const SCENARIOS := [
	{
		"title": "Loaded build",
		"description": "Loop 1, stage 1. Four weapons and items carrying 3-5 modifiers each.",
		"scene": "res://test/scenarios/scenario_loaded_build.tscn",
	},
	{
		"title": "First stage boss",
		"description": "Loop 1 boss, so the enemy stage is skipped. Tests the boss itself.",
		"scene": "res://test/scenarios/scenario_first_boss.tscn",
	},
	{
		"title": "Loop 3",
		"description": "Endgame scaling: enemies spawn already buffed for loop 3. Clearing the boss wins the run.",
		"scene": "res://test/scenarios/scenario_loop_three.tscn",
	},
	{
		"title": "Cursed enemies",
		"description": "Enemies carry a debuff item, so the HUD's debuff row fills. Also picks up a buff item.",
		"scene": "res://test/scenarios/scenario_cursed_enemies.tscn",
	},
]

## Bounds of the monster-density slider, mirrored by its range in the scene.
const MIN_MONSTER_MULTIPLIER := 0.1
const MAX_MONSTER_MULTIPLIER := 20.0

@onready var scenario_list: VBoxContainer = $Control/Center/Menu/ScenarioList
@onready var back_button: Button = $Control/Center/Menu/BackButton
@onready var monster_slider: HSlider = $Control/Center/Menu/MonsterRow/MonsterSlider
@onready var monster_value_label: Label = $Control/Center/Menu/MonsterRow/MonsterValueLabel


func _ready() -> void:
	for index in SCENARIOS.size():
		scenario_list.add_child(_make_row(index))
	back_button.pressed.connect(_on_back_pressed)
	monster_slider.value_changed.connect(_on_monster_slider_changed)
	_on_monster_slider_changed(monster_slider.value)


## One button plus the line describing it, as a single row so the two stay
## together when the list is read.
func _make_row(index: int) -> Control:
	var row := VBoxContainer.new()
	row.name = "ScenarioRow%d" % index

	var button := UiMenuButton.new()
	button.name = "ScenarioButton%d" % index
	button.text = SCENARIOS[index]["title"]
	button.pressed.connect(_on_scenario_pressed.bind(index))
	row.add_child(button)

	var description := Label.new()
	description.name = "ScenarioDescription%d" % index
	description.text = SCENARIOS[index]["description"]
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(description)

	return row


## The scene a row opens. Split out of `_on_scenario_pressed` so the routing can
## be checked without actually loading a `Game.tscn` mid-suite.
func scene_path_for(index: int) -> String:
	if index < 0 or index >= SCENARIOS.size():
		push_error("Debug scenario index out of range: %d" % index)
		return ""
	return SCENARIOS[index]["scene"]


func _on_scenario_pressed(index: int) -> void:
	var path := scene_path_for(index)
	if path == "" or not ResourceLoader.exists(path):
		push_error("Debug scenario scene missing: " + path)
		return
	_publish_monster_multiplier()
	# No global is set here on purpose. The scenario's own `ScenarioSetup` node
	# writes the loadout into `GlobalGameState` before the character reads it,
	# and the stage jump into `StageManager`, so the scene file carries the whole
	# configuration and there is no second place to keep in sync.
	get_tree().change_scene_to_file(path)


## The density the slider currently shows, clamped to the range the spawner
## accepts. Read back off the slider rather than kept in a field so the label and
## the handed-off value cannot disagree.
func _selected_multiplier() -> float:
	return clampf(
		monster_slider.value,
		MIN_MONSTER_MULTIPLIER,
		MAX_MONSTER_MULTIPLIER
	)


## Hands the picked density to the scenario about to be loaded. A static rather
## than a node because the scenario scene that reads it is not in the tree yet,
## and every scenario reads the same value, so the slider is shared instead of
## being a per-scenario field in `SCENARIOS`. Split out of `_on_scenario_pressed`
## so the handoff can be checked without changing scene mid-suite.
func _publish_monster_multiplier() -> void:
	DebugScenarioSetup.pending_monster_multiplier = _selected_multiplier()


func _on_monster_slider_changed(value: float) -> void:
	monster_value_label.text = "%.1fx" % value


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
