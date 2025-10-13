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
    $WeaponHolder.add_weapon(load("res://Resources/weapons/Thorns.tres"))
    #$WeaponHolder.add_weapon(load("res://Resources/weapons/Fist.tres"))
    #$WeaponHolder.add_weapon(load("res://Resources/weapons/Pistol.tres"))
    #$WeaponHolder.add_weapon(load("res://Resources/weapons/Pistol.tres"))
    #$WeaponHolder.add_weapon(load("res://Resources/weapons/Knife.tres"))
    item_holder.add_item(load("res://Resources/items/BootsOfSpeed.tres"))
    #item_holder.add_item(load("res://Resources/items/RegenPassive.tres"))
    #item_holder.add_item(load("res://Resources/items/RegenPassive.tres"))
    #item_holder.add_item(load("res://Resources/items/RegenPassive.tres"))
    #item_holder.add_item(load("res://Resources/items/ArmorPlate.tres"))
    #item_holder.add_item(load("res://Resources/items/EnergyShieldBlock.tres"))
    #item_holder.add_item(load("res://Resources/items/MinusArmorOnHitDebuff.tres"))
    #item_holder.add_item(load("res://Resources/items/PoisonHit.tres"))
    #item_holder.add_item(load("res://Resources/items/HomingProjectileOnHit.tres"))
    #item_holder.add_item(load("res://Resources/items/HomingShot.tres"))
    #item_holder.add_item(load("res://Resources/items/Knockback.tres"))
    #item_holder.add_item(load("res://Resources/items/HealthMeat.tres"))
    #item_holder.add_item(load("res://Resources/items/HealthMeat.tres"))
    
    collision_layer = 2
    collision_mask = 0 | 2
    
    $Hitbox.collision_layer = 4
    $Hitbox.collision_mask = 5
    
    event_manager.subscribe("on_death", Callable(self, "_die"))
    event_manager.subscribe("before_take_damage", Callable(self, "_flash"))

func set_target_position(new_target: Node):
    target = new_target  

func _physics_process(delta):
    if !_alive:
        return
    behaviour.process_movement(self, delta)

func _flash(event):
    var sprite = $Node2D/Sprite2D
    var tween = create_tween()
    tween.tween_property(sprite, "modulate", Color(1, 4, 1), 0.2)
    tween.tween_property(sprite, "modulate", Color(4, 1, 1, 0), 0.2).from(Color(1, 1, 4))
    tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.0)

func _die(event: Dictionary):
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
