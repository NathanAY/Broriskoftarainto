# res://src/Scenes/particles/poison_particles.gd
#
# The looping visual of a poisoned actor: small green bubbles rising off the
# body, denser the more poison stacks it carries.
#
# `PoisonEffect` adds this to whatever owns the poisoned `Health` node, so every
# enemy and character gets it with no scene wiring. It holds no combat logic -
# it is told the stack count and draws it.
extends GPUParticles2D
class_name PoisonParticles

## Stack count at which the emitter runs at its full `amount`. Fewer stacks emit
## proportionally fewer bubbles; more are not drawn any denser, because a
## modifier's `max_stacks` can be in the hundreds and one stack still has to be
## visible.
const FULL_STACKS := 10

## How much of the body sprite's half-width the bubbles are born across.
const BODY_FILL := 0.7

## The body sprite the emission area is sized from, relative to the parent. The
## same default as `HitFlashManager.sprite_path`.
@export var sprite_path: NodePath = "Node2D/Sprite2D"


func _ready() -> void:
	var sprite := get_parent().get_node_or_null(sprite_path) as Sprite2D
	if sprite == null or sprite.texture == null:
		return
	# Duplicated first: a scene instance shares its sub-resources, so writing the
	# shared material would resize the bubbles of every other poisoned actor.
	var material_copy := process_material.duplicate() as ParticleProcessMaterial
	material_copy.emission_sphere_radius = sprite.get_rect().size.x * absf(sprite.scale.x) * 0.5 * BODY_FILL
	process_material = material_copy
	position = sprite.position


## `amount_ratio` rather than `amount`: writing `amount` restarts the emitter and
## wipes every live bubble, which would pop the whole effect on each new stack.
func set_stacks(stacks: int) -> void:
	amount_ratio = clampf(float(stacks) / FULL_STACKS, 0.0, 1.0)
	emitting = stacks > 0


## Stops emitting and frees the node once the bubbles already in the air are gone.
func fade_out() -> void:
	emitting = false
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
