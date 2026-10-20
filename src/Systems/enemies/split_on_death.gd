# Splits an enemy into smaller copies of itself when it dies.
#
# It is an optional child node on the enemy scene, the same way the death
# burst is: an enemy that does not split simply does not have one. `Enemy`
# itself knows nothing about splitting, so the enemy script stays the code
# every enemy needs and only the splitter carries this.
#
# The node is a direct child of the enemy - that is where it looks for the
# enemy, and where it looks for the splitter of a child it spawns.
#
# The children are the same scene at a reduced scale. A scene cannot point at
# itself - Godot refuses the cyclic reference - so an empty `split_scene`
# means "the owner's own scene", taken from the owner's scene file path.
extends Node
class_name SplitOnDeath

## The scene the children are built from. Empty means the owner's own scene,
## which is the usual case: a splitter is normally a smaller copy of itself.
@export var split_scene: PackedScene

## How many children the split produces.
@export_range(1, 6) var split_count: int = 3

## Multiplies the children's health, speed, damage and visual scale.
@export_range(0.25, 1.0) var split_scale: float = 0.6

## Set on a spawned child, so a mini does not split again: a chain of splits
## would never let the stage end, because a stage ends when the enemy
## container is empty.
var suppressed: bool = false


func _ready() -> void:
	var bus := _owner_bus()
	if bus == null:
		push_warning("SplitOnDeath: the owner has no EventManager, so the split never happens.")
		return
	bus.subscribe("on_death", Callable(self, "_on_owner_died"))


## The event bus of the enemy this splitter belongs to.
func _owner_bus() -> EventManager:
	var owner_node := get_parent()
	if owner_node == null:
		return null
	return owner_node.get_node_or_null("EventManager") as EventManager


func _on_owner_died(_event: Dictionary) -> void:
	if suppressed or split_count <= 0:
		return
	var owner_enemy := get_parent() as Enemy
	if owner_enemy == null:
		return
	var child_scene := _child_scene(owner_enemy)
	if child_scene == null:
		return
	var container := owner_enemy.get_parent()
	if container == null:
		return
	for _i in range(split_count):
		var child := child_scene.instantiate() as Enemy
		if child == null:
			continue
		_suppress_child_split(child)
		child.global_position = owner_enemy.global_position + _child_offset(owner_enemy)
		child.set_target_position(owner_enemy.target)
		_scale_child(child)
		# The death event fires from inside `Health.apply_damage`, which can be
		# inside a physics callback, and touching the tree from there is a
		# flushing error. The container is the one the spawner uses, so
		# `StageManager`'s "no enemies left" stage-end still sees the children.
		container.call_deferred("add_child", child)


## The scene the children are built from: the authored one, or the owner's own
## scene when none is set.
func _child_scene(owner_enemy: Enemy) -> PackedScene:
	if split_scene != null:
		return split_scene
	var path := owner_enemy.scene_file_path
	if path == "":
		push_warning("SplitOnDeath: no split scene and the owner came from no scene file, so it splits into nothing.")
		return null
	return load(path) as PackedScene


## Tells a spawned child's own splitter not to split again.
func _suppress_child_split(child: Enemy) -> void:
	for node in child.get_children():
		if node is SplitOnDeath:
			(node as SplitOnDeath).suppressed = true


## Where a child lands relative to the parent. A small ring around the corpse,
## so the children do not stack on top of each other.
func _child_offset(owner_enemy: Enemy) -> Vector2:
	var angle := randf_range(0.0, TAU)
	return Vector2(cos(angle), sin(angle)) * (owner_enemy.body_radius() * 0.6)


## Scales a child's stats and its body down.
##
## The stats have to be scaled before the child enters the tree, because
## `Health._ready()` reads the health stat once. The collision shape is a
## shared sub-resource of the scene, so it has to be duplicated before its
## radius is changed - otherwise every instance of the scene would shrink.
func _scale_child(child: Enemy) -> void:
	var child_stats := child.get_node_or_null("Stats") as Stats
	if child_stats != null:
		child_stats.set_base_stat("health", child_stats.get_stat("health") * split_scale)
		child_stats.set_base_stat("movement_speed", child_stats.get_stat("movement_speed") * split_scale)
		child_stats.set_base_stat("damage", child_stats.get_stat("damage") * split_scale)
	_scale_circle(child.get_node_or_null("CollisionShape2D"))
	_scale_circle(child.get_node_or_null("Hitbox/CollisionShape2D"))
	var child_sprite := child.get_node_or_null("Node2D/Sprite2D") as Sprite2D
	if child_sprite != null:
		child_sprite.scale = Vector2.ONE * split_scale


## Shrinks one collider to `split_scale` of its authored size.
func _scale_circle(shape_node: Node) -> void:
	var shape := shape_node as CollisionShape2D
	if shape == null or not (shape.shape is CircleShape2D):
		return
	var circle := (shape.shape as CircleShape2D).duplicate() as CircleShape2D
	circle.radius *= split_scale
	shape.shape = circle
