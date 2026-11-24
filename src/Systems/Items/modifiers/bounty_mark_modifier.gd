extends BaseModifier
class_name BountyMarkModifier
## Every `interval` seconds one living enemy is marked with a gold ring. Killing
## a marked enemy pays `(coins_base + coins_per_loop × (loop - 1))` coins, ×
## `1 + bonus_per_extra_stack × (stacks - 1)`, scaled by `coin_gain`. Numbers
## come from the `economy_modifiers` config.

const META := "bounty_mark"
const RING_NAME := "BountyMarkRing"

@export var display_name: String = "Bounty Mark"
@export var trigger_event: String = "on_kill"


func get_tooltip_stats() -> String:
    var config := _economy_config()
    return "Mark an enemy every %ss: kill pays %d coins (+%d per loop)" % [
        str(config.get("interval", 0.0)), int(config.get("coins_base", 0)), int(config.get("coins_per_loop", 0))]


func attachEventManager(em: Node):
    _cache_holder(em)
    _subscribe("on_kill", _on_kill)
    var timer := Timer.new()
    timer.wait_time = maxf(0.1, float(_economy_config().get("interval", 10.0)))
    timer.autostart = true
    timer.timeout.connect(mark_random_enemy)
    add_child(timer)


static func is_marked(node: Object) -> bool:
    return is_instance_valid(node) and node.has_meta(META)


func mark(enemy: Node) -> void:
    enemy.set_meta(META, true)
    if enemy is Node2D and enemy.get_node_or_null(RING_NAME) == null:
        var ring := _MarkRing.new()
        ring.name = RING_NAME
        enemy.add_child(ring)


## Marks one living, unmarked enemy, if there is one.
func mark_random_enemy() -> void:
    var tree := Engine.get_main_loop() as SceneTree
    var candidates := tree.get_nodes_in_group("enemies").filter(
        func(enemy: Node) -> bool: return not enemy.is_queued_for_deletion() and not is_marked(enemy))
    if not candidates.is_empty():
        mark(candidates.pick_random())


func bounty() -> float:
    var config := _economy_config()
    var coins := float(config.get("coins_base", 0)) + float(config.get("coins_per_loop", 0)) * (StageManager.loop_of(self) - 1)
    return coins * (1.0 + float(config.get("bonus_per_extra_stack", 0.0)) * (_active_stacks() - 1))


func _on_kill(event: Dictionary) -> void:
    var ctx := event.get("damage_context") as DamageContext
    var character := holder as Character
    if ctx == null or character == null or not is_marked(ctx.target):
        return
    ctx.target.remove_meta(META)
    var coins := Wallet.coins_for(character, bounty())
    Wallet.earn(character, coins, "bounty")
    RunHistory.record(character, display_name, "coins", coins)


## The gold ring drawn under a marked enemy.
class _MarkRing extends Node2D:
    const COLOR := Color(1.0, 0.8, 0.2, 0.9)
    const RADIUS := 48.0
    const WIDTH := 4.0

    func _draw() -> void:
        draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 40, COLOR, WIDTH)
