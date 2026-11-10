class_name GamepediaData
extends RefCounted
## What the Gamepedia shows, as plain dictionaries, read from the shipped data.
##
## Nothing here is a second copy of a number: weapons are the `.tres` files,
## enemies are the enemy scenes, effects are the modifier scenes. A weapon,
## enemy or modifier added to its folder shows up without touching this file.

const WEAPON_DIRS := ["res://src/Resources/weapons", "res://src/Resources/weapons/boss"]
const ENEMY_DIR := "res://src/Systems/enemies"
const MODIFIER_DIR := "res://src/Systems/Items/modifiers"

const CHARACTER_DIR := "res://src/Assets/character"
const MODIFIER_ICON_DIR := "res://src/Assets/modifiers/"

## The enemy scene with no suffix is the basic one the others are compared to.
const BASE_ENEMY_NAME := "Grunt"


## `{name, description, rows}` per weapon; `rows` is `[label, value]` pairs
## (damage, range, attack speed, built-in effects) in the card's own order.
static func weapon_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for dir in WEAPON_DIRS:
		for path in _files(dir, ".tres"):
			var weapon := load(path) as BaseWeapon
			if weapon != null:
				entries.append(_weapon_entry(weapon))
	return entries


## `{name, rows, weapons}` per enemy scene. `rows` is the base stats, `weapons`
## is one weapon entry per weapon the enemy attacks with.
static func enemy_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for path in _files(ENEMY_DIR, ".tscn"):
		var scene := load(path) as PackedScene
		if scene == null:
			continue
		var enemy := scene.instantiate()
		if enemy is Enemy:
			entries.append(_enemy_entry(path, enemy))
		enemy.free()
	return entries


## `{name, description, rows, resource}` per character, found the way the
## character select screen finds them: every `CharacterData` `.tres` under the
## character art folder. `rows` is the same card rows that screen shows
## (flavour, base stats, effects, starting gear) as `[label, value]` pairs.
static func character_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for path in _tres_files_recursive(CHARACTER_DIR):
		var character := load(path) as CharacterData
		if character == null:
			continue
		var rows: Array = []
		for row in ItemTooltip.card_rows(character):
			if row.kind != ItemCardRow.Kind.NAME and row.kind != ItemCardRow.Kind.FLAVOR:
				rows.append([row.label, row.value] if not row.label.is_empty() else ["", row.to_line()])
		entries.append({
			"name": character.display_name,
			"description": character.description.strip_edges(),
			"rows": rows,
			"resource": character,
		})
	return entries


## `{name, text, stats, trigger, cost, texture}` per modifier an item can carry.
static func modifier_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for path in _files(MODIFIER_DIR, ".tscn"):
		var scene := load(path) as PackedScene
		if scene == null:
			continue
		var display := ItemTooltip.resolve_effect_display(scene)
		entries.append({
			"name": str(display["name"]),
			"text": str(display["text"]),
			"stats": str(display["stats"]),
			"trigger": ItemTooltip.humanize_effect_name(str(display["trigger"])),
			"cost": int(display["effect_kind"]) == BaseModifier.EffectKind.COST,
			"texture": _modifier_icon(path),
		})
	return entries


static func _weapon_entry(weapon: BaseWeapon) -> Dictionary:
	var rows: Array = []
	for row in ItemTooltip.weapon_card_rows(weapon):
		if row.kind == ItemCardRow.Kind.WEAPON:
			rows.append([row.label, row.value])
	return {
		"name": ItemTooltip.humanize_effect_name(weapon.name),
		"description": weapon.description.strip_edges(),
		"rows": rows,
		"resource": weapon,
	}


static func _enemy_entry(path: String, enemy: Enemy) -> Dictionary:
	var stats: Dictionary = Stats.DEFAULT_STATS.duplicate()
	var stats_node := enemy.get_node_or_null("Stats")
	if stats_node != null:
		stats.merge(stats_node.stats, true)
	var weapons: Array[Dictionary] = []
	if enemy.contact_weapon != null:
		weapons.append(_weapon_entry(enemy.contact_weapon))
	var holder := enemy.get_node_or_null("WeaponHolder")
	if holder != null:
		for weapon in holder.weapons:
			weapons.append(_weapon_entry(weapon))
	return {
		"name": _enemy_name(path),
		"rows": [
			["Health", ItemTooltip.format_value(float(stats["health"]))],
			["Movement Speed", ItemTooltip.format_value(float(stats["movement_speed"])) + " m/s"],
		],
		"weapons": weapons,
		"texture": (enemy.get_node("Node2D/Sprite2D") as Sprite2D).texture,
	}


## The art an item shows for this effect: the file named after the scene, the
## same lookup `ItemIconGenerator` does, with the shared default as fallback.
static func _modifier_icon(scene_path: String) -> Texture2D:
	var path := MODIFIER_ICON_DIR + scene_path.get_file().get_basename().to_lower() + ".png"
	if not ResourceLoader.exists(path):
		path = MODIFIER_ICON_DIR + "_default.png"
	return load(path)


static func _tres_files_recursive(dir_path: String) -> PackedStringArray:
	var found := _files(dir_path, ".tres")
	for sub in DirAccess.get_directories_at(dir_path):
		found.append_array(_tres_files_recursive(dir_path.path_join(sub)))
	return found


## `EnemyBulwark.tscn` -> "Bulwark"; the bare `Enemy.tscn` is the grunt.
static func _enemy_name(path: String) -> String:
	var base := path.get_file().get_basename().trim_prefix("Enemy")
	return BASE_ENEMY_NAME if base.is_empty() else base


static func _files(dir_path: String, extension: String) -> PackedStringArray:
	var found := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("Gamepedia: cannot open " + dir_path)
		return found
	for file_name in dir.get_files():
		if file_name.ends_with(extension):
			found.append("%s/%s" % [dir_path, file_name])
	found.sort()
	return found
