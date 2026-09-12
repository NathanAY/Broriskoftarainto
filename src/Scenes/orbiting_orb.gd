extends Node2D
class_name SpinningOrb

@export var orbit_center: Node2D
@export var orbit_radius := 60.0
@export var orbit_speed := 360.0  # degrees per second
@export var angle_offset := 0.0
@export var damage := 3.0

@onready var area: Area2D = $Area2D
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D

var event_manager: EventManager
var ignore_groups: Array[StringName] = []
var _angle := 0.0
var overlapping_bodies: Array = []
var modifier_meta := "spawned_by_SpinningOrb"

func _ready():
    if area:
        area.body_entered.connect(_on_body_entered)
        area.body_exited.connect(_on_body_exited)

func _process(delta: float):
    if not is_instance_valid(orbit_center):
        queue_free()
        return

    _angle += orbit_speed * delta
    var angle_rad = deg_to_rad(_angle + angle_offset)
    var center_pos = orbit_center.global_position
    global_position = center_pos + Vector2(cos(angle_rad), sin(angle_rad)) * orbit_radius

    # Deal contact damage every frame
    _deal_contact_damage()

func _on_body_entered(body: Node):
    if not body:
        return
    if body in overlapping_bodies:
        return
    for group in ignore_groups:
        if body.is_in_group(group):
            return true
    overlapping_bodies.append(body)

func _on_body_exited(body: Node):
    if not body:
        return
    overlapping_bodies.erase(body)

func _deal_contact_damage():
    if overlapping_bodies.is_empty():
        return

    for body in overlapping_bodies:
        if not is_instance_valid(body):
            continue
        var health: Health = body.get_node_or_null("Health")
        if not health:
            continue

        var ctx := DamageContext.new()
        ctx.source = orbit_center
        ctx.target = body
        ctx.base_amount = damage
        ctx.final_amount = damage
        ctx.tags.append(modifier_meta)

        # apply global modifiers
        event_manager.emit_event("before_deal_damage", [{"damage_context": ctx}])

        # apply to target
        health.event_manager.emit_event("before_take_damage", [{"damage_context": ctx}])
        health.take_damage(ctx)
        health.event_manager.emit_event("after_take_damage", [{"damage_context": ctx}])

        event_manager.emit_event("after_deal_damage", [{"damage_context": ctx}])
        event_manager.emit_event("on_hit", [{"damage_context": ctx}])
    overlapping_bodies.clear()
