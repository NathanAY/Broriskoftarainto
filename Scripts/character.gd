#character.gd
extends CharacterBody2D
class_name Character

@onready var event_manager: EventManager = $EventManager
@onready var item_holder = $ItemHolder
@onready var stats = $Stats
@onready var weapon_holder = $WeaponHolder
@onready var sprite: Sprite2D = $Node2D/Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var current_target = null
var fire_timer = 0.0
var timer = Timer.new()

signal character_died

func _ready():
    add_to_group("character")
    add_to_group("damageable")
    for c in get_children():
        if c.has_method("attachEventManager"):
            c.attachEventManager(event_manager)

    var weapons = GlobalGameState.starting_weapons
    for weapon_path in weapons:
        $WeaponHolder.add_weapon(load(weapon_path))
    # Items
    var items = GlobalGameState.starting_items
    for item_path in items:
        $ItemHolder.add_item(load(item_path)) 
 
    #$WeaponHolder.add_weapon(load("res://Resources/weapons/Fist.tres"))
    #$WeaponHolder.add_weapon(load("res://Resources/weapons/Knife.tres"))
    #$WeaponHolder.add_weapon(load("res://Resources/weapons/Thorns.tres"))
    $WeaponHolder.add_weapon(load("res://Resources/weapons/Pistol.tres"))
    #$WeaponHolder.add_weapon(load("res://Resources/weapons/Shotgun.tres"))
    #$WeaponHolder.add_weapon(load("res://Resources/weapons/Shotgun.tres"))

    #$ItemHolder.add_item(load("res://Resources/items/AttackSpeedOnHitBuff.tres"))
    #$ItemHolder.add_item(load("res://Resources/items/ProjSpeed.tres"))
    #$ItemHolder.add_item(load("res://Resources/items/HomingProjectileOnHit.tres"))
    #$ItemHolder.add_item(load("res://Resources/items/HomingProjectileFromTarget.tres"))
    #$ItemHolder.add_item(load("res://Resources/items/AttackSpeedItem.tres"))
    #$ItemHolder.add_item(load("res://Resources/items/AttackSpeedItem.tres"))
    #$ItemHolder.add_item(load("res://Resources/items/SpreadShot.tres"))
    #$ItemHolder.add_item(load("res://Resources/items/ChainProjectile.tres"))
    #$ItemHolder.add_item(load("res://Resources/items/BounceProjectile.tres"))
    #$ItemHolder.add_item(load("res://Resources/items/LifeOnKill.tres"))
    #$ItemHolder.add_item(load("res://Resources/items/MoreDamageToHealthy.tres"))
    #$ItemHolder.add_item(load("res://Resources/items/BombOnHit.tres"))
    $ItemHolder.add_item(load("res://Resources/items/ReflectProjectile.tres"))
    #$ItemHolder.add_item(load("res://Resources/items/ExplosiveShot.tres"))
    $ItemHolder.add_item(load("res://Resources/items/SpiningOrb.tres"))
    $ItemHolder.add_item(load("res://Resources/items/SpiningOrb.tres"))
    $ItemHolder.add_item(load("res://Resources/items/RegenPassive.tres"))
    $ItemHolder.add_item(load("res://Resources/items/RegenPassive.tres"))
    #$ItemHolder.add_item(load("res://Resources/items/HealOnEvent.tres"))
    #$ItemHolder.add_item(load("res://Resources/items/LifeLeachModifier.tres"))
    #$ItemHolder.add_item(load("res://Resources/items/EmergencyHeal.tres"))
    #$ItemHolder.add_item(load("res://Resources/items/RegenPassive.tres"))
    #$ItemHolder.add_item(load("res://Resources/items/Knockback.tres"))
    #$ItemHolder.add_item(load("res://Resources/items/AttackSpeedIfStill.tres"))
    $ItemHolder.add_item(load("res://Resources/items/MinusArmorOnHitDebuff.tres"))
    #$ItemHolder.add_item(load("res://Resources/items/PoisonHit.tres"))
    $ItemHolder.add_item(load("res://Resources/items/BootsOfSpeed.tres"))
    $ItemHolder.add_item(load("res://Resources/items/BootsOfSpeed.tres"))
    #$ItemHolder.add_item(load("res://Resources/items/BootsOfSpeed.tres"))
    #$ItemHolder.add_item(load("res://Resources/items/HomingShot.tres"))
    $ItemHolder.add_item(load("res://Resources/items/HealthMeat.tres"))
    $ItemHolder.add_item(load("res://Resources/items/HealthMeat.tres"))
    #$ItemHolder.add_item(load("res://Resources/items/EnergyShieldBlock.tres"))
    #$ItemHolder.add_item(load("res://Resources/items/CritGlass.tres"))
    #$ItemHolder.add_item(load("res://Resources/items/PlusDamageItem.tres"))
    #$ItemHolder.add_item(load("res://Resources/items/AttackSpeedItem.tres"))
    
    collision_layer = 1
    collision_mask = 0   # doesn't need to collide with anything
    
    $Hitbox.collision_layer = 3
    $Hitbox.collision_mask = 5
    event_manager.subscribe("on_death", Callable(self, "_die"))   
    event_manager.subscribe("before_take_damage", Callable(self, "_flash"))

func _on_area_2d_area_entered(area: Area2D) -> void:
    if area.get_parent().is_in_group("enemies"):
        area.get_parent().queue_free()
        print("Enemy destroyed!")  

func _flash(event):
    var sprite = $Node2D/Sprite2D
    var tween = create_tween()
    tween.tween_property(sprite, "modulate", Color(1, 4, 1), 0.2)
    tween.tween_property(sprite, "modulate", Color(4, 1, 1, 0), 0.2).from(Color(1, 1, 4))
    tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.0)

func _die(event: Dictionary):
    emit_signal("character_died")
    queue_free()
