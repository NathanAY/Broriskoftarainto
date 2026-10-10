# res://src/scripts/weapons/base_weapon.gd
extends Resource
class_name BaseWeapon

@export var name: String
@export var description: String
@export var base_attack_speed: float = 1.0
@export var base_damage: float = 5.0
@export var modifiers: Dictionary = {}
@export var target_selector: TargetSelector
@export var sprite: Texture2D    # assign in .tres
@export var sprite_offset: Vector2 = Vector2.ZERO  # for fine positioning if needed
@export var attack_sound: Array[Resource] = []

## How far this weapon reaches, **in meters**. The unit the player is shown, so
## a `.tres` reads 1.0 rather than 300 and a designer can compare two weapons
## without converting. Convert at the point of use with [method get_range_px]
## rather than reading this field directly.
@export var weapon_range: float = 1.33

## [member weapon_range] in pixels - the only form the target selectors, the
## melee swing and the aura's radius take. A getter rather than a separate
## field so the number damage is measured against cannot drift from the number
## the tooltip prints.
func get_range_px() -> float:
    return Stats.meters_to_px(weapon_range)

# --- tooltip contract --------------------------------------------------------
# `ItemTooltip.weapon_card_rows` owns the card's row format; a weapon only says
# *what* to show. Both hooks are virtual, so a new weapon surfaces its own
# numbers by overriding them here instead of `ItemTooltip` growing another
# `if weapon is ShotgunWeapon` branch.

## Extra `[label, value]` rows the card shows after the shared damage / range /
## attack-speed rows. Override and append for numbers only the subclass knows
## (a shotgun's pellet count). Keep it additive: call `super()` first.
func tooltip_details() -> Array:
    return []

## Whether the shared "Range" row applies. A contact weapon (Thorns) is driven
## by the holder's own hitbox rather than a reach, so it has no range to show.
func has_tooltip_range() -> bool:
    return true

## Damage one swing deals: (base_damage + flat_weapon_damage) * damage.
##
## This is a getter rather than a cached field on purpose. `BaseWeapon` is a
## Resource, so a member initializer runs while the object is still bare -
## before Godot writes the `.tres` values into it. Seeding the field from
## `base_damage` there captured the *script default* (5.0) instead of the
## weapon's configured value, and nothing recomputed it until the first
## `on_stat_changes` event arrived. That made the first hit of a run deal the
## default damage while every hit after it dealt the real value.
##
## Computing on read also keeps damage correct for a weapon whose holder has no
## Stats yet: `apply_to` may not have run, and a stat that changes without an
## event can no longer leave a stale number behind.
##
## No leading underscore: every weapon subclass and `melee_weapon_node.gd` read
## this, and a getter-only member that this class never reads itself is reported
## as unused.
var current_damage: float:
    get:
        if not is_instance_valid(stats):
            return base_damage
        return (base_damage + stats.get_stat("flat_weapon_damage")) * stats.get_stat("damage")

var _current_attack_speed

var holder_ref: WeakRef
var stats: Stats
var event_manager: Node
var timer: Timer     # each weapon has its own firing timer
var sprite_node: Sprite2D  # visual instance of this weapon

# Bound built-in modifier nodes created from this weapon's `modifiers` dict.
# Owned by `WeaponBuiltinEffects`, which fills and clears it from outside this
# class - hence no leading underscore. GDScript reports an underscore-prefixed
# member that is never read *inside* its own class as unused, which this is not.
var bound_effect_nodes: Array[Node] = []

#groups to ignore (friendly fire)
var ignore_groups: Array = []

func apply_to(holder: Node) -> void:
    holder_ref = weakref(holder)
    event_manager = holder.get_node_or_null("EventManager")
    stats = holder.get_node_or_null("Stats")
    ignore_groups = holder.get_groups().filter(func(g): return g != "damageable")

    # create and start timer
    timer = Timer.new()
    timer.one_shot = false
    holder.add_child(timer) # attach to holder so it ticks
    timer.timeout.connect(_on_timeout)
    _update_timer_wait()
    # A Timer only ticks once it is inside the scene tree, and calling start()
    # before that is an engine error rather than a deferred start. Weapons can be
    # equipped while their holder is still off-tree - buying in the shop builds
    # the character before it enters the stage - so in that case wait and start
    # from the tree instead. Starting immediately when the timer is already live
    # keeps the common path byte-for-byte as it was.
    #
    # The signal is the *timer's* own `tree_entered`, not the holder's: Godot
    # emits a parent's `tree_entered` before it recurses into the children, so a
    # handler on the holder would still see an off-tree timer and fail exactly as
    # before. Waiting on the timer itself cannot run early.
    if timer.is_inside_tree():
        timer.start()
    else:
        timer.tree_entered.connect(_start_timer_when_holder_enters_tree, CONNECT_ONE_SHOT)

    if event_manager:
        event_manager.subscribe("on_stat_changes", Callable(self, "_on_stat_changes"))

    WeaponBuiltinEffects.attach_for_weapon(self, holder, event_manager)

## Deferred half of the timer start in `apply_to`, for a holder that was still
## off-tree when the weapon was equipped. One-shot, so it fires at most once.
func _start_timer_when_holder_enters_tree() -> void:
    if timer and is_instance_valid(timer):
        timer.start()

func remove_from(_holder: Node) -> void:
    WeaponBuiltinEffects.detach(self)

    # Cancel the deferred start if the weapon is removed before it ever reaches
    # the tree, otherwise this stays wired to a dead weapon.
    if timer and is_instance_valid(timer) \
            and timer.tree_entered.is_connected(_start_timer_when_holder_enters_tree):
        timer.tree_entered.disconnect(_start_timer_when_holder_enters_tree)

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
        targets = target_selector.find_targets(sprite_node, get_range_px(), holder)

    if targets.size() > 0:
        try_shoot(targets)

func _update_timer_wait() -> void:
    if not timer: return
    var holder = get_holder()
    var _stats_node: Node = holder.get_node_or_null("Stats") if holder else null

    var base_weapon_speed := base_attack_speed
    var owner_speed = stats.get_stat("attack_speed") if stats else 1.0
    _current_attack_speed = owner_speed * base_weapon_speed
    if _current_attack_speed <= 0.001:
        _current_attack_speed = 0.001
    timer.wait_time = 1.0 / _current_attack_speed

func _on_stat_changes(_event) -> void:
    _update_timer_wait()

func aim() -> void:
    if not sprite_node or not is_instance_valid(sprite_node):
        return
    var holder = get_holder()
    if not holder: return

    var targets: Array[Node] = []
    if target_selector:
        targets = target_selector.find_targets(sprite_node, get_range_px(), holder)

    if targets.size() == 0:
        return

    var target = targets[0]
    var dir = (target.global_position - sprite_node.global_position).normalized()
    sprite_node.rotation = dir.angle()
    sprite_node.flip_v = dir.x < 0

# --- abstract shoot ---
func try_shoot(_targets: Array[Node]) -> void:
    push_warning("BaseWeapon: try_shoot not implemented for %s" % name)
