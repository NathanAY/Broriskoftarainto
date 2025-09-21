# res://scripts/weapons/AreaWeapon.gd
extends BaseWeapon
class_name AreaWeapon

func try_shoot(targets: Array[Node]) -> void:
    var holder = get_holder()
    if not holder: return
#    TODO: implement
    for t in targets:
        if t.has_node("Health"):
            do_damage(t)
                
func do_damage(body):
    var ctx = DamageContext.new()
    ctx.source = get_holder()
    ctx.target = body
    ctx.base_amount = base_damage
    ctx.final_amount = base_damage
    ctx.tags.append("melee")
    if event_manager: 
        event_manager.emit_event("before_deal_damage", [{"damage_context": ctx}])
    var bodyHealth: Health = body.get_node("Health")
    bodyHealth.event_manager.emit_event("before_take_damage", [{"damage_context": ctx}])
    bodyHealth.take_damage(ctx)
    if event_manager:
        event_manager.emit_event("after_deal_damage", [{"weapon": self, "body": body, "damage_context": ctx}])
        event_manager.emit_event("on_attack", [{"weapon": self, "body": body, "damage_context": ctx}])
        event_manager.emit_event("on_hit", [{"weapon": self, "body": body, "damage_context": ctx}])                     
    
