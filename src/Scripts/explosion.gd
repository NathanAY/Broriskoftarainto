extends Area2D
class_name Explosion

## Blast radius in **meters**, the unit a designer authors and the tooltip would
## show. `get_radius_px()` is the only pixel form - the collision shape and the
## particle burst both take it, so neither can drift from the authored number.
@export var radius: float = 0.33
@export var damage: float = 10

## How long the blast **damages**, in seconds. The `CollisionShape2D` is switched
## off the moment this elapses, so a lingering explosion cannot go on hurting
## things that walk into the smoke.
@export var duration: float = 0.15

## How long the node stays alive to play its visual, in seconds. Longer than
## [member duration] because the burst's smoke outlives the flash; the node
## exists only because it is the burst's parent.
@export var visual_duration: float = 0.9

var time_passed: float = 0.0
var damage_tags: Array[String] = []

## The blast visual. Parented to the explosion rather than spawned beside it, so
## the node's own lifetime is what keeps it alive for as long as the particles
## need and not a frame longer.
@export var burst_scene: PackedScene = preload("res://src/Scenes/particles/explosion_burst.tscn")

var event_manager: EventManager = null 
var holder: Node = null
var stats: Stats = null
var _burst: ExplosionBurst = null
var _shape: CollisionShape2D = null

## [member radius] in pixels. A getter rather than a cached field so the shape
## keeps matching after `area_size_multiplier` rewrites `radius` in `_ready`.
func get_radius_px() -> float:
    return Stats.meters_to_px(radius)

func _ready():
    if stats:
        var area_multiplier: float = stats.get_stat("area_size_multiplier")
        radius *= area_multiplier
    _shape = get_node_or_null("CollisionShape2D")
    if _shape != null:
        _shape.shape.radius = get_radius_px()
    connect("body_entered", Callable(self, "_on_body_entered"))
    _spawn_burst()

## Plays the blast at the same radius the collision shape took.
##
## `radius` is set after `add_child` by every spawner, and `_ready` is what
## converts it to pixels, so this has to happen in `_ready` rather than in the
## spawner - otherwise the burst would be drawn at the authored radius while the
## damage used the `area_size_multiplier`-scaled one.
func _spawn_burst():
    if burst_scene == null:
        return
    _burst = burst_scene.instantiate() as ExplosionBurst
    if _burst == null:
        return
    _burst.radius = get_radius_px()
    add_child(_burst)
    # The scene's own layer lifetimes are the floor; `visual_duration` only has to
    # cover them. A layer retuned longer in the editor extends the explosion with
    # it rather than getting truncated by a stale number over here.
    visual_duration = maxf(visual_duration, _burst.get_longest_lifetime())

func attachEventManager(em: EventManager):
    event_manager = em
    holder = em.get_parent()
    stats = holder.get_node_or_null("Stats")

## Runs to [member visual_duration], not [member duration]: the blast visual's
## smoke lives well past the damage window, and the node has to stay parented
## to it until then.
func _process(delta: float):
    time_passed += delta
    if time_passed >= duration and _shape != null and not _shape.disabled:
        _shape.set_deferred("disabled", true)
    if time_passed >= maxf(duration, visual_duration):
        queue_free()

func _on_body_entered(body: Node):
    if body.has_node("Health"):
        do_damage(body)
    else:
        print("Explosion.gd: Body has no Health node!")

func do_damage(body):
    var ctx = DamageContext.new()
    ctx.source = self
    ctx.target = body
    ctx.base_amount = damage
    ctx.final_amount = damage
    ctx.tags.append("explosion")
    ctx.tags.append_array(damage_tags)
    if event_manager: 
        event_manager.emit_event("before_deal_damage", {"damage_context": ctx})
    var bodyHealth: Health = body.get_node("Health")
    if not bodyHealth.apply_damage(ctx):
        return  # already dead: the blast does not land, so no hit/kill events either
    if event_manager:
        event_manager.emit_event("after_deal_damage", {"explosion": self, "body": body, "damage_context": ctx})
    if event_manager:
        event_manager.emit_event("on_hit", {"explosion": self, "body": body, "damage_context": ctx})
    if event_manager and bodyHealth.current_health <= 0:
        event_manager.emit_event("on_kill", {"explosion": self, "body": body, "damage_context": ctx})
