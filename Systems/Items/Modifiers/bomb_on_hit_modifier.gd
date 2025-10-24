extends Node
class_name BombModifier

var explosion_scene := preload("res://Scenes/Explosion.tscn")
var bomb_scene := preload("res://Scenes/Bomb.tscn") # optional, for visuals

var explosion_radius := 64.0
var explosion_damage := 0.3 #30% of initional damage
var detonation_delay := 3.0

var _tag = "bomb_modifier"
var event_manager: EventManager = null
var stacks: Array[bool] = []  # each entry = active/inactive

func attachEventManager(em: Node):
    event_manager = em
    event_manager.subscribe("on_hit", Callable(self, "_on_hit"))
    event_manager.subscribe("on_stat_changes", Callable(self, "_on_stat_changes"))

func add_stack(active: bool):
    stacks.append(active)
    prints("add_stack", stacks)

func remove_stack(index: int):
    if index >= 0 and index < stacks.size():
        stacks.remove_at(index)
    prints("remove_stack", stacks)

func set_stack_active(index: int, active: bool):
    if index >= 0 and index < stacks.size():
        stacks[index] = active
    prints("set_stack_active", stacks)

func _on_hit(event: Dictionary):
    var ctx: DamageContext = event.get("damage_context")
    if not ctx or not ctx.target:
        return
    if ctx.tags.has(_tag):
        return
    _attach_bomb(ctx.target, ctx.final_amount)

func _attach_bomb(target: Node, damage: int):
    # ensure target has a place to attach
    if not is_instance_valid(target):
        return

    var bomb_visual = bomb_scene.instantiate()
    target.add_child(bomb_visual)
    var position: Vector2 = target.global_position
    position.x = position.x + randi_range(-20, 20)
    position.y = position.y + randi_range(-20, 20)
    bomb_visual.global_position = position

    # create a timer to detonate
    var timer = Timer.new()
    timer.one_shot = true
    timer.wait_time = detonation_delay
    timer.connect("timeout", Callable(self, "_detonate").bind(target, damage, bomb_visual, timer))
    add_child(timer)
    timer.start()

func _detonate(target: Node, damage: int, bomb_visual: Node, timer: Timer):
    if bomb_visual and is_instance_valid(bomb_visual):
        bomb_visual.queue_free()
    timer.queue_free()

    if not is_instance_valid(target):
        return

    var stacks_multiplier = 5.0 / (4 + stacks.count(true))# +20% per stack
    # spawn explosion at target position
    var explosion: Explosion = explosion_scene.instantiate()
    explosion.attachEventManager(event_manager)
    explosion.damage_tags.append(_tag)
    explosion.global_position = target.global_position
    explosion.radius = explosion_radius
    explosion.damage = damage * explosion_damage * stacks_multiplier
    get_tree().current_scene.add_child(explosion)

func _on_stat_changes(stat_name: String, value: float):
    match stat_name:
        "damage":
            explosion_damage = value
