#Enemy
extends CharacterBody2D
class_name Enemy

@onready var health_node: Health = $Health  # attach Health.gd as child
@onready var stats: Stats = $Stats  # attach Health.gd as child
@onready var event_manager: EventManager = $EventManager
@onready var item_holder: ItemHolder = $ItemHolder
@onready var weapon_holder: WeaponHolder = $WeaponHolder
@onready var collisition_shape: CollisionShape2D = $CollisionShape2D
@onready var anim_player: AnimationPlayer = get_node("AnimationPlayer")
@onready var sprite: Sprite2D = $Node2D/Sprite2D
@onready var behaviour: MovementBehaviour = $MovementBehaviour

var target: Node = null
var _alive: bool = true

## Soft crowd separation: force starts pulling once two enemies get closer
## than SEPARATION_FACTOR * body radius (hard body-body collision is disabled
## so packed crowds no longer shove/slide each other into unnatural paths).
## Bodies are small (radius 41) but sprites are ~100px wide, so this is kept
## above 1 body radius to stop sprites overlapping visually.
const SEPARATION_FACTOR: float = 2.0
## Peak separation force as a multiple of the enemy's movement speed.
const SEPARATION_FORCE_SCALE: float = 2.5

func _ready():
    add_to_group("enemies")  # Add enemy to a group
    add_to_group("damageable")
    $WeaponHolder.add_weapon(load("res://src/Resources/weapons/Thorns.tres"))
    #$WeaponHolder.add_weapon(load("res://src/Resources/weapons/Fist.tres"))
    # $WeaponHolder.add_weapon(load("res://src/Resources/weapons/Pistol.tres"))
    #$WeaponHolder.add_weapon(load("res://src/Resources/weapons/Pistol.tres"))
    #$WeaponHolder.add_weapon(load("res://src/Resources/weapons/Knife.tres"))
    item_holder.add_item(load("res://src/Resources/items/BootsOfSpeed.tres"))
    item_holder.add_item(load("res://src/Resources/items/ProjSlow.tres"))
    #item_holder.add_item(load("res://src/Resources/items/MoreDamageToHealthy.tres"))
    #item_holder.add_item(load("res://src/Resources/items/RegenPassive.tres"))
    #item_holder.add_item(load("res://src/Resources/items/RegenPassive.tres"))
    #item_holder.add_item(load("res://src/Resources/items/RegenPassive.tres"))
    #item_holder.add_item(load("res://src/Resources/items/ArmorPlate.tres"))
    #item_holder.add_item(load("res://src/Resources/items/EnergyShieldBlock.tres"))
    #item_holder.add_item(load("res://src/Resources/items/MinusArmorOnHitDebuff.tres"))
    #item_holder.add_item(load("res://src/Resources/items/PoisonHit.tres"))
    #item_holder.add_item(load("res://src/Resources/items/HomingProjectileOnHit.tres"))
    #item_holder.add_item(load("res://src/Resources/items/HomingShot.tres"))
    #item_holder.add_item(load("res://src/Resources/items/Knockback.tres"))
    #item_holder.add_item(load("res://src/Resources/items/HealthMeat.tres"))
    #item_holder.add_item(load("res://src/Resources/items/HealthMeat.tres"))
    
    collision_layer = 2
    # Only collide with arena walls (layer 4). Enemies do NOT collide with
    # each other — crowding is handled with a soft separation force so large
    # groups spread out naturally instead of being hard-pushed side to side.
    collision_mask = Arena.WALL_LAYER_BIT
    
    $Hitbox.collision_layer = 4
    $Hitbox.collision_mask = 7
    
    event_manager.subscribe("on_death", Callable(self, "_die"))

func set_target_position(new_target: Node):
    target = new_target  

func _physics_process(_delta):
    if !_alive:
        return
    behaviour.process_movement(self, _delta)
    velocity += _separation_force()
    # Keep combined chase + separation within the enemy's top speed so crowds
    # spread smoothly instead of bursting outward.
    var max_speed := stats.get_stat("movement_speed")
    var speed_sq := velocity.length_squared()
    if speed_sq > max_speed * max_speed:
        velocity = velocity.normalized() * max_speed
    move_and_slide()

## Sums soft repulsion from each nearby enemy so overlapping crowds expand
## naturally. Uses the body's collision radius so bigger bodies (bosses)
## separate more; stable anti-symmetric pairing keeps exact overlaps apart.
func _separation_force() -> Vector2:
    var radius := _body_radius()
    var sep_radius := radius * SEPARATION_FACTOR
    if sep_radius <= 0.0:
        return Vector2.ZERO
    var move_speed: float = stats.get_stat("movement_speed")
    var force := Vector2.ZERO
    for other in get_tree().get_nodes_in_group("enemies"):
        if other == self or not is_instance_valid(other):
            continue
        if other is Enemy and not other._alive:
            continue
        var to_other: Vector2 = global_position - other.global_position
        var dist := to_other.length()
        if dist > sep_radius:
            continue
        if dist < 0.001:
            # Exact overlap: pick a per-pair axis so both creatures push apart.
            var dir: float = 1.0 if get_instance_id() > other.get_instance_id() else -1.0
            var hash_pair := hash(get_instance_id() ^ other.get_instance_id())
            var angle := float(hash_pair % 100000) / 100000.0 * TAU
            to_other = Vector2.RIGHT.rotated(angle) * dir
            dist = 0.001
        var falloff := 1.0 - dist / sep_radius
        force += to_other.normalized() * (move_speed * SEPARATION_FORCE_SCALE * falloff)
    return force


func _body_radius() -> float:
    if collisition_shape != null and collisition_shape.shape is CircleShape2D:
        return (collisition_shape.shape as CircleShape2D).radius
    return 0.0

func _die(_event: Dictionary):
    _alive = false
    call_deferred("_disable_colision")
    anim_player.play("death")
    anim_player.animation_finished.connect(
        func(anim_name: String):
            if anim_name == "death":
                queue_free(),
        CONNECT_ONE_SHOT
    ) 

func _disable_colision():
    collisition_shape.disabled = true
