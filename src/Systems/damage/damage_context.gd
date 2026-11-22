# DamageContext.gd
## One hit, as it travels through `Damage.deal()`. Damage events carry only
## `{"damage_context": ctx}`, so everything a listener needs lives here.
extends Resource
class_name DamageContext

var attacker: Node = null      # entity whose Stats and EventManager the hit uses; set by Damage.deal
var source: Node = null        # the physical thing that hit (projectile, orb, explosion, the holder)
var target: Node = null        # entity that receives; must own a Health child
var weapon: BaseWeapon = null  # weapon behind a direct hit; null for secondary damage (no on_hit)
var base_amount: float = 0.0
var final_amount: float = 0.0
var can_crit: bool = true      # false for damage over time
var is_crit: bool = false
var energy_shield_absorbed: float = 0.0
var damage_type: String = "physical"  # physical, fire, poison, etc.
var tags: Array[String] = []   # ["projectile", "melee", "bleed"]

var fraction_of_max_health: float  # set by Health once the hit has landed
