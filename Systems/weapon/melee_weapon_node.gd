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

    if weapon_data.sprite_node and is_instance_valid(weapon_data.sprite_node):
        weapon_data.sprite_node.visible = false
        sprite_node.visible = true
    if sprite_node:
        sprite_node.rotation = direction.angle()
        sprite_node.flip_v = direction.x < 0

    var tween = get_tree().create_tween()
    SoundManager.play(weapon_data.attack_sound.pick_random(), 0, 0)
    #SoundManager.play2d(weapon_data.attack_sound.pick_random(), Vector2(-1000, 0), -5, 0.2)
    # Forward
    var speed = weapon_data.range * weapon_data._current_attack_speed
    var duration = weapon_data.range / speed

    # ✅ Stretch hitbox proportionally to swing speed
    _adjust_hitbox_stretch(speed)
    
    tween.tween_property(self, "position", origin_pos + direction * weapon_data.range, duration / 3).set_trans(Tween.TRANS_EXPO)
    # Mark forward as false after reaching max
    tween.tween_callback(Callable(self, "_on_forward_finished"))
    # Backward
    tween.tween_property(self, "position", origin_pos, duration / 2).set_trans(Tween.TRANS_SINE)
    tween.finished.connect(func():
        attacking = false
        _reset_hitbox_scale()  # ✅ restore hitbox scale
        if weapon_data.sprite_node and is_instance_valid(weapon_data.sprite_node):
            weapon_data.sprite_node.visible = true
        sprite_node.visible = false
    )

func _on_forward_finished():
    forward_swing = false

func _on_body_entered(body: Node) -> void:
    if not attacking: return
    if not forward_swing: return
    if not body.is_in_group("damageable"): return
    if holder and body.is_in_group(holder.name): return
    if ignore_groups.any(func(g): return body.is_in_group(g)): return
    do_damage(body)

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
    var stretch := 1.0
    if speed > 10000:
        stretch = 1.0 + speed / 100
    elif speed > 800:
        stretch = 1.0 + speed / 1000

    # Elongate along X (swing direction)
    hitbox.scale.x = _original_scale_x * stretch
    sprite_node.scale.x = stretch
    
func _reset_hitbox_scale() -> void:
    hitbox.scale.x = _original_scale_x
    sprite_node.scale.x = 1.0
