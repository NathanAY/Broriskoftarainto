#Enemy
extends CharacterBody2D

var target_position: Vector2 = Vector2.ZERO

@onready var health_node: Node = $Health  # attach Health.gd as child
@onready var stats: Stats = $Stats  # attach Health.gd as child
@onready var event_manager: EventManager = $EventManager
@onready var item_holder: ItemHolder = $ItemHolder

@onready var anim_player: AnimationPlayer = get_node("AnimationPlayer")

func _ready():
    add_to_group("enemies")  # Add enemy to a group
    add_to_group("damageable")
    #$WeaponHolder.add_weapon(load("res://Resources/weapons/Pistol.tres"))
    #$WeaponHolder.add_weapon(load("res://Resources/weapons/Pistol.tres"))
    #$WeaponHolder.add_weapon(load("res://Resources/weapons/Pistol.tres"))
    #$WeaponHolder.add_weapon(load("res://Resources/weapons/Knife.tres"))
    #$WeaponHolder.add_weapon(load("res://Resources/weapons/Pistol.tres"))
    item_holder.add_item(load("res://Resources/items/BootsOfSpeed.tres"))
    #item_holder.add_item(load("res://Resources/items/RegenPassive.tres"))
    #item_holder.add_item(load("res://Resources/items/RegenPassive.tres"))
    #item_holder.add_item(load("res://Resources/items/RegenPassive.tres"))
    item_holder.add_item(load("res://Resources/items/RegenPassive.tres"))
    item_holder.add_item(load("res://Resources/items/ArmorPlate.tres"))
    item_holder.add_item(load("res://Resources/items/EnergyShieldBlock.tres"))
    item_holder.add_item(load("res://Resources/items/MinusArmorOnHitDebuff.tres"))
    item_holder.add_item(load("res://Resources/items/HomingShot.tres"))
    #item_holder.add_item(load("res://Resources/items/HealthMeat.tres"))
    #item_holder.add_item(load("res://Resources/items/HealthMeat.tres"))
    #item_holder.add_item(load("res://Resources/items/HealthMeat.tres"))
    #item_holder.add_item(load("res://Resources/items/HealthMeat.tres"))
    #item_holder.add_item(load("res://Resources/items/HealthMeat.tres"))
    #item_holder.add_item(load("res://Resources/items/HealthMeat.tres"))
    #item_holder.add_item(load("res://Resources/items/HealthMeat.tres"))
    target_position = global_position

func set_target_position(new_target: Vector2):
    target_position = new_target

func _physics_process(delta):
    if global_position.distance_to(target_position) < 5:
        #queue_free()
        #print("Enemy reached target!")
        anim_player.play("idle") 
        return
    anim_player.play("move")
    var direction = (target_position - global_position).normalized()
    # ✅ Use stats for movement speed
    var move_speed = stats.get_stat("movement_speed")
    velocity = direction * move_speed
    var collision = move_and_slide()
               
