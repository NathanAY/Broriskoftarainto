#Enemy
extends CharacterBody2D

@onready var health_node: Node = $Health  # attach Health.gd as child
@onready var stats: Stats = $Stats  # attach Health.gd as child
@onready var event_manager: EventManager = $EventManager
@onready var item_holder: ItemHolder = $ItemHolder
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
    $WeaponHolder.add_weapon(load("res://Resources/weapons/Pistol.tres"))
    #$WeaponHolder.add_weapon(load("res://Resources/weapons/Pistol.tres"))
    #$WeaponHolder.add_weapon(load("res://Resources/weapons/Knife.tres"))
    item_holder.add_item(load("res://Resources/items/BootsOfSpeed.tres"))
    #item_holder.add_item(load("res://Resources/items/RegenPassive.tres"))
    #item_holder.add_item(load("res://Resources/items/RegenPassive.tres"))
    #item_holder.add_item(load("res://Resources/items/RegenPassive.tres"))
    #item_holder.add_item(load("res://Resources/items/ArmorPlate.tres"))
    item_holder.add_item(load("res://Resources/items/EnergyShieldBlock.tres"))
    item_holder.add_item(load("res://Resources/items/MinusArmorOnHitDebuff.tres"))
    item_holder.add_item(load("res://Resources/items/PoisonHit.tres"))
    item_holder.add_item(load("res://Resources/items/HomingShot.tres"))
    #item_holder.add_item(load("res://Resources/items/Knockback.tres"))
    #item_holder.add_item(load("res://Resources/items/HealthMeat.tres"))
    #item_holder.add_item(load("res://Resources/items/HealthMeat.tres"))
    #item_holder.add_item(load("res://Resources/items/HealthMeat.tres"))
    #item_holder.add_item(load("res://Resources/items/HealthMeat.tres"))
    event_manager.subscribe("on_death", Callable(self, "_die"))

func set_target_position(new_target: Node):
    target = new_target  

func _physics_process(delta):
    if !_alive:
        return
    behaviour.process_movement(self, delta)

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
