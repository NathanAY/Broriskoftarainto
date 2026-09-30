extends Control

## Dev-only fixture: the shop with a stub character wearing sample items and
## weapons, so `ShopMenu` can be rendered on its own for a visual check (see
## `run_scene_shot.bat`). Not part of the game.

const SAMPLE_ITEMS := [
	"ArmorPlate", "CritGlass", "Knockback", "PlusDamageItem", "PoisonHit", "ProjSpeed",
]
const SAMPLE_WEAPONS := ["Fist", "Pistol", "Shotgun", "Knife", "Thorns"]


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
	# `show_menu()` pauses the tree and reads the character off the global, which
	# is exactly what the real portal does; a screenshot of a paused tree is
	# still drawn, so the pause is undone again right after.
	shop.show_menu()
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
