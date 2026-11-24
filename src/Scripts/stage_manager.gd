extends Node
class_name StageManager

## The run's high-level flow: `Wave -> Boss -> Shop` repeats for every stage, and
## after the last guaranteed stage the player chooses between the final boss and
## one more stage.
##
## A "stage" is one full difficulty round. `current_stage` starts at 1 and only
## climbs; there is no longer a `max_stages` ceiling the run is cut off at, because
## the player decides when to stop. `FINAL_BOSS_STAGE` is where that decision is
## first offered, and it is offered again after every extra stage taken.

## The stage of the running game as seen from `node`, or 1 outside one (tests,
## previews, a detached node). The one lookup for shop prices, rerolls and the
## wallet's tally, so they cannot disagree about which stage it is.
static func stage_of(node: Node) -> int:
    if node == null or not node.is_inside_tree():
        return 1
    var scene := node.get_tree().current_scene
    # `as`, not a typed assignment: test harnesses name a plain Node "StageManager".
    var stage_manager := scene.get_node_or_null("StageManager") as StageManager if scene else null
    return stage_manager.current_stage if stage_manager else 1

## 1 = enemies, 2 = boss, 3 = shop (waits for the player).
const PHASE_WAVE := 1
const PHASE_BOSS := 2
const PHASE_SHOP := 3
## The final boss fight. Leaving it any way other than killing the boss is a loss.
const PHASE_FINAL_BOSS := 4

## The stage after which the player is first asked "final boss or one more stage?".
## Stages below this finish into a normal shop, exactly as they always did.
const FINAL_BOSS_STAGE := 3

@export var phase_duration = 20         # seconds per (non-boss) phase
@export var character: Character
@export var phase_time_elapsed: float = 0.0
@export var current_stage: int = 1       # which stage/round we're on
@export var current_phase: int = 1       # see PHASE_* above

@onready var enemy_spawner: EnemySpawner = $EnemySpawner
@onready var boss_spawner: BossSpawner   = $BossSpawner

var shop_portal_scene = preload("res://src/Systems/ShopPortal.tscn")
var run_end_screen = preload("res://src/Scenes/menu/RunEndScreen.tscn")
## The two "final boss or one more stage?" portals, spawned after the shop of
## `FINAL_BOSS_STAGE` and of every stage taken past it.
var stage_choice_portal_scene = preload("res://src/Systems/StageChoicePortal.tscn")

var enemiesNode: Node = null
var phase_active: bool = true
## The choice portals currently waiting on the player, if any.
var stage_portals: Array[StageChoicePortal] = []

func _ready():
    enemiesNode = get_node("../Nodes/Enemies")
    character.character_died.connect(_on_character_died)
    # Start first phase explicitly
    go_to_phase(PHASE_WAVE)


func _process(delta: float) -> void:
    if not phase_active:
        return

    match current_phase:
        PHASE_WAVE:
            _process_enemy_phase(delta)
        PHASE_BOSS, PHASE_FINAL_BOSS:
            _process_boss_phase(delta)


func _process_enemy_phase(delta: float) -> void:
    phase_time_elapsed += delta
    if phase_time_elapsed >= phase_duration:
        enemy_spawner.spawn_active = false
        # wait until all enemies die
        if enemiesNode.get_child_count() == 0:
            _end_phase()

func _process_boss_phase(_delta: float) -> void:
    # Wait until boss (or any enemies) are dead
    # We consider boss cleared when there are no enemies in the Enemies node
    if enemiesNode.get_child_count() == 0 and boss_spawner.spawn_active and not boss_spawner.is_spawning():
        boss_spawner.spawn_active = false
        _end_phase()


func _end_phase() -> void:
    # Called when current phase finishes its condition (time expired & no enemies OR boss dead)
    phase_active = false

    match current_phase:
        PHASE_WAVE:
            # finish enemy wave → go to boss phase
            go_to_phase(PHASE_BOSS)
        PHASE_BOSS:
            # finish boss → spawn shop portal and wait for player
            spawn_shop_portal()
        PHASE_FINAL_BOSS:
            # Killing the final boss is the win condition. Reaching this line is
            # the only way out of that phase other than dying.
            _show_win_screen()
        _:
            # shouldn't happen normally because shop flow is handled by the portal/ShopMenu
            push_warning("StageManager: _end_phase called in unexpected state: %d" % current_phase)


func spawn_shop_portal() -> void:
    set_phase_shop()

    var portal = shop_portal_scene.instantiate()
    portal.global_position = character.global_position + Vector2(0, -100)
    get_tree().current_scene.get_node("Nodes").add_child(portal)

    var menu: ShopMenu = get_tree().current_scene.get_node_or_null("UI/ShopMenu")
    if menu:
        # Connect the shop "Next Stage" signal to restart the stage.
        # Use one-shot connect to avoid duplicate connections. (Your PROJECT constant may differ.)
        # If your engine complains, replace CONNECT_ONE_SHOT with the appropriate constant or use Callable(self, "_on_shop_next_pressed")
        menu.next_stage_pressed.connect(_on_shop_next_pressed, CONNECT_ONE_SHOT)


## Moves the run into its shop phase without spawning a portal: the state a real
## boss kill puts it in, split out so a test can reach the shop without a portal.
func set_phase_shop() -> void:
    current_phase = PHASE_SHOP
    phase_time_elapsed = 0.0
    phase_active = false   # wait for player


func _on_shop_next_pressed() -> void:
    # Player confirmed "next stage" in shop. Past the last guaranteed stage the
    # run is about to end one way or the other, so the player picks how.
    if current_stage >= FINAL_BOSS_STAGE:
        offer_stage_choice()
    else:
        start_new_stage()


## Spawns the two "final boss or one more stage?" portals and waits for the
## answer. `phase_active` stays false throughout: neither answer is a phase that
## processes, and `go_to_phase()` turns it back on for whichever is picked.
func offer_stage_choice() -> void:
    phase_active = false
    clear_stage_portals()

    var final_portal := _spawn_stage_portal(
        StageChoicePortal.Choice.FINAL_BOSS,
        "Finale Gate\nEnd the run here.\nFace the final boss now.",
        Color(1.0, 0.55, 0.55),
        Vector2(-180, -100))
    final_portal.chosen.connect(_on_final_boss_chosen, CONNECT_ONE_SHOT)

    var extra_portal := _spawn_stage_portal(
        StageChoicePortal.Choice.EXTRA_STAGE,
        "Deeper Gate (Stage %d)\nThe Finale can wait. Face harder stages,\ngather more power, then return." % (current_stage + 1),
        Color(0.55, 0.85, 1.0),
        Vector2(180, -100))
    extra_portal.chosen.connect(_on_extra_stage_chosen, CONNECT_ONE_SHOT)


func _spawn_stage_portal(
        choice: StageChoicePortal.Choice,
        label_text: String,
        tint: Color,
        offset: Vector2) -> StageChoicePortal:
    var portal: StageChoicePortal = stage_choice_portal_scene.instantiate()
    portal.choice = choice
    portal.label_text = label_text
    portal.tint = tint
    portal.global_position = character.global_position + offset
    get_tree().current_scene.get_node("Nodes").add_child(portal)
    stage_portals.append(portal)
    return portal


## Frees both choice portals. Picking one ends the question, and a death while
## the question is open must not leave a portal offering a fight to a player
## with no character.
func clear_stage_portals() -> void:
    for portal in stage_portals:
        if is_instance_valid(portal):
            portal.queue_free()
    stage_portals.clear()


func _on_final_boss_chosen(_choice: int) -> void:
    clear_stage_portals()
    go_to_phase(PHASE_FINAL_BOSS)


func _on_extra_stage_chosen(_choice: int) -> void:
    clear_stage_portals()
    start_new_stage()


## Advances to the next stage and starts its enemy wave. Not gated on a maximum
## stage count: the run only ends at the final boss or on death.
func start_new_stage() -> void:
    # increment stage counter and advance enemy spawner difficulty
    current_stage += 1

    # Inform boss spawner about new stage (so boss scaling uses stage count)
    if boss_spawner:
        boss_spawner.current_stage = current_stage

    # Tell enemy spawner to advance its internal phase (this increments enemy_spawner.current_phase)
    if enemy_spawner:
        enemy_spawner._on_next_stage()

    # Fresh arena look every stage
    var arena := get_tree().get_first_node_in_group("arena") as Arena
    if arena:
        arena.randomize_theme()

    # Now go to enemies phase for the new stage
    go_to_phase(PHASE_WAVE)


func go_to_phase(phase: int) -> void:
    # Centralized phase transition
    current_phase = phase
    phase_time_elapsed = 0.0

    match phase:
        PHASE_WAVE:
            # Start a Wave (enemy period) for this stage via the spawner seam so
            # the cadence restarts at ~1s instead of inheriting a stale timer.
            phase_active = true
            # Boss should not spawn or be active during wave
            boss_spawner.spawn_active = false
            if enemy_spawner.has_method("start_wave"):
                enemy_spawner.start_wave()
            else:
                enemy_spawner.spawn_active = true
            # NOTE:
            # We purposely DON'T call enemy_spawner._on_next_stage() here,
            # because start_new_stage() already calls that when beginning a new stage.
            # At game start the spawner's current_phase is assumed to be correct (1).
            print("StageManager -> Phase 1 (Enemies). Stage: %d" % current_stage)
        PHASE_BOSS:
            # Start boss phase: stop normal spawns and spawn single boss
            phase_active = true
            enemy_spawner.spawn_active = false
            boss_spawner.spawn_active = true
            # Ensure boss spawner knows current stage
            boss_spawner.current_stage = current_stage
            boss_spawner.spawn_boss()
            print("StageManager -> Phase 2 (Boss). Stage: %d" % current_stage)
        PHASE_SHOP:
            # Shop phase: we wait for player, do not set phase_active true
            phase_active = false
            enemy_spawner.spawn_active = false
            boss_spawner.spawn_active = false
            print("StageManager -> Phase 3 (Shop). Stage: %d" % current_stage)
        PHASE_FINAL_BOSS:
            # The player chose to end the run here. Same encounter as an ordinary
            # boss, scaled past the stage the player banked - `spawn_final_boss()`
            # owns how far past.
            phase_active = true
            enemy_spawner.spawn_active = false
            boss_spawner.spawn_active = true
            boss_spawner.current_stage = current_stage
            boss_spawner.spawn_final_boss()
            print("StageManager -> Final boss. Stage: %d" % current_stage)
        _:
            push_warning("StageManager: go_to_phase() called with invalid phase: %s" % str(phase))

func _show_win_screen():
    print("YOU WIN!")
    var run_end: RunEndScreen = run_end_screen.instantiate()
    get_tree().current_scene.get_node("UI").add_child(run_end)
    run_end.label.text = "YOU WIN!"
    phase_active = false

func _on_character_died():
    print("YOU LOOSE!")
    # A death during the choice is still a death, and the portals would
    # otherwise sit over the run-end screen offering a fight to a player who no
    # longer has a character.
    clear_stage_portals()
    var run_end: RunEndScreen = run_end_screen.instantiate()
    get_tree().current_scene.get_node("UI").add_child(run_end)
    run_end.label.text = "D.E.F.E.T.E.D"
    phase_active = false
