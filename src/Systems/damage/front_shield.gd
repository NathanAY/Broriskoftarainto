# An optional enemy child that turns a hit away when it lands on the enemy's
# front arc.
#
# It is a targeting puzzle rather than a damage number: every other enemy in the
# roster is a positioning problem, and this one is answered by getting behind it.
#
# The shield subscribes to its owner's `before_take_damage`, reads the source of
# the hit, and zeroes `final_amount` when the source sits inside the arc. It is
# deliberately a plain `Node` rather than an `Area2D`: the hit already arrived,
# and the shield only rewrites the hit's damage.
extends Node
class_name FrontShield

## Half-width of the protected arc, in degrees from the facing direction.
## 70 degrees covers a little under half the circle in front of the creature.
@export_range(0.0, 180.0) var half_arc_degrees: float = 70.0


func _ready() -> void:
	var bus := _owner_bus()
	if bus == null:
		push_warning("FrontShield: the owner has no EventManager, so the shield never blocks.")
		return
	bus.subscribe("before_take_damage", Callable(self, "_on_before_take_damage"))


func _on_before_take_damage(event: Dictionary) -> void:
	var ctx := event.get("damage_context") as DamageContext
	if ctx == null:
		return
	var owner_node := get_parent() as Node2D
	if owner_node == null:
		return
	var source := ctx.source as Node2D
	if source == null or source == owner_node:
		return
	if is_in_front(owner_node, source.global_position):
		ctx.final_amount = 0.0


## Whether `world_position` sits inside the owner's frontal arc.
func is_in_front(owner_node: Node2D, world_position: Vector2) -> bool:
	var to_point := world_position - owner_node.global_position
	if to_point.length() < 0.001:
		return false
	var angle_degrees := rad_to_deg(absf(_facing(owner_node).angle_to(to_point)))
	return angle_degrees <= half_arc_degrees


## The sprite faces left when `flip_h` is set and right otherwise, which is the
## direction every movement behaviour already writes. Movement direction is a
## fallback for a body without the roster's `Node2D/Sprite2D` rig.
func _facing(owner_node: Node2D) -> Vector2:
	var sprite := owner_node.get_node_or_null("Node2D/Sprite2D") as Sprite2D
	if sprite != null:
		return Vector2.LEFT if sprite.flip_h else Vector2.RIGHT
	return Vector2.LEFT if owner_node.velocity.x < 0.0 else Vector2.RIGHT


## The event bus of the enemy this shield belongs to.
func _owner_bus() -> EventManager:
	var owner_node := get_parent()
	if owner_node == null:
		return null
	return owner_node.get_node_or_null("EventManager") as EventManager
