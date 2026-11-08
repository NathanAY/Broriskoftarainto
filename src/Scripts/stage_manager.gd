extends Node
class_name StageManager

## The run's high-level flow: `Wave -> Boss -> Shop` repeats for every loop, and
## after the last guaranteed loop the player chooses between the final boss and
## one more loop.
##
## A "loop" is one full difficulty round. `current_loop` starts at 1 and only
## climbs; there is no longer a `max_loops` ceiling the run is cut off at, because
## the player decides when to stop. `FINAL_BOSS_LOOP` is where that decision is
## first offered, and it is offered again after every extra loop taken.

## 1 = enemies, 2 = boss, 3 = shop (waits for the player).
const STAGE_WAVE := 1
const STAGE_BOSS := 2
const STAGE_SHOP := 3
## The final boss fight. Leaving it any way other than killing the boss is a loss.
const STAGE_FINAL_BOSS := 4

## The loop after which the player is first asked "final boss or one more loop?".
## Loops below this finish into a normal shop, exactly as they always did.
const FINAL_BOSS_LOOP := 3

@export var stage_duration = 20         # seconds per (non-boss) stage
@export var character: Character
@export var stage_time_elapsed: float = 0.0
@export var current_loop: int = 1       # which loop/round we're on
@export var current_stage: int = 1       # see STAGE_* above

@onready var enemy_spawner: EnemySpawner = $EnemySpawner
@onready var boss_spawner: BossSpawner   = $BossSpawner

var shop_portal_scene = preload("res://src/Systems/ShopPortal.tscn")
var run_end_screen = preload("res://src/Scenes/menu/RunEndScreen.tscn")
## The two "final boss or one more loop?" portals, spawned after the shop of
## `FINAL_BOSS_LOOP` and of every loop taken past it.
var loop_choice_portal_scene = preload("res://src/Systems/LoopChoicePortal.tscn")

var enemiesNode: Node = null
var stage_active: bool = true
## The choice portals currently waiting on the player, if any.
var loop_portals: Array[LoopChoicePortal] = []

func _ready():
    enemiesNode = get_node("../Nodes/Enemies")
    character.character_died.connect(_on_character_died)
    # Start first stage explicitly
    go_to_stage(STAGE_WAVE)


func _process(delta: float) -> void:
    if not stage_active:
        return

    match current_stage:
        STAGE_WAVE:
            _process_enemy_stage(delta)
        STAGE_BOSS, STAGE_FINAL_BOSS:
            _process_boss_stage(delta)


func _process_enemy_stage(delta: float) -> void:
    stage_time_elapsed += delta
    if stage_time_elapsed >= stage_duration:
        enemy_spawner.spawn_active = false
        # wait until all enemies die
        if enemiesNode.get_child_count() == 0:
            _end_stage()

func _process_boss_stage(_delta: float) -> void:
    # Wait until boss (or any enemies) are dead
    # We consider boss cleared when there are no enemies in the Enemies node
    if enemiesNode.get_child_count() == 0 and boss_spawner.spawn_active:
        boss_spawner.spawn_active = false
        _end_stage()


func _end_stage() -> void:
    # Called when current stage finishes its condition (time expired & no enemies OR boss dead)
    stage_active = false

    match current_stage:
        STAGE_WAVE:
            # finish enemy wave → go to boss stage
            go_to_stage(STAGE_BOSS)
        STAGE_BOSS:
            # finish boss → spawn shop portal and wait for player
            spawn_shop_portal()
        STAGE_FINAL_BOSS:
            # Killing the final boss is the win condition. Reaching this line is
            # the only way out of that stage other than dying.
            _show_win_screen()
        _:
            # shouldn't happen normally because shop flow is handled by the portal/ShopMenu
            push_warning("StageManager: _end_stage called in unexpected state: %d" % current_stage)


func spawn_shop_portal() -> void:
    set_stage_shop()

    var portal = shop_portal_scene.instantiate()
    portal.global_position = character.global_position + Vector2(0, -100)
    get_tree().current_scene.get_node("Nodes").add_child(portal)

    var menu: ShopMenu = get_tree().current_scene.get_node_or_null("UI/ShopMenu")
    if menu:
        # Connect the shop "Next Stage" signal to restart the loop.
        # Use one-shot connect to avoid duplicate connections. (Your PROJECT constant may differ.)
        # If your engine complains, replace CONNECT_ONE_SHOT with the appropriate constant or use Callable(self, "_on_shop_next_pressed")
        menu.next_stage_pressed.connect(_on_shop_next_pressed, CONNECT_ONE_SHOT)


## Moves the run into its shop stage without spawning a portal: the state a real
## boss kill puts it in, split out so a test can reach the shop without a portal.
func set_stage_shop() -> void:
    current_stage = STAGE_SHOP
    stage_time_elapsed = 0.0
    stage_active = false   # wait for player


func _on_shop_next_pressed() -> void:
    # Player confirmed "next stage" in shop. Past the last guaranteed loop the
    # run is about to end one way or the other, so the player picks how.
    if current_loop >= FINAL_BOSS_LOOP:
        offer_loop_choice()
    else:
        start_new_loop()


## Spawns the two "final boss or one more loop?" portals and waits for the
## answer. `stage_active` stays false throughout: neither answer is a stage that
## processes, and `go_to_stage()` turns it back on for whichever is picked.
func offer_loop_choice() -> void:
    stage_active = false
    clear_loop_portals()

    var final_portal := _spawn_loop_portal(
        LoopChoicePortal.Choice.FINAL_BOSS,
        "Final boss",
        Color(1.0, 0.55, 0.55),
        Vector2(-180, -100))
    final_portal.chosen.connect(_on_final_boss_chosen, CONNECT_ONE_SHOT)

    var extra_portal := _spawn_loop_portal(
        LoopChoicePortal.Choice.EXTRA_LOOP,
        "One more loop (loop %d)" % (current_loop + 1),
        Color(0.55, 0.85, 1.0),
        Vector2(180, -100))
    extra_portal.chosen.connect(_on_extra_loop_chosen, CONNECT_ONE_SHOT)


func _spawn_loop_portal(
        choice: LoopChoicePortal.Choice,
        label_text: String,
        tint: Color,
        offset: Vector2) -> LoopChoicePortal:
    var portal: LoopChoicePortal = loop_choice_portal_scene.instantiate()
    portal.choice = choice
    portal.label_text = label_text
    portal.tint = tint
    portal.global_position = character.global_position + offset
    get_tree().current_scene.get_node("Nodes").add_child(portal)
    loop_portals.append(portal)
    return portal


## Frees both choice portals. Picking one ends the question, and a death while
## the question is open must not leave a portal offering a fight to a player
## with no character.
func clear_loop_portals() -> void:
    for portal in loop_portals:
        if is_instance_valid(portal):
            portal.queue_free()
    loop_portals.clear()


func _on_final_boss_chosen(_choice: int) -> void:
    clear_loop_portals()
    go_to_stage(STAGE_FINAL_BOSS)


func _on_extra_loop_chosen(_choice: int) -> void:
    clear_loop_portals()
    start_new_loop()


## Advances to the next loop and starts its enemy wave. Not gated on a maximum
## loop count: the run only ends at the final boss or on death.
func start_new_loop() -> void:
    # increment loop counter and advance enemy spawner difficulty
    current_loop += 1

    # Inform boss spawner about new loop (so boss scaling uses loop count)
    if boss_spawner:
        boss_spawner.current_loop = current_loop

    # Tell enemy spawner to advance its internal stage (this increments enemy_spawner.current_stage)
    if enemy_spawner:
        enemy_spawner._on_next_stage()

    # Now go to enemies stage for the new loop
    go_to_stage(STAGE_WAVE)


func go_to_stage(stage: int) -> void:
    # Centralized stage transition
    current_stage = stage
    stage_time_elapsed = 0.0

    match stage:
        STAGE_WAVE:
            # Start a Wave (enemy period) for this loop via the spawner seam so
            # the cadence restarts at ~1s instead of inheriting a stale timer.
            stage_active = true
            # Boss should not spawn or be active during wave
            boss_spawner.spawn_active = false
            if enemy_spawner.has_method("start_wave"):
                enemy_spawner.start_wave()
            else:
                enemy_spawner.spawn_active = true
            # NOTE:
            # We purposely DON'T call enemy_spawner._on_next_stage() here,
            # because start_new_loop() already calls that when beginning a new loop.
            # At game start the spawner's current_stage is assumed to be correct (1).
            print("StageManager -> Stage 1 (Enemies). Loop: %d" % current_loop)
        STAGE_BOSS:
            # Start boss stage: stop normal spawns and spawn single boss
            stage_active = true
            enemy_spawner.spawn_active = false
            boss_spawner.spawn_active = true
            # Ensure boss spawner knows current loop
            boss_spawner.current_loop = current_loop
            boss_spawner.spawn_boss()
            print("StageManager -> Stage 2 (Boss). Loop: %d" % current_loop)
        STAGE_SHOP:
            # Shop stage: we wait for player, do not set stage_active true
            stage_active = false
            enemy_spawner.spawn_active = false
            boss_spawner.spawn_active = false
            print("StageManager -> Stage 3 (Shop). Loop: %d" % current_loop)
        STAGE_FINAL_BOSS:
            # The player chose to end the run here. Same encounter as an ordinary
            # boss, scaled past the loop the player banked - `spawn_final_boss()`
            # owns how far past.
            stage_active = true
            enemy_spawner.spawn_active = false
            boss_spawner.spawn_active = true
            boss_spawner.current_loop = current_loop
            boss_spawner.spawn_final_boss()
            print("StageManager -> Final boss. Loop: %d" % current_loop)
        _:
            push_warning("StageManager: go_to_stage() called with invalid stage: %s" % str(stage))

func _show_win_screen():
    print("YOU WIN!")
    var run_end: RunEndScreen = run_end_screen.instantiate()
    get_tree().current_scene.get_node("UI").add_child(run_end)
    run_end.label.text = "YOU WIN!"
    stage_active = false

func _on_character_died():
    print("YOU LOOSE!")
    # A death during the choice is still a death, and the portals would
    # otherwise sit over the run-end screen offering a fight to a player who no
    # longer has a character.
    clear_loop_portals()
    var run_end: RunEndScreen = run_end_screen.instantiate()
    get_tree().current_scene.get_node("UI").add_child(run_end)
    run_end.label.text = "D.E.F.E.T.E.D"
    stage_active = false
