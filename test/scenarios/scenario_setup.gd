extends Node
class_name DebugScenarioSetup

## Dev-only: the state one debug scenario forces on a run.
##
## Every `test/scenarios/scenario_*.tscn` instances `src/Scenes/Game.tscn` and
## ends with one node of this script, configured through the exports below. That
## keeps a scenario to a single short file: the scene *is* the configuration, and
## nothing has to be remembered between the picker and the run.
##
## The scenario never returns here - `_on_stage_applied` is the log line to read
## when a scenario did not do what it claims.

const DEFAULT_CHARACTER := "res://src/Assets/character/multitasker/Multitasker.tres"
const ITEMS_DIR := "res://src/Resources/items"
const WEAPONS_DIR := "res://src/Resources/weapons"
const MODIFIERS_DIR := "res://src/Systems/Items/modifiers"

enum StartMode {
	STAGE_ONE, ## normal run: the enemy stage of `current_loop`.
	BOSS_STAGE, ## straight to stage 2 - the enemy stage is skipped entirely.
	LOOP, ## the enemy stage of `start_loop`, with both spawners already scaled.
}

## Monster-density multiplier for the run the picker is about to start, read by
## every scenario as `monster_multiplier`. Static rather than a node, because the
## picker sets it and the scenario is a *different* scene: there is no shared
## node to hang it on, and it has to survive the scene change. The picker writes
## it and is the only writer; a scenario never writes it back.
static var pending_monster_multiplier: float = 1.0

@export var scenario_title := "Debug scenario"
## Must be a real `src/Assets/character/<id>/<Id>.tres`: `CharacterInitializer`
## derives the sprite folder from this path, so a synthetic resource loads with
## no art.
@export var character_path: String = DEFAULT_CHARACTER
## Bare file names under `src/Resources/weapons`. The character's own
## `starting_weapons` are added on top of these by `CharacterInitializer`, so a
## character that ships one (Multitasker has a Fist) ends up with one more than
## listed here.
@export var weapon_names: Array[String] = []
## Bare file names under `src/Resources/items`.
@export var item_names: Array[String] = []
## Adds the stacked mid-game build from `stacked_items()` on top of the above.
@export var stacked_build: bool = false
@export var start_mode: StartMode = StartMode.STAGE_ONE
## Only read by `StartMode.LOOP`.
@export var start_loop: int = 1
## Bare file name under `src/Resources/items`. Given to every enemy the spawner
## fields, so an item that curses whatever it hits actually lands on the player.
## Enemies carry no items in the shipped game (`src/Scripts/Enemy.gd`), which is
## why the player's debuff row needs a scenario to be reachable at all - see
## `docs/systems/debug_scenarios.md`.
@export var enemy_item_name: String = ""
## 0..1 per enemy. Only read when `enemy_item_name` is set.
@export_range(0.0, 1.0, 0.05) var enemy_item_chance: float = 1.0


## Runs before *any* child's `_ready`, which is what makes this the right hook:
## `Character` and its `CharacterInitializer` both read `GlobalGameState` from
## their own `_ready`, so the character has to be chosen here rather than after a
## frame. The loadout below is added afterwards through the holder API instead,
## because those holders only exist once `Character` is built.
func _enter_tree() -> void:
	GlobalGameState.starting_character = character_path
	GlobalGameState.starting_weapons = []
	GlobalGameState.starting_items = []


func _ready() -> void:
	# The loadout and the stage jump both need a character and a `StageManager`
	# that have finished their own `_ready`, so they wait one frame.
	await get_tree().process_frame
	_equip_loadout()
	_equip_enemy_items()
	_apply_start_mode()
	_apply_monster_multiplier()
	_on_stage_applied()


func _equip_loadout() -> void:
	var character := get_tree().get_first_node_in_group("character") as Character
	if character == null:
		push_warning("DebugScenarioSetup: no character in the tree, scenario '%s' starts empty." % scenario_title)
		return

	for weapon_name in weapon_names:
		character.weapon_holder.add_weapon(load("%s/%s.tres" % [WEAPONS_DIR, weapon_name]))
	for item_name in item_names:
		character.item_holder.add_item(load("%s/%s.tres" % [ITEMS_DIR, item_name]))
	if stacked_build:
		for item in stacked_items():
			character.item_holder.add_item(item)


## The mid-game build: items carrying 3-5 modifiers each, which no shipped
## `src/Resources/items/*.tres` does - every one of those is a single modifier.
## They are built with `ItemBuilder` rather than added as new `.tres` files so
## the numbers stay readable next to the scenario that uses them.
func stacked_items() -> Array[Item]:
	return [
		ItemBuilder.make_stat_item(
			"Veteran's Charm",
			"+4 and +25% damage, +15% crit, +3 flat damage, pierce 2",
			{
				"damage": {"flat": 4.0, "percent": 0.25},
				"critical_chance": {"flat": 0.15},
				"flat_damage": {"flat": 3.0},
				"projectile_pierce": {"flat": 2.0},
			}
		),
		ItemBuilder.make_effect_item(
			"Chain Reactor",
			"Chains on hit, and +20% damage with +30% area",
			load("%s/ChainModifier.tscn" % MODIFIERS_DIR),
			{
				"damage": {"percent": 0.2},
				"area_radius": {"percent": 0.3},
				"attack_speed": {"percent": 0.1},
			}
		),
		ItemBuilder.make_stat_item(
			"Survivor's Ward",
			"+30 health, 20 shield, +20% speed, +0.5 crit multiplier",
			{
				"health": {"flat": 30.0},
				"energy_shield": {"flat": 20.0},
				"movement_speed": {"percent": 0.2},
				"critical_multiplier": {"flat": 0.5},
			}
		),
	]


## Hangs an `EnemyDebuffModifier` off the enemy spawner, which is the spawner's
## own extension point: it calls `attach_to_enemy()` on every child that has the
## method, once per enemy, before the enemy enters the tree.
##
## Deliberately not "give every enemy a debuff item in the shipped game": that is
## a balance change, and `docs/systems/balance.md` governs those. This keeps the
## player's debuff row reachable for a visual check and nothing else.
func _equip_enemy_items() -> void:
	if enemy_item_name.is_empty():
		return
	var enemy_spawner := get_node_or_null("../StageManager/EnemySpawner") as EnemySpawner
	if enemy_spawner == null:
		push_warning("DebugScenarioSetup: no EnemySpawner for '%s' to give items to." % scenario_title)
		return
	var modifier := EnemyDebuffModifier.new()
	modifier.name = "EnemyDebuffModifier"
	modifier.item_path = "%s/%s.tres" % [ITEMS_DIR, enemy_item_name]
	modifier.chance = enemy_item_chance
	enemy_spawner.add_child(modifier)
	# `_ready()` collects the spawner's modifiers into a list before this node
	# exists, so adding the child alone would leave it never called.
	enemy_spawner.modifiers.append(modifier)


func _apply_start_mode() -> void:
	var stage_manager := get_node_or_null("../StageManager") as StageManager
	if stage_manager == null:
		push_warning("DebugScenarioSetup: no StageManager next to '%s'." % scenario_title)
		return

	match start_mode:
		StartMode.STAGE_ONE:
			# `StageManager._ready()` already ran stage 1 for us.
			pass
		StartMode.BOSS_STAGE:
			# The same call `_end_stage()` makes, so the boss gets the normal
			# scaling and the stage-end rule stays in one place.
			stage_manager.go_to_stage(2)
		StartMode.LOOP:
			# Each spawner keeps its own `current_loop`. `start_new_loop()` is
			# deliberately not used here: it advances the enemy spawner through
			# `_on_next_stage()`, which would leave the two counters disagreeing.
			stage_manager.current_loop = start_loop
			stage_manager.enemy_spawner.current_loop = start_loop
			stage_manager.boss_spawner.current_loop = start_loop
			# Re-enter the enemy stage so the wave is sized for the new loop
			# (`start_wave()` reads `current_loop`) instead of the loop-1 wave
			# that `_ready()` already started.
			stage_manager.go_to_stage(1)


## Applies the picker's monster density. Last of the three, because
## `_apply_start_mode()` can call `start_wave()`, which re-sizes the wave from
## `current_loop` and would drop a multiplier set before it.
func _apply_monster_multiplier() -> void:
	var stage_manager := get_node_or_null("../StageManager") as StageManager
	if stage_manager == null:
		push_warning("DebugScenarioSetup: no StageManager next to '%s'." % scenario_title)
		return
	if pending_monster_multiplier == 1.0:
		return
	stage_manager.enemy_spawner.set_spawn_multiplier(pending_monster_multiplier)


func _on_stage_applied() -> void:
	var stage_manager := get_node_or_null("../StageManager") as StageManager
	var stage := stage_manager.current_stage if stage_manager != null else 0
	var loop_number := stage_manager.current_loop if stage_manager != null else 0
	print(
		"Debug scenario '%s': stage %d, loop %d, %d weapons, stacked build: %s, monsters %.1fx, enemies get %s"
		% [
			scenario_title, stage, loop_number, weapon_names.size(),
			str(stacked_build), pending_monster_multiplier,
			enemy_item_name if not enemy_item_name.is_empty() else "nothing",
		]
	)
