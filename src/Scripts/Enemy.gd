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

func _ready():
    add_to_group("enemies")  # Add enemy to a group
    add_to_group("damageable")
    $WeaponHolder.add_weapon(load("res://src/Resources/weapons/Thorns.tres"))
    #$WeaponHolder.add_weapon(load("res://src/Resources/weapons/Fist.tres"))
    $WeaponHolder.add_weapon(load("res://src/Resources/weapons/Pistol.tres"))
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
    # Collide with other enemies (layer 2) and arena walls (layer 4) so
    # enemies stay inside the ground. Hit detection uses the Hitbox Area2D.
    collision_mask = 2 | Arena.WALL_LAYER_BIT
    
    $Hitbox.collision_layer = 4
    $Hitbox.collision_mask = 7
    
    event_manager.subscribe("on_death", Callable(self, "_die"))
    event_manager.subscribe("before_take_damage", Callable(self, "_flash"))

func set_target_position(new_target: Node):
    target = new_target  

func _physics_process(delta):
    if !_alive:
        return
    behaviour.process_movement(self, delta)

func _flash(_event):
    var tween = create_tween()
    tween.tween_property(sprite, "modulate", Color(1, 4, 1), 0.1)
    tween.tween_property(sprite, "modulate", Color(4, 1, 1, 0), 0.1).from(Color(1, 1, 4))
    tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.0)

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
