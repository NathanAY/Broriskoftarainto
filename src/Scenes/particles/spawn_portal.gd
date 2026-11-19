# res://src/Scenes/particles/spawn_portal.gd
#
# Teleport-in telegraph shown where an enemy is about to appear: glow particles
# are pulled in towards the spot while a ring shrinks around it, then the node
# frees itself. The spawner adds the enemy when `duration` has passed, so the
# effect and the spawn share one number. Use `SpawnPortal.play()` to start one.
extends Node2D
class_name SpawnPortal

const SCENE := "res://src/Scenes/particles/spawn_portal.tscn"
## Seconds an enemy is telegraphed for. The spawners and the sandbox panel all default to it.
const DEFAULT_DURATION := 1.0
## Ring and particle start radius, a little outside a grunt's body (radius ~41).
const DEFAULT_RADIUS := 56.0
## The boss is bigger, so its ring is too.
const BOSS_RADIUS := 110.0

@export var duration := DEFAULT_DURATION
@export var radius := DEFAULT_RADIUS
@export var color := Color(0.884, 0.754, 0.456, 0.78)

var _age := 0.0
@onready var _swarm: GPUParticles2D = $Swarm


## Puts a portal at `global_pos` under `parent` and returns it. Under `parent`,
## not the enemy container, so it is never counted as an enemy.
static func play(parent: Node, global_pos: Vector2, play_duration: float = DEFAULT_DURATION,
        portal_radius: float = DEFAULT_RADIUS) -> SpawnPortal:
    var portal := (load(SCENE) as PackedScene).instantiate() as SpawnPortal
    portal.duration = play_duration
    portal.radius = portal_radius
    parent.add_child(portal)
    portal.global_position = global_pos
    return portal


func _ready() -> void:
    # Duplicated first: a scene instance shares its sub-resources, so writing the
    # shared material would resize every other portal (a boss's would resize a grunt's).
    var swarm_material := _swarm.process_material.duplicate() as ParticleProcessMaterial
    swarm_material.emission_sphere_radius = radius
    # Travel = 0.5 * accel * lifetime^2, so this lands the particle on the centre.
    var pull := -2.0 * radius / (_swarm.lifetime * _swarm.lifetime)
    swarm_material.radial_accel_min = pull
    swarm_material.radial_accel_max = pull
    swarm_material.color = color
    _swarm.process_material = swarm_material
    _swarm.emitting = true


func _process(delta: float) -> void:
    _age += delta
    # Stop feeding the swarm early enough that the last particles arrive by the end.
    if _age >= duration - _swarm.lifetime:
        _swarm.emitting = false
    if _age >= duration:
        queue_free()
        return
    queue_redraw()


func _draw() -> void:
    var t := clampf(_age / duration, 0.0, 1.0)
    draw_arc(Vector2.ZERO, radius * (1.0 - t), 0.0, TAU, 48, Color(color, sin(t * PI)), 3.0, true)
