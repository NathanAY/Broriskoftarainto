# res://scripts/weapons/ContactWeapon.gd
extends BaseWeapon
class_name ContactWeapon

# Keep track of bodies inside the holder's hitbox
var overlapping_bodies: Array = []

func apply_to(holder: Node) -> void:
    super.apply_to(holder) # parent setup (timer etc.)
    var sprite = Sprite2D.new()
    sprite_node = sprite
    
    var area = holder.get_node_or_null("Hitbox")
    if area and area is Area2D:
        if not area.body_entered.is_connected(_on_body_entered):
            area.body_entered.connect(_on_body_entered)
        if not area.body_exited.is_connected(_on_body_exited):
            area.body_exited.connect(_on_body_exited)

func remove_from(holder: Node) -> void:
    var area = holder.get_node_or_null("Hitbox")
    if area and area is Area2D:
        if area.body_entered.is_connected(_on_body_entered):
            area.body_entered.disconnect(_on_body_entered)
        if area.body_exited.is_connected(_on_body_exited):
            area.body_exited.disconnect(_on_body_exited)
    overlapping_bodies.clear()
    super.remove_from(holder)

# Called by BaseWeapon timer (_on_timeout)
func try_shoot(_targets: Array) -> void:
    if overlapping_bodies.is_empty():
        return
    for body in overlapping_bodies:
        if body and body.has_node("Health"):
            do_damage(body)

func _body_in_ignore_group(body: Node) -> bool:
    for group in ignore_groups:
        if body.is_in_group(group):
            return true
    return false

func _on_body_entered(body: Node) -> void:
    if not body: return
    if _body_in_ignore_group(body):
        return
    if body in overlapping_bodies: 
        return
    overlapping_bodies.append(body)

func _on_body_exited(body: Node) -> void:
    if not body: return
    # even if it's in ignore groups we just erase safely
    overlapping_bodies.erase(body)

func do_damage(body: Node) -> void:
    var ctx = DamageContext.new()
    ctx.source = get_holder()
    ctx.target = body
    ctx.base_amount = base_damage
    ctx.final_amount = base_damage
    ctx.tags.append("contact")

    if event_manager:
        event_manager.emit_event("before_deal_damage", [{"damage_context": ctx}])

    var bodyHealth: Health = body.get_node("Health")
    bodyHealth.event_manager.emit_event("before_take_damage", [{"damage_context": ctx}])
    bodyHealth.take_damage(ctx)
    bodyHealth.event_manager.emit_event("after_take_damage", [{"damage_context": ctx}])

    if event_manager:
        event_manager.emit_event("after_deal_damage", [{"weapon": self, "body": body, "damage_context": ctx}])
        event_manager.emit_event("on_attack", [{"weapon": self, "body": body, "damage_context": ctx}])
        event_manager.emit_event("on_hit", [{"weapon": self, "body": body, "damage_context": ctx}])
