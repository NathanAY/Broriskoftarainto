extends BaseModifier

@export var display_name: String = "Explosive Shot"
@export_multiline var tooltip_text: String = "Hits explode, dealing area damage."
@export var trigger_event: String = "on_hit"
@export var damage_multiplier_per_stack: float = 0.5 # +50% explosion damage per stack

## Fraction of the triggering hit's damage the explosion deals. When above zero
## it overrides [member explosion_damage], so the blast scales with the weapon
## instead of a fixed number (this is what lets it be a weapon built-in).
@export var damage_fraction_of_hit: float = 0.2

var explosion_scene = preload("res://src/Scenes/Explosion.tscn")

## Blast radius in meters (64 px); `Explosion` converts at its own boundary.
var explosion_radius := 0.21
## Fallback blast damage for a hit that carries no damage context.
var explosion_damage := 3.0

func get_tooltip_stats() -> String:
    if damage_fraction_of_hit > 0.0:
        return "Explodes for %d%% of hit damage" % int(round(damage_fraction_of_hit * 100.0))
    return "Explodes for %s damage, +%d%% per stack" % [str(explosion_damage), int(round(damage_multiplier_per_stack * 100.0))]

func attachEventManager(em: Node):
    _cache_holder(em)
    _subscribe(trigger_event, Callable(self, "_on_hit"))

func _on_hit(event: Dictionary):
    if !event.has("projectile"):
        return
    var projectile = event["projectile"]
    var base_damage := explosion_damage
    var ctx: DamageContext = event.get("damage_context")
    if damage_fraction_of_hit > 0.0 and ctx:
        base_damage = max(ctx.base_amount, ctx.final_amount) * damage_fraction_of_hit
    # Defer the explosion spawn to avoid flushing query errors
    call_deferred("_spawn_explosion", projectile.global_position, base_damage)

func _spawn_explosion(position: Vector2, base_damage: float):
    var explosion = explosion_scene.instantiate()
    explosion.attachEventManager(event_manager)
    explosion.global_position = position
    explosion.radius = explosion_radius
    explosion.damage = base_damage * (1.0 + (damage_multiplier_per_stack * (_active_stacks() - 1)))
    get_tree().current_scene.add_child(explosion)