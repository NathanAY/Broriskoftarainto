#character.gd
extends CharacterBody2D
class_name Character

@onready var event_manager: EventManager = $EventManager
@onready var item_holder: ItemHolder = $ItemHolder
@onready var stats: Stats = $Stats
@onready var weapon_holder: WeaponHolder = $WeaponHolder
@onready var sprite: Sprite2D = $Node2D/Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var current_target = null
var fire_timer = 0.0
# var timer = Timer.new()

signal character_died

func _ready():
    add_to_group("character")
    add_to_group("damageable")
    for c in get_children():
        if c.has_method("attachEventManager"):
            c.attachEventManager(event_manager)
    
    GlobalGameState.current_character = self
    var weapons = GlobalGameState.starting_weapons
    for weapon_path in weapons:
        $WeaponHolder.add_weapon(load(weapon_path))
    # Items
    var items = GlobalGameState.starting_items
    for item_path in items:
        $ItemHolder.add_item(load(item_path)) 
 
    $WeaponHolder.add_weapon(load("res://src/Resources/weapons/Fist.tres"))
    #$WeaponHolder.add_weapon(load("res://src/Resources/weapons/Thorns.tres"))
    #$WeaponHolder.add_weapon(load("res://src/Resources/weapons/Pistol.tres"))
    #$WeaponHolder.add_weapon(load("res://src/Resources/weapons/Shotgun.tres"))

    #$ItemHolder.add_item(load("res://src/Resources/items/AttackSpeedOnHitBuff.tres"))
    #$ItemHolder.add_item(load("res://src/Resources/items/ProjSpeed.tres"))
    #$ItemHolder.add_item(load("res://src/Resources/items/HomingProjectileOnHit.tres"))
    #$ItemHolder.add_item(load("res://src/Resources/items/HomingProjectileFromTarget.tres"))
    #$ItemHolder.add_item(load("res://src/Resources/items/AttackSpeedItem.tres"))
    #$ItemHolder.add_item(load("res://src/Resources/items/SpreadShot.tres"))
    #$ItemHolder.add_item(load("res://src/Resources/items/MoreDamageToHealthy.tres"))sd
    #$ItemHolder.add_item(load("res://src/Resources/items/BombOnHit.tres"))
    #$ItemHolder.add_item(load("res://src/Resources/items/ReflectProjectile.tres"))
    #$ItemHolder.add_item(load("res://src/Resources/items/SpiningOrb.tres"))
    $ItemHolder.add_item(load("res://src/Resources/items/RegenPassive.tres"))
    #$ItemHolder.add_item(load("res://src/Resources/items/RegenPassive.tres"))
    #$ItemHolder.add_item(load("res://src/Resources/items/HealOnEvent.tres"))
    #$ItemHolder.add_item(load("res://src/Resources/items/LifeLeachModifier.tres"))
    #$ItemHolder.add_item(load("res://src/Resources/items/EmergencyHeal.tres"))
    #$ItemHolder.add_item(load("res://src/Resources/items/RegenPassive.tres"))
    #$ItemHolder.add_item(load("res://src/Resources/items/Knockback.tres"))
    #$ItemHolder.add_item(load("res://src/Resources/items/AttackSpeedIfStill.tres"))
    #$ItemHolder.add_item(load("res://src/Resources/items/MinusArmorOnHitDebuff.tres"))
    $ItemHolder.add_item(load("res://src/Resources/items/BootsOfSpeed.tres"))
    $ItemHolder.add_item(load("res://src/Resources/items/BootsOfSpeed.tres"))
    #$ItemHolder.add_item(load("res://src/Resources/items/HomingShot.tres"))
    #$ItemHolder.add_item(load("res://src/Resources/items/EnergyShieldBlock.tres"))
    #$ItemHolder.add_item(load("res://src/Resources/items/CritGlass.tres"))
    #$ItemHolder.add_item(load("res://src/Resources/items/PlusDamageItem.tres"))
    # $ItemHolder.add_item(load("res://src/Resources/items/HealthMeat.tres"))
    $ItemHolder.add_item(load("res://src/Resources/items/HealthMeat.tres"))
    
    collision_layer = 1
    # Only collide with arena walls (layer 4) — stays inside the ground.
    # Hit detection goes through the Hitbox Area2D, not the body.
    collision_mask = Arena.WALL_LAYER_BIT
    
    $Hitbox.collision_layer = 3
    $Hitbox.collision_mask = 7
    event_manager.subscribe("on_death", Callable(self, "_die"))   
    event_manager.subscribe("before_take_damage", Callable(self, "_flash"))

func _on_area_2d_area_entered(area: Area2D) -> void:
    if area.get_parent().is_in_group("enemies"):
        area.get_parent().queue_free()
        print("Enemy destroyed!")  

func _flash(_event):
    var tween = create_tween()
    tween.tween_property(sprite, "modulate", Color(1, 4, 1), 0.1)
    tween.tween_property(sprite, "modulate", Color(4, 1, 1, 0), 0.1).from(Color(1, 1, 4))
    tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.0)

func _die(_event: Dictionary):
    emit_signal("character_died")
    queue_free()

func _exit_tree() -> void:
    if GlobalGameState.current_character == self:
        GlobalGameState.current_character = null
