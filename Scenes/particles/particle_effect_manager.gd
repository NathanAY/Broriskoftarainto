#particle_effect_manager
extends Node2D

@onready var event_manager: EventManager = get_parent().get_node_or_null("EventManager")
@onready var hit_particles: PackedScene = preload("res://Scenes/particles/hit_particles.tscn")
@onready var directional_hit_particles: PackedScene = preload("res://Scenes/particles/directional_hit_particles.tscn")

func _ready():
    event_manager.subscribe("after_take_damage", Callable(self, "_emit_particle"))

func _emit_particle(event: Dictionary):
    var ctx: DamageContext = event.get("damage_context")
    var particle_amount = 8 * ctx.target_take_persent_damage
    if particle_amount < 1:
        return
    var particles = directional_hit_particles.instantiate() as GPUParticles2D    
    if ctx.source:
        var dir = (global_position - ctx.source.global_position).normalized()
        particles.rotation = dir.angle()
        particles.amount = particle_amount
    add_child(particles)
    particles.emitting = true
    particles.finished.connect(particles.queue_free) # auto cleanup
