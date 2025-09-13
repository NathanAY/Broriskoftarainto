# DamageContext.gd
extends Resource
class_name DamageContext

var source: Node = null        # who dealt the damage
var target: Node = null        # who receives
var base_amount: float = 0.0
var final_amount: float = 0.0
var is_crit: bool = false
var armor_applied: int = 0   # optional, for debugging/logging
var armour_damage_multiplier: float = 0.0
var damage_type: String = "physical"  # physical, fire, poison, etc.
var tags: Array[String] = []   # ["projectile", "melee", "bleed"]
