#melee_weapon_node
extends Node2D
## How many stretches the forward flight is split into. The swing hits the fist's
## own footprint when it starts (stretch 0), then, each time the fist arrives at the
## end of a stretch, the rectangle that stretch has just covered (stretches 1..SEGMENTS).
const SEGMENTS: int = 4

var weapon_data: MeleeWeapon
var holder: Node
var event_manager: Node
var attacking: bool = false
var origin_pos: Vector2
var direction: Vector2 = Vector2.RIGHT
var ignore_groups: Array = []
var _damaged_bodies: Array = []
var _attack_origin_global: Vector2

@onready var sprite_node: Sprite2D = $Sprite2D
## Only its shape is used: the fist's length and width. Damage comes from the
## segment rectangles, not from this area overlapping anything.
@onready var hitbox: Area2D = $Area2D


func setup(data: MeleeWeapon, h: Node, em: Node) -> void:
    weapon_data = data
    holder = h
    event_manager = em
    ignore_groups = data.ignore_groups
    sprite_node.texture = data.sprite
    hitbox.monitoring = false
    hitbox.monitorable = false
    origin_pos = sprite_node.global_position


func attack(dir: Vector2) -> void:
    if attacking:
        return
    if event_manager:
        event_manager.emit_event("on_attack", {"weapon": weapon_data})
    attacking = true
    origin_pos = position
    direction = dir.normalized()
    _damaged_bodies.clear()
    _attack_origin_global = global_position

    if weapon_data.sprite_node and is_instance_valid(weapon_data.sprite_node):
        weapon_data.sprite_node.visible = false
        sprite_node.visible = true
    if sprite_node:
        sprite_node.rotation = direction.angle()
        sprite_node.flip_v = direction.x < 0

    var tween = get_tree().create_tween()
    SoundManager.play(weapon_data.attack_sound.pick_random(), 0, 0)

    # `weapon_range` is meters and a `Vector2` is pixels, so every measurement
    # below goes through `get_range_px()`. Reading `weapon_range` directly would
    # shrink the swing by PIXELS_PER_METER.
    var reach = weapon_data.get_range_px()
    var speed = reach * weapon_data._current_attack_speed
    var duration = reach / speed

    # What the fist itself covers is hit the moment the swing starts. The fist then
    # flies one stretch at a time and, on arriving at the end of each, hits the
    # ground that stretch just covered - never ground it has not reached yet.
    hit_segment(0)
    var seg_time = (duration / 3.0) / SEGMENTS
    for i in range(SEGMENTS):
        var t = float(i + 1) / SEGMENTS
        tween.tween_property(self, "position", origin_pos + direction * reach * t, seg_time).set_trans(Tween.TRANS_LINEAR)
        tween.tween_callback(hit_segment.bind(i + 1))
    # Backward
    tween.tween_property(self, "position", origin_pos, duration / 2).set_trans(Tween.TRANS_LINEAR)
    tween.finished.connect(func():
        attacking = false
        if weapon_data.sprite_node and is_instance_valid(weapon_data.sprite_node):
            weapon_data.sprite_node.visible = true
        sprite_node.visible = false
    )


## Half the fist's length: the front of the fist is this far ahead of its centre,
## and it is the front that has to get to a target.
func tip_offset() -> float:
    var cs := hitbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
    if cs and cs.shape is RectangleShape2D:
        return (cs.shape as RectangleShape2D).size.x * 0.5 * absf(hitbox.scale.x)
    return 0.0


## Distance along the path, from where the swing started, at which stretch `index`
## ends: where the fist's tip is once the fist has arrived there. Stretch 0 is the
## fist's own footprint and ends at its tip; stretch k is the k-th part of the flight.
func segment_end(index: int) -> float:
    return tip_offset() + weapon_data.get_range_px() * float(index) / SEGMENTS


## Where stretch `index` starts: the end of the one before it (the fist's centre
## for stretch 0, which has none).
func segment_start(index: int) -> float:
    return 0.0 if index <= 0 else segment_end(index - 1)


func first_segment_end() -> float:
    return segment_end(0)


## The fist's width across its path.
func _perp_width() -> float:
    var cs := hitbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
    var width := 8.0
    if cs and cs.shape is RectangleShape2D:
        width = (cs.shape as RectangleShape2D).size.y * absf(hitbox.scale.y)
    elif cs and cs.shape is CircleShape2D:
        width = (cs.shape as CircleShape2D).radius * 2.0 * absf(hitbox.scale.y)
    return clampf(width, 4.0, 200.0)


## Hits everything inside the rectangle that covers stretch `index` of the path:
## from the end of the previous stretch to the end of this one, as wide as the
## fist. Called when the fist arrives at the end of the stretch, so the rectangle
## is ground the fist's tip has just covered. A target already hit this swing is
## not hit again.
func hit_segment(index: int) -> void:
    var start := segment_start(index)
    var end := segment_end(index)
    var shape := RectangleShape2D.new()
    shape.size = Vector2(end - start, _perp_width())
    var query := PhysicsShapeQueryParameters2D.new()
    query.shape = shape
    query.transform = Transform2D(direction.angle(), _attack_origin_global + direction * (start + end) * 0.5)
    query.collide_with_areas = true
    query.collide_with_bodies = true
    query.collision_mask = 0x7fffffff
    query.exclude = [hitbox.get_rid()]
    for hit in get_world_2d().direct_space_state.intersect_shape(query, 64):
        _try_damage(hit.collider)


func _try_damage(collider: Object) -> void:
    var target: Node = _resolve_damageable_target(collider)
    if not target or target == holder:
        return
    if holder and target.is_in_group(holder.name):
        return
    if ignore_groups.any(func(g): return target.is_in_group(g)):
        return
    if _damaged_bodies.has(target):
        return
    _damaged_bodies.append(target)
    do_damage(target)


func _resolve_damageable_target(collider: Object) -> Node:
    # If the collider itself is the damageable body, return it.
    if collider is Node and collider.is_in_group("damageable"):
        return collider
    # If collider is an Area2D or other child, walk up the parent chain to find the damageable owner.
    if collider is Node:
        var p = collider.get_parent()
        while p:
            if p.is_in_group("damageable"):
                return p
            p = p.get_parent()
    return null


func do_damage(body):
    var ctx = DamageContext.new()
    ctx.source = self
    ctx.target = body
    ctx.base_amount = weapon_data.current_damage
    ctx.final_amount = weapon_data.current_damage
    ctx.tags.append("melee")
    if event_manager: 
        event_manager.emit_event("before_deal_damage", {"damage_context": ctx})
    var bodyHealth = body.get_node("Health")
    if not bodyHealth.apply_damage(ctx):
        return  # already dead: the swing does not land, so no hit/kill events either
    if event_manager:
        event_manager.emit_event("after_deal_damage", {"melee": self, "body": body, "damage_context": ctx, "weapon": weapon_data})
    if event_manager:
        event_manager.emit_event("on_hit", {"melee": self, "body": body, "damage_context": ctx, "weapon": weapon_data})
    if event_manager and bodyHealth.current_health <= 0:
        event_manager.emit_event("on_kill", {"melee": self, "body": body, "damage_context": ctx, "weapon": weapon_data})
