extends Control

## Dev-only fixture: the shop with a stub character wearing sample items and
## weapons, so `ShopMenu` can be rendered on its own for a visual check (see
## `run_scene_shot.bat`). Not part of the game.

const SAMPLE_ITEMS := [
	"ArmorPlate", "CritGlass", "Knockback", "LifeDrain", "PlusDamageItem",
	"PoisonHit", "ProjSpeed", "RegenPassive",
]
const SAMPLE_WEAPONS := ["Fist", "Pistol", "Shotgun", "Knife", "Thorns"]

## The offer row is only 4 cards wide, so the pool has to be small enough that
## the two hand-built polarity items are guaranteed to appear alongside a plain
## one. Built rather than generated because an item whose curse is a modifier
## needs `NEGATIVE_MODIFIER_CHANCE` to go our way.
static func _offer_items() -> Array[Item]:
	var out: Array[Item] = []
	var regen := load("res://src/Systems/Items/modifiers/FlatRegenModifier.tscn")
	var drain := load("res://src/Systems/Items/modifiers/FlatLifeDrainModifier.tscn")
	# Only used for its build-time display cache; it needs no Stats child here.
	var cache := ItemFactory.new()

	# Positive AND negative modifier on one item: two toned effect lines.
	var two_effects := ItemBuilder.make_effect_item(
		"Regen Charm", "Grants special effect: Regen", regen, {})
	two_effects.effect_scene = [regen, drain]
	cache._store_effect_display(two_effects, [regen, drain])
	out.append(two_effects)

	# The awkward shape: a stat item whose ONLY effect scene is a drawback. Its
	# positive stat has to stay green instead of being forced red as a tradeoff.
	var curse_only := ItemBuilder.make_stat_item(
		"Damage Talisman", "Enhances damage at a cost.",
		{"damage": {"flat": 6.0}, "movement_speed": {"flat": -1.5}})
	curse_only.effect_scene = [drain]
	cache._store_effect_display(curse_only, [drain])
	out.append(curse_only)

	# A plain positive item, to prove the gold effect line is untouched.
	out.append(load("res://src/Resources/items/Knockback.tres"))
	out.append(load("res://src/Resources/items/PoisonHit.tres"))

	# `get_item_from_pool_or_generate()` picks with replacement, so the pool is
	# weighted to make both shapes show up in a 4-card row: the two-effect card is
	# listed twice, the rest once each.
	out.append(two_effects)

	cache.free()
	return out


func _ready() -> void:
	var character := _build_character()
	add_child(character)

	var item_holder: ItemHolder = character.get_node("ItemHolder")
	for item in SAMPLE_ITEMS:
		item_holder.add_item(load("res://src/Resources/items/%s.tres" % item))

	var weapon_holder: WeaponHolder = character.get_node("WeaponHolder")
	for weapon in SAMPLE_WEAPONS:
		weapon_holder.weapons.append(load("res://src/Resources/weapons/%s.tres" % weapon))

	character.stats.set_base_stat("money", 78)
	GlobalGameState.current_character = character

	var shop: CanvasLayer = load("res://src/Scenes/menu/ShopMenu.tscn").instantiate()
	add_child(shop)
	# `ShopMenu.item_factory` is wired by the real ShopStage; this fixture builds
	# its own (ItemFactory needs a `Stats` child for its @onready) so the offers
	# can be pinned. A fixed seed plus a pre-seeded `drop_pool` - which
	# `get_item_from_pool_or_generate()` drains - makes the screenshot repeatable
	# instead of showing whatever the generator rolled.
	var factory := ItemFactory.new()
	factory.name = "ItemFactory"
	var factory_stats := Stats.new()
	factory_stats.name = "Stats"
	factory.add_child(factory_stats)
	add_child(factory)
	shop.item_factory = factory
	factory.rng.seed = 20260930
	factory.drop_pool = _offer_items()
	# `show_menu()` pauses the tree and reads the character off the global, which
	# is exactly what the real portal does; a screenshot of a paused tree is
	# still drawn, so the pause is undone again right after.
	shop.show_menu()
	# Simulates the portal cleanup: phase 1 lists collected pickups as icon
	# tiles, phase 2 is the shop row whose cards carry the tone-coloured stat
	# body - the part worth screenshotting.
	shop.load_items([])
	shop.get_tree().paused = false


## See `test/tools/character_ui_preview.gd` for why these two placeholder children
## exist.
func _build_character() -> Character:
	var character := Character.new()
	character.name = "Character"

	var animation_player := AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	character.add_child(animation_player)

	var hitbox := Area2D.new()
	hitbox.name = "Hitbox"
	character.add_child(hitbox)

	var event_manager := EventManager.new()
	event_manager.name = "EventManager"
	character.add_child(event_manager)

	var stats := Stats.new()
	stats.name = "Stats"
	stats.event_manager = event_manager
	character.add_child(stats)

	var item_holder := ItemHolder.new()
	item_holder.name = "ItemHolder"
	character.add_child(item_holder)

	var weapon_holder := WeaponHolder.new()
	weapon_holder.name = "WeaponHolder"
	character.add_child(weapon_holder)

	return character
