extends Node
class_name StageManager

@export var stage_duration = 10         # seconds per (non-boss) stage
@export var character: Character
@export var stage_time_elapsed: float = 0.0
@export var max_loops: int = 3         # <--- after this player wins
@export var current_loop: int = 1        # which loop/round we're on
@export var current_stage: int = 1       # 1 = enemies, 2 = boss, 3 = shop

@onready var enemy_spawner: EnemySpawner = $EnemySpawner
@onready var boss_spawner: BossSpawner   = $BossSpawner

var shop_portal_scene = preload("res://Systems/ShopPortal.tscn")
var win_screen_scene = preload("res://Scenes/menu/WinScreen.tscn") 

var enemiesNode: Node = null
var stage_active: bool = true

func _ready():
    enemiesNode = get_node("../Nodes/Enemies")
    # Start first stage explicitly
    go_to_stage(1)


func _process(delta: float) -> void:
    if not stage_active:
        return

    match current_stage:
        1:
            _process_enemy_stage(delta)
        2:
            _process_boss_stage(delta)
        3:
            # shop stage waits for player's action; shouldn't happen while active=true
            pass


func _process_enemy_stage(delta: float) -> void:
    stage_time_elapsed += delta
    if stage_time_elapsed >= stage_duration:
        enemy_spawner.spawn_active = false
        # wait until all enemies die
        if enemiesNode.get_child_count() == 0:
            _end_stage()


func _process_boss_stage(delta: float) -> void:
    # Wait until boss (or any enemies) are dead
    # We consider boss cleared when there are no enemies in the Enemies node
    if enemiesNode.get_child_count() == 0 and boss_spawner.spawn_active:
        boss_spawner.spawn_active = false
        _end_stage()


func _end_stage() -> void:
    # Called when current stage finishes its condition (time expired & no enemies OR boss dead)
    stage_active = false

    if current_stage == 1:
        # finish enemy wave → go to boss stage
        go_to_stage(2)
    elif current_stage == 2:
        # finish boss → spawn shop portal and wait for player
        spawn_shop_portal()
        # current_stage is set to 3 inside spawn_shop_portal and stage_active left false
    else:
        # shouldn't happen normally because shop flow is handled by the portal/ShopMenu
        push_warning("StageManager: _end_stage called in unexpected state: %d" % current_stage)


func spawn_shop_portal() -> void:
    current_stage = 3
    stage_time_elapsed = 0.0
    stage_active = false   # wait for player

    var portal = shop_portal_scene.instantiate()
    portal.global_position = character.global_position + Vector2(0, -100)
    get_tree().current_scene.get_node("Nodes").add_child(portal)

    var menu: ShopMenu = get_tree().current_scene.get_node_or_null("UI/ShopMenu")
    if menu:
        # Connect the shop "Next Stage" signal to restart the loop.
        # Use one-shot connect to avoid duplicate connections. (Your PROJECT constant may differ.)
        # If your engine complains, replace CONNECT_ONE_SHOT with the appropriate constant or use Callable(self, "_on_shop_next_pressed")
        menu.next_stage_pressed.connect(_on_shop_next_pressed, CONNECT_ONE_SHOT)


func _on_shop_next_pressed() -> void:
    # Player confirmed "next stage" in shop → start a new loop (increase difficulty)
    start_new_loop()


func start_new_loop() -> void:
    # increment loop counter and advance enemy spawner difficulty
    current_loop += 1
    if current_loop > max_loops:
        _show_win_screen()
        return

    # Inform boss spawner about new loop (so boss scaling uses loop count)
    if boss_spawner:
        boss_spawner.current_loop = current_loop

    # Tell enemy spawner to advance its internal stage (this increments enemy_spawner.current_stage)
    if enemy_spawner:
        enemy_spawner._on_next_stage()

    # Now go to enemies stage for the new loop
    go_to_stage(1)


func go_to_stage(stage: int) -> void:
    # Centralized stage transition
    current_stage = stage
    stage_time_elapsed = 0.0

    match stage:
        1:
            # Start spawning enemy waves for this loop
            stage_active = true
            enemy_spawner.spawn_active = true
            # Boss should not spawn or be active during wave
            boss_spawner.spawn_active = false
            # NOTE:
            # We purposely DON'T call enemy_spawner._on_next_stage() here,
            # because start_new_loop() already calls that when beginning a new loop.
            # At game start the spawner's current_stage is assumed to be correct (1).
            print("StageManager -> Stage 1 (Enemies). Loop: %d" % current_loop)
        2:
            # Start boss stage: stop normal spawns and spawn single boss
            stage_active = true
            enemy_spawner.spawn_active = false
            boss_spawner.spawn_active = true
            # Ensure boss spawner knows current loop
            boss_spawner.current_loop = current_loop
            boss_spawner.spawn_boss()
            print("StageManager -> Stage 2 (Boss). Loop: %d" % current_loop)
        3:
            # Shop stage: we wait for player, do not set stage_active true
            stage_active = false
            enemy_spawner.spawn_active = false
            boss_spawner.spawn_active = false
            print("StageManager -> Stage 3 (Shop). Loop: %d" % current_loop)
        _:
            push_warning("StageManager: go_to_stage() called with invalid stage: %s" % str(stage))

func _show_win_screen():
    print("YOU WIN!")
    var win_screen = win_screen_scene.instantiate()
    get_tree().current_scene.get_node("UI").add_child(win_screen)
    stage_active = false
