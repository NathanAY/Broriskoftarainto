extends Control

## Dev-only fixture: the character menu with a stub character wearing sample
## items and weapons, so `CharacterUI` can be rendered on its own for a visual
## check (see `run_scene_shot.bat`). It adds no effect nodes or
## weapons to the tree - it only fills the holder's arrays, which is what the UI
## reads.
##
## Not part of the game: nothing loads this scene.

const SAMPLE_ITEMS := [
	"ArmorPlate", "AttackSpeedItem", "BootsOfSpeed", "CritGlass", "Knockback",
	"LifeDrain", "PlusDamageItem", "PoisonHit", "RegenPassive", "ProjSpeed",
]
const SAMPLE_WEAPONS := ["Fist", "Pistol", "Shotgun", "DeathAura", "Thorns"]


func _ready() -> void:
	var character := _build_character()
	add_child(character)

	var item_holder: ItemHolder = character.get_node("ItemHolder")
	for item in SAMPLE_ITEMS:
		item_holder.add_item(load("res://src/Resources/items/%s.tres" % item))

	var weapon_holder: WeaponHolder = character.get_node("WeaponHolder")
	for weapon in SAMPLE_WEAPONS:
		weapon_holder.weapons.append(load("res://src/Resources/weapons/%s.tres" % weapon))

	# `CharacterUi._ready()` reads the character off the global, so it has to be
	# published before the UI is added.
	GlobalGameState.current_character = character

	var ui: Control = load("res://src/ui/CharacterUI.tscn").instantiate()
	add_child(ui)
	ui.visible = true


## A bare Character with the children `CharacterUi._ready()` looks up. It is
## deliberately not `Systems/Character.tscn`: this fixture is a UI, not a game
## entity, and instantiating the real scene would drag in its Hitbox /
## AnimationPlayer / starting loadout. The two below are only there because
## `Character._ready()` dereferences them unconditionally.
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
