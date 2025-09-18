#tower.gd
extends CharacterBody2D

@onready var event_manager = $EventManager
@onready var item_holder = $ItemHolder
@onready var stats = $Stats
@onready var weapon_holder = $WeaponHolder

var current_target = null
var fire_timer = 0.0
var timer = Timer.new()

func _ready():
    add_to_group("tower")
    add_to_group("damageable")
    for c in get_children():
        if c.has_method("attachEventManager"):
            c.attachEventManager(event_manager)
    
    $WeaponHolder.add_weapon(load("res://Resources/weapons/Knife.tres"))
    #$WeaponHolder.add_weapon(load("res://Resources/weapons/Pistol.tres"))
    $WeaponHolder.add_weapon(load("res://Resources/weapons/Shotgun.tres"))
    $ItemHolder.add_item(load("res://Resources/items/AttackSpeedItem.tres"))
    $ItemHolder.add_item(load("res://Resources/items/AttackSpeedItem.tres"))
    $ItemHolder.add_item(load("res://Resources/items/AttackSpeedItem.tres"))
    #$ItemHolder.add_item(load("res://Resources/items/AttackSpeedItem.tres"))
    #$ItemHolder.add_item(load("res://Resources/items/AttackSpeedItem.tres"))
    #$ItemHolder.add_item(load("res://Resources/items/SpreadShot.tres"))
    #$ItemHolder.add_item(load("res://Resources/items/ChainProjectile.tres"))
    #$ItemHolder.add_item(load("res://Resources/items/ExplosiveShot.tres"))
    $ItemHolder.add_item(load("res://Resources/items/RegenPassive.tres"))
    $ItemHolder.add_item(load("res://Resources/items/RegenPassive.tres"))
    $ItemHolder.add_item(load("res://Resources/items/AttackSpeedIfStill.tres"))
    $ItemHolder.add_item(load("res://Resources/items/MinusArmorOnHitDebuff.tres"))
    #$ItemHolder.add_item(load("res://Resources/items/PoisonHit.tres"))
    $ItemHolder.add_item(load("res://Resources/items/BootsOfSpeed.tres"))
    $ItemHolder.add_item(load("res://Resources/items/BootsOfSpeed.tres"))
    $ItemHolder.add_item(load("res://Resources/items/BootsOfSpeed.tres"))
    $ItemHolder.add_item(load("res://Resources/items/HomingShot.tres"))
    $ItemHolder.add_item(load("res://Resources/items/HealthMeat.tres"))
    #$ItemHolder.add_item(load("res://Resources/items/EnergyShieldBlock.tres"))
    #$ItemHolder.add_item(load("res://Resources/items/CritGlass.tres"))
    #$ItemHolder.add_item(load("res://Resources/items/PlusDamageItem.tres"))
    #$ItemHolder.add_item(load("res://Resources/items/AttackSpeedItem.tres"))

func _draw():
    # Draw a circle showing the attack range (for debugging)
    #draw_circle(Vector2.ZERO, stats.get_stat("attack_range"), Color(1, 0, 0, 0.02))
    draw_circle(Vector2.ZERO, 100, Color(1, 0, 0, 0.02))
    pass

func _on_area_2d_area_entered(area: Area2D) -> void:
    if area.get_parent().is_in_group("enemies"):
        area.get_parent().queue_free()
        print("Enemy destroyed!")  
