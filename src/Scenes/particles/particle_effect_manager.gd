#particle_effect_manager
extends Node2D

## Share of a hit's particles that fly in every direction; the rest are aimed away from the source.
const OMNI_SHARE := 0.3
## A huge hit must not stack hundreds of particles into one blob.
const MAX_PARTICLES := 40

@onready var event_manager: EventManager = get_parent().get_node_or_null("EventManager")
@onready var hit_particles: PackedScene = preload("res://src/Scenes/particles/hit_particles.tscn")
@onready var directional_hit_particles: PackedScene = preload("res://src/Scenes/particles/directional_hit_particles.tscn")

func _ready():
    event_manager.subscribe("after_take_damage", Callable(self, "_emit_particle"))

func _emit_particle(event: Dictionary):
    var ctx: DamageContext = event.get("damage_context")
    var total := mini(int(8 * ctx.target_take_persent_damage), MAX_PARTICLES)
    if total < 1:
        return
    var omni_amount := int(total * OMNI_SHARE)
    _spawn(hit_particles, omni_amount, 0.0, false)
    var dir_angle := 0.0
    if ctx.source:
        dir_angle = (global_position - ctx.source.global_position).angle()
    _spawn(directional_hit_particles, total - omni_amount, dir_angle, true)

func _spawn(scene: PackedScene, amount: int, angle: float, aimed: bool) -> void:
    if amount < 1:
        return
    var particles := scene.instantiate() as GPUParticles2D
    particles.amount = amount
    if aimed:
        particles.rotation = angle
    add_child(particles)
    particles.emitting = true
    particles.finished.connect(particles.queue_free) # auto cleanup
