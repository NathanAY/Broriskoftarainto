extends Node2D

## Dev-only preview: the final boss mid-fight, frozen part-way through a Safe
## Drop while a Burrow mound travels and a Coin Spiral has fired. For eyeballing
## the attack visuals at in-game size:
##
##     .\run_scene_shot.bat res://test/tools/final_boss_preview.tscn res://boss_shot.png 20
##
## Not shipped: nothing in `src/` loads this.

const BOSS_SCENE := preload("res://src/Systems/enemies/EnemyFinalBoss.tscn")
const BACKDROP := Color(0.55, 0.47, 0.36)
const STEP := 1.0 / 60.0


func _ready() -> void:
    var backdrop := ColorRect.new()
    backdrop.color = BACKDROP
    backdrop.size = get_viewport_rect().size
    # The arena floor's own z (`Arena.tscn`), so ground markers draw over it.
    backdrop.z_index = -10
    add_child(backdrop)
    var centre := get_viewport_rect().size * 0.5

    var target := Node2D.new()
    add_child(target)
    target.global_position = centre + Vector2(260, 60)

    var boss: Enemy = BOSS_SCENE.instantiate()
    add_child(boss)
    boss.set_physics_process(false)
    boss.global_position = centre + Vector2(-220, 0)
    boss.set_target_position(target)
    var brain := boss.behaviour as BossBrain

    var spiral := brain.get_node("CoinSpiral") as BossAttack
    spiral.start(boss, target)
    for i in 100:
        spiral.tick(STEP)

    var safe_drop := brain.get_node("SafeDrop") as BossAttack
    brain.rng.seed = 3
    safe_drop.start(boss, target)
    while safe_drop.step == BossAttack.Step.TELEGRAPH:
        safe_drop.tick(STEP)
    for i in 35:
        safe_drop.tick(STEP)

    # A second boss underground, so the mound shows too.
    var digger: Enemy = BOSS_SCENE.instantiate()
    add_child(digger)
    digger.set_physics_process(false)
    digger.global_position = centre + Vector2(150, -250)
    digger.set_target_position(target)
    var burrow := (digger.behaviour as BossBrain).get_node("Burrow") as BossAttack
    burrow.start(digger, target)
    while burrow.step == BossAttack.Step.TELEGRAPH:
        burrow.tick(STEP)
    burrow.tick(STEP)

    # A third boss in phase 3: broken art, mid-beam, inside a closing Margin Call.
    var broken: Enemy = BOSS_SCENE.instantiate()
    add_child(broken)
    broken.set_physics_process(false)
    broken.global_position = centre + Vector2(-380, 260)
    broken.set_target_position(target)
    var broken_brain := broken.behaviour as BossBrain
    broken.sprite.texture = broken_brain.broken_texture
    var beam := broken_brain.get_node("GoldenBeam") as BossAttack
    beam.start(broken, target)
    while beam.step == BossAttack.Step.TELEGRAPH:
        beam.tick(STEP)
    for i in 60:
        beam.tick(STEP)
    var margin := broken_brain.get_node("MarginCall") as BossAttack
    margin.start(broken, target)
    while margin.step == BossAttack.Step.TELEGRAPH:
        margin.tick(STEP)
    for i in 70:
        margin.tick(STEP)
