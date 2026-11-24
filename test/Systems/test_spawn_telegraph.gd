# An enemy does not pop in: a teleport effect plays on the spot first, and the
# enemy only appears once `spawn_telegraph_time` has passed.
class_name SpawnTelegraphTest
extends GdUnitTestSuite


func _build_tree(telegraph: float) -> Dictionary:
    var root: Node = auto_free(Node.new())
    root.name = "TestRoot"
    add_child(root)
    var nodes := Node.new()
    nodes.name = "Nodes"
    root.add_child(nodes)
    var enemies := Node.new()
    enemies.name = "Enemies"
    nodes.add_child(enemies)
    var stage := Node.new()
    stage.name = "StageManager"
    root.add_child(stage)
    var character: Character = auto_free(load("res://src/Systems/Character.tscn").instantiate())
    root.add_child(character)
    var spawner: EnemySpawner = auto_free(load("res://src/Systems/EnemySpawner.tscn").instantiate())
    spawner.set("character", character)
    spawner.spawn_telegraph_time = telegraph
    spawner.use_group_spawning = false
    stage.add_child(spawner)
    return {"nodes": nodes, "enemies": enemies, "spawner": spawner}


func _portals(nodes: Node) -> Array:
    return nodes.get_children().filter(func(n): return n is SpawnPortal)


func test_enemy_appears_only_after_the_effect_has_played() -> void:
    var ctx := _build_tree(0.2)
    var spawner: EnemySpawner = ctx["spawner"]
    var enemies: Node = ctx["enemies"]

    spawner.spawn_enemy()

    assert_int(enemies.get_child_count()).is_equal(0)
    assert_int(_portals(ctx["nodes"]).size()).is_equal(1)
    # A pending spawn already counts as alive, so pacing does not overshoot.
    assert_int(spawner._alive_count()).is_equal(1)

    await await_millis(400)

    assert_int(enemies.get_child_count()).is_equal(1)
    assert_int(_portals(ctx["nodes"]).size()).is_equal(0)
    assert_int(spawner._alive_count()).is_equal(1)


func test_boss_appears_after_the_effect_and_the_stage_waits_for_it() -> void:
    var ctx := _build_tree(0.0)
    var spawner: BossSpawner = auto_free(load("res://src/Systems/BossSpawner.tscn").instantiate())
    spawner.character = ctx["spawner"].character
    spawner.spawn_telegraph_time = 0.2
    ctx["spawner"].get_parent().add_child(spawner)

    spawner.spawn_boss()
    spawner.spawn_boss() # a second call while teleporting must not queue a second boss

    assert_int(ctx["enemies"].get_child_count()).is_equal(0)
    assert_int(_portals(ctx["nodes"]).size()).is_equal(1)
    # StageManager reads an empty arena as "boss dead" unless this is true.
    assert_bool(spawner.is_spawning()).is_true()

    await await_millis(400)

    assert_int(ctx["enemies"].get_child_count()).is_equal(1)
    assert_bool(spawner.is_spawning()).is_false()
    assert_object(spawner.boss_instance).is_not_null()
    assert_int(_portals(ctx["nodes"]).size()).is_equal(0)


func test_zero_telegraph_spawns_instantly_without_an_effect() -> void:
    var ctx := _build_tree(0.0)

    ctx["spawner"].spawn_enemy()

    assert_int(ctx["enemies"].get_child_count()).is_equal(1)
    assert_int(_portals(ctx["nodes"]).size()).is_equal(0)


# Stands in for a real spawner modifier. Its typed `Character` parameter is what
# turns a freed character into a hard "invalid type" error, as in the bug report.
class _ModifierStub extends Node:
    var calls := 0

    func attach_to_enemy(_enemy: Node, _character: Character) -> void:
        calls += 1


## Regression: the character dies while an enemy is still teleporting in. The
## spawn must be dropped quietly, and no modifier may be handed the dead character.
func test_character_dying_during_the_telegraph_spawns_nothing() -> void:
    var ctx := _build_tree(0.2)
    var spawner: EnemySpawner = ctx["spawner"]
    var enemies: Node = ctx["enemies"]
    var stub: _ModifierStub = auto_free(_ModifierStub.new())
    spawner.modifiers.append(stub)

    spawner.spawn_enemy()
    spawner.character.free()
    await await_millis(400)

    assert_int(enemies.get_child_count()).is_equal(0)
    assert_int(stub.calls).is_equal(0)


func test_the_effect_sits_where_the_enemy_appears() -> void:
    var ctx := _build_tree(0.2)

    ctx["spawner"].spawn_enemy()
    var portal_position: Vector2 = _portals(ctx["nodes"])[0].global_position
    await await_millis(400)

    var enemy := ctx["enemies"].get_child(0) as Node2D
    # The enemy starts chasing the moment it spawns, so allow for that drift; a
    # spot picked separately from the portal's would be hundreds of px away.
    assert_float(enemy.global_position.distance_to(portal_position)).is_less(100.0)
