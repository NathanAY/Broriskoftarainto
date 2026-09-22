# weapon_builtin_effects.gd
## Static helper that binds built-in weapon modifiers to their owning weapon.
##
## Weapons declare built-in effects via `BaseWeapon.modifiers`, a Dictionary keyed
## by effect name. Effects split into two kinds:
## - hit-event effects (e.g. "knockback", "poison"): reuse the existing item
##   modifier scripts as nodes bound to the weapon, so they only fire on hits
##   caused by that weapon (never on another weapon's hits).
## - spawn-time effects (e.g. "pierce"): merged into projectile properties when
##   the weapon fires (there is no per-hit event involved).
extends RefCounted
class_name WeaponBuiltinEffects

# key (used in BaseWeapon.modifiers) -> modifier script to instantiate + bind
const MODIFIER_KEY_TO_SCRIPT := {
	"knockback": preload("res://src/Systems/Items/Modifiers/knockback_modifier.gd"),
	"poison": preload("res://src/Systems/Items/Modifiers/poison_modifier.gd"),
}

# alias config keys from the .tres dict onto the modifier script's variable names
const CONFIG_ALIASES := {
	"knockback": {
		"strength": "knockback_strength",
		"duration": "knockback_duration",
	},
	"poison": {
		"chance": "poison_chance",
		"duration": "duration",
		"tick_interval": "tick_interval",
		"max_stacks": "max_stacks",
	},
}

# keys not instantiated as modifier nodes; applied at spawn time instead
const SPAWN_TIME_KEYS := ["pierce"]


## Instantiate and bind one modifier node per hit-event effect declared in
## `weapon.modifiers`. Nodes live under the holder's WeaponHolder (or the holder
## itself) and are tracked on the weapon for later detach.
static func attach_for_weapon(weapon: BaseWeapon, holder: Node, em: EventManager) -> void:
	if weapon == null or holder == null or em == null:
		return
	if not is_instance_valid(holder):
		return

	var parent: Node = holder.get_node_or_null("WeaponHolder")
	if parent == null:
		parent = holder

	for key in weapon.modifiers:
		if not MODIFIER_KEY_TO_SCRIPT.has(key):
			continue
		var config: Dictionary = weapon.modifiers[key]
		var node: BaseModifier = MODIFIER_KEY_TO_SCRIPT[key].new()
		_apply_config(node, CONFIG_ALIASES.get(key, {}), config)
		node.bound_weapon = weapon
		parent.add_child(node)
		node.attachEventManager(em)
		if not weapon._bound_effect_nodes.has(node):
			weapon._bound_effect_nodes.append(node)


## Unsubscribe and free every node bound to `weapon`.
static func detach(weapon: BaseWeapon) -> void:
	if weapon == null:
		return
	for node in weapon._bound_effect_nodes:
		if not is_instance_valid(node):
			continue
		if node.has_method("_unsubscribe_all"):
			node._unsubscribe_all()
		node.queue_free()
	weapon._bound_effect_nodes.clear()


## Player-facing tooltip lines for the weapon's built-in effects (e.g.
## "pierce: 1", "knockback: 120.0", "poison: 50% chance, 3.0s"). Reads the
## declared `.tres` config so displayed numbers always match the live effect.
static func builtin_tooltip_lines(weapon: BaseWeapon) -> PackedStringArray:
	var lines := PackedStringArray()
	if weapon == null:
		return lines
	for key in weapon.modifiers:
		var config: Dictionary = weapon.modifiers[key]
		if typeof(config) != TYPE_DICTIONARY:
			continue
		match key:
			"pierce":
				lines.append("pierce: %d" % int(config.get("amount", 0)))
			"knockback":
				lines.append("knockback: %s" % str(config.get("strength", 0.0)))
			"poison":
				var parts := PackedStringArray()
				if config.has("chance"):
					parts.append("%d%% chance" % int(round(float(config["chance"]) * 100.0)))
				if config.has("duration"):
					parts.append("%ss" % str(config["duration"]))
				lines.append("poison: " + ", ".join(parts))
	return lines


## Spawn-time effects for `weapon`, e.g. `{"pierce": 1}`. Merged into projectile
## properties by ProjectileWeapon before firing.
static func get_spawn_time_modifiers(weapon: BaseWeapon) -> Dictionary:
	var result := {}
	if weapon == null:
		return result
	for key in weapon.modifiers:
		if not SPAWN_TIME_KEYS.has(key):
			continue
		var config: Dictionary = weapon.modifiers[key]
		result[key] = config.get("amount", 0)
	return result


static func _apply_config(node: BaseModifier, aliases: Dictionary, config: Dictionary) -> void:
	for key in config:
		var target: String = aliases.get(key, key)
		if target != "" and node.has_method("set") and node.get(target) != null:
			node.set(target, config[key])