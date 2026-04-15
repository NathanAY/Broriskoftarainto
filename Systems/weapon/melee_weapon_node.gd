#melee_weapon_node
extends Node2D

var weapon_data: MeleeWeapon
var holder: Node
var event_manager: Node
var attacking: bool = false
var origin_pos: Vector2
var direction: Vector2 = Vector2.RIGHT
var ignore_groups: Array = []
var forward_swing = true
# --- optional: store original hitbox/sprite scale for restoration
var _original_scale_x: float = 1.0
var _damaged_bodies: Array = []
var _last_sweep_pos = null
var attack_angle_deg: float = 6.0
var _attack_origin_global: Vector2

func _get_hitbox_perp_width() -> float:
    var width = 1.0
    var cs = hitbox.get_node_or_null("CollisionShape2D")
    if cs and cs.shape:
        var s = cs.shape
        if s is CircleShape2D:
            width = s.radius * 2.0 * abs(hitbox.scale.y)
        elif s is RectangleShape2D:
            width = s.extents.y * 2.0 * abs(hitbox.scale.y)
        elif s is CapsuleShape2D:
            width = s.radius * 2.0 * abs(hitbox.scale.y)
    return clamp(width, 4.0, 200.0)

@onready var sprite_node: Sprite2D = $Sprite2D
@onready var hitbox: Area2D = $Area2D

func setup(data: MeleeWeapon, h: Node, em: Node) -> void:
    weapon_data = data
    holder = h
    event_manager = em
    ignore_groups = data.ignore_groups
    sprite_node.texture = data.sprite
    hitbox.body_entered.connect(_on_body_entered)
    origin_pos = sprite_node.global_position
    _original_scale_x = hitbox.scale.x

func attack(dir: Vector2) -> void:
    if attacking:
        print("Skip")
        return
    if event_manager:
        event_manager.emit_event("on_attack", [{"weapon": weapon_data}])
    attacking = true
    forward_swing = true  # reset for this attack
    origin_pos = position
    direction = dir.normalized()
    _damaged_bodies.clear()
    _last_sweep_pos = global_position
    _attack_origin_global = global_position

    if weapon_data.sprite_node and is_instance_valid(weapon_data.sprite_node):
        weapon_data.sprite_node.visible = false
        sprite_node.visible = true
    if sprite_node:
        sprite_node.rotation = direction.angle()
        sprite_node.flip_v = direction.x < 0

    var tween = get_tree().create_tween()
    SoundManager.play(weapon_data.attack_sound.pick_random(), 0, 0)

    # Forward movement
    var speed = weapon_data.range * weapon_data._current_attack_speed
    var duration = weapon_data.range / speed

    # Stretch hitbox proportionally to swing speed
    _adjust_hitbox_stretch(speed)

    # detect overlaps immediately on attack start
    _check_existing_overlaps()

    # Split forward swing into segments and check overlaps after each step
    var segments: int = 6
    var forward_total_time = duration / 3.0
    var seg_time = forward_total_time / segments
    for i in range(segments):
        var t = float(i + 1) / segments
        var target_pos = origin_pos + direction * weapon_data.range * t
        tween.tween_property(self, "position", target_pos, seg_time).set_trans(Tween.TRANS_LINEAR)
        tween.tween_callback(Callable(self, "_check_existing_overlaps"))
    # Mark forward as finished after the last segment
    tween.tween_callback(Callable(self, "_on_forward_finished"))
    # Backward
    tween.tween_property(self, "position", origin_pos, duration / 2).set_trans(Tween.TRANS_LINEAR)
    tween.finished.connect(func():
        attacking = false
        _reset_hitbox_scale()  # Restore hitbox scale
        #_last_sweep_pos = null
        if weapon_data.sprite_node and is_instance_valid(weapon_data.sprite_node):
            weapon_data.sprite_node.visible = true
        sprite_node.visible = false
    )

func _on_forward_finished():
    forward_swing = false

func _check_existing_overlaps() -> void:
    if not forward_swing:
        return
    var from_pos = _last_sweep_pos if _last_sweep_pos else global_position
    var to_pos = global_position
    _sweep_between(from_pos, to_pos)
    _last_sweep_pos = to_pos

func _sweep_between(from_pos: Vector2, to_pos: Vector2) -> void:
    var motion = to_pos - from_pos
    var dist = motion.length()
    if dist <= 0.001:
        # fallback to overlap check
        var overlapping := hitbox.get_overlapping_bodies()
        for body in overlapping:
            if _damaged_bodies.has(body):
                continue
            _on_body_entered(body)
        return

    var dir = motion.normalized()
    var perp = Vector2(-dir.y, dir.x)

    # estimate hitbox width (perpendicular size) from child CollisionShape2D when available
    var width = 8.0
    var cs = hitbox.get_node_or_null("CollisionShape2D")
    if cs and cs.shape:
        var s = cs.shape
        if s is CircleShape2D:
            width = s.radius * 2.0 * abs(hitbox.scale.y)
        elif s is RectangleShape2D:
            width = s.extents.y * 2.0 * abs(hitbox.scale.y)
        elif s is CapsuleShape2D:
            width = s.radius * 2.0 * abs(hitbox.scale.y)

    # clamp width to a reasonable range to avoid huge offsets from stretched X-scale
    width = clamp(width, 4.0, 200.0)

    var rays = 3
    for i in range(rays):
        var t = 0.0
        if rays > 1:
            t = float(i) / float(rays - 1)
        var offset = perp * ((t - 0.5) * width)
        var fromp = from_pos + offset
        var top = to_pos + offset
        var exclude = [holder, self]
        var ps: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(fromp, top)
        ps.exclude = exclude
        ps.collide_with_areas = true
        ps.collide_with_bodies = true
        ps.collision_mask = 0x7fffffff
        var res = get_world_2d().direct_space_state.intersect_ray(ps)
        if res and res.collider:
            _process_sweep_collider(res.collider)

func _process_sweep_collider(collider: Object) -> void:
    if not collider: return
    var target: Node = _resolve_damageable_target(collider)
    if not target: return
    if not _is_on_movement_line(target):
        return
    if holder and target.is_in_group(holder.name): return
    if ignore_groups.any(func(g): return target.is_in_group(g)): return
    if _damaged_bodies.has(target):
        return
    do_damage(target)
    _damaged_bodies.append(target)

func _is_in_attack_cone(target: Node) -> bool:
    return false

func _get_target_hitbox_radius(target: Node) -> float:
    # Try to find a `Hitbox` Area2D child and read its CollisionShape2D
    var hb = null
    if target.has_node("Hitbox"):
        hb = target.get_node("Hitbox")
    else:
        # try to find an Area2D child
        for c in target.get_children():
            if c is Area2D:
                hb = c
                break
    if not hb:
        return 8.0
    var cs = hb.get_node_or_null("CollisionShape2D")
    if not cs or not cs.shape:
        return 8.0
    var s = cs.shape
    if s is CircleShape2D:
        return s.radius * max(abs(hb.global_scale.x), abs(hb.global_scale.y))
    elif s is RectangleShape2D:
        return max(s.extents.x * abs(hb.global_scale.x), s.extents.y * abs(hb.global_scale.y))
    elif s is CapsuleShape2D:
        return s.radius * max(abs(hb.global_scale.x), abs(hb.global_scale.y))
    return 8.0

func _is_on_movement_line(target: Node) -> bool:
    if not target: return false
    var target_pos = Vector2()
    if target.has_method("global_position"):
        target_pos = target.global_position
    elif target is Node2D:
        target_pos = (target as Node2D).global_position
    else:
        return false

    var start = _attack_origin_global if _attack_origin_global else global_position
    var forward = direction.normalized()
    var to_target = target_pos - start
    var proj = to_target.dot(forward)
    if proj < 0.0:
        return false
    var max_range = weapon_data.range if weapon_data and weapon_data.range else 0
    if max_range > 0 and proj > max_range * 1.1:
        return false

    var perp = Vector2(-forward.y, forward.x)
    var perp_dist = abs(to_target.dot(perp))
    var target_radius = _get_target_hitbox_radius(target)
    var weapon_half_width = _get_hitbox_perp_width() * 0.5
    # movement line intersects target hitbox if perp distance <= target_radius + weapon_half_width
    return perp_dist <= (target_radius + weapon_half_width + 0.5)

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

func _on_body_entered(body: Node) -> void:
    if not attacking: return
    if not forward_swing: return
    if not body.is_in_group("damageable"): return
    if holder and body.is_in_group(holder.name): return
    if ignore_groups.any(func(g): return body.is_in_group(g)): return
    # Only apply damage if the target overlaps the weapon movement line
    if not _is_on_movement_line(body):
        return
    if _damaged_bodies.has(body):
        return
    do_damage(body)
    _damaged_bodies.append(body)

func do_damage(body):
    var ctx = DamageContext.new()
    ctx.source = self
    ctx.target = body
    ctx.base_amount = weapon_data._current_damage
    ctx.final_amount = weapon_data._current_damage
    ctx.tags.append("melee")
    if event_manager: 
        event_manager.emit_event("before_deal_damage", [{"damage_context": ctx}])
    var bodyHealth: Health = body.get_node("Health")
    bodyHealth.event_manager.emit_event("before_take_damage", [{"damage_context": ctx}])
    bodyHealth.take_damage(ctx)
    bodyHealth.event_manager.emit_event("after_take_damage", [{"damage_context": ctx}])
    if event_manager:
        event_manager.emit_event("after_deal_damage", [{"melee": self, "body": body, "damage_context": ctx}])
    if event_manager:
        event_manager.emit_event("on_hit", [{"melee": self, "body": body, "damage_context": ctx}])

func _adjust_hitbox_stretch(speed: float) -> void:
    hitbox.scale.x = _original_scale_x * speed

func _reset_hitbox_scale() -> void:
    hitbox.scale.x = _original_scale_x
