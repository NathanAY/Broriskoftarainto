# res://scripts/weapons/base_weapon.gd
extends Resource
class_name BaseWeapon

@export var name: String
@export var description: String
@export var base_attack_speed: float = 1.0
@export var base_damage: float = 5.0
@export var range: float = 400.0
@export var modifiers: Dictionary = {}
@export var target_selector: TargetSelector
@export var sprite: Texture2D    # assign in .tres
@export var sprite_offset: Vector2 = Vector2.ZERO  # for fine positioning if needed

var holder_ref: WeakRef
var event_manager: Node
var timer: Timer     # each weapon has its own firing timer
var sprite_node: Sprite2D  # visual instance of this weapon

#groups to ignore (friendly fire)
var ignore_groups: Array = []

func apply_to(holder: Node) -> void:
    holder_ref = weakref(holder)
    event_manager = holder.get_node_or_null("EventManager")

    # create and start timer
    timer = Timer.new()
    timer.one_shot = false
    holder.add_child(timer) # attach to holder so it ticks
    timer.timeout.connect(_on_timeout)
    _update_timer_wait()
    timer.start()

    if event_manager:
        event_manager.subscribe("on_stat_changes", Callable(self, "_on_stat_changes"))

func remove_from(holder: Node) -> void:
    if timer and is_instance_valid(timer):
        timer.stop()
        timer.queue_free()
    timer = null

    if sprite_node and is_instance_valid(sprite_node):
        sprite_node.queue_free()
    sprite_node = null

    if event_manager:
        event_manager.unsubscribe("on_stat_changes", Callable(self, "_on_stat_changes"))
    event_manager = null
    holder_ref = null

func get_holder() -> Node:
    return holder_ref.get_ref() if holder_ref and holder_ref.get_ref() else null

# --- runtime loop ---
func _on_timeout() -> void:
    var holder = get_holder()
    if not holder: return

    var targets: Array[Node] = []
    if target_selector:
        targets = target_selector.find_targets(sprite_node, range, holder)

    if targets.size() > 0:
        try_shoot(targets)

func _update_timer_wait() -> void:
    if not timer: return
    var holder = get_holder()
    var stats_node: Node = holder.get_node_or_null("Stats") if holder else null

    var base_weapon_speed := base_attack_speed
    var owner_speed = stats_node.get_stat("attack_speed") if stats_node and stats_node.has_method("get_stat") else 1.0
    var combined = owner_speed * base_weapon_speed
    if combined <= 0.001:
        combined = 0.001
    timer.wait_time = 1.0 / combined

func _on_stat_changes(_event) -> void:
    _update_timer_wait()

func aim() -> void:
    if not sprite_node or not is_instance_valid(sprite_node):
        return
    var holder = get_holder()
    if not holder: return

    var targets: Array[Node] = []
    if target_selector:
        targets = target_selector.find_targets(sprite_node, range, holder)

    if targets.size() == 0:
        return

    var target = targets[0]
    var dir = (target.global_position - sprite_node.global_position).normalized()
    sprite_node.rotation = dir.angle()
    sprite_node.flip_v = dir.x < 0

# --- abstract shoot ---
func try_shoot(targets: Array[Node]) -> void:
    push_warning("BaseWeapon: try_shoot not implemented for %s" % name)
