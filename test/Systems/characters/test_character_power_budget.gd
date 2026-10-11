# GdUnit TestSuite for the §5 character power budget: every character's starting
# kit must sit inside the rulebook band relative to the reference character.
#
# Reference = Multitasker (docs/systems/balance.md §5). Bands are the design
# decision recorded there: WB_solo within +/-30% and EHP within +/-60% of the
# reference. Nothing is pinned to a literal - every figure is derived from the
# .tres under test, so a rebalance moves the numbers without rotting the suite.
#
# EHP counts armor only when an ArmorModifier scene is declared next to the armor
# value, because a bare `armor` stat never reduces damage (armor_modifier.gd).
#
# WB_solo uses the character's *weapon* only. The Ranger's Spread item is a
# deliberate clear-power exception (SpreadModifier is +200% clear WB and is kept
# as-is by design), so it is excluded here; see docs/systems/balance.md §5.
class_name CharacterPowerBudgetTest
extends GdUnitTestSuite

const CHARACTERS_DIR := "res://src/Assets/character"
const MULTITASKER := "res://src/Assets/character/multitasker/Multitasker.tres"
const ARMOR_MODIFIER_SCENE := "res://src/Systems/Items/modifiers/ArmorModifier.tscn"

# docs/systems/balance.md §5 target bands, relative to the reference character.
const WB_SOLO_BAND := 0.30
const EHP_BAND := 0.60

# §4.3 uptime by archetype. The rulebook keys this off effective range, but a
# contact weapon (Thorns) keeps the default 1.33 m range while never using it to
# pick targets, so the archetype is the honest key here.
const MELEE_UPTIME := 0.70
const CONTACT_UPTIME := 0.90
const RANGED_UPTIME := 0.85


# ---------------- the two bands ----------------

func test_every_character_starts_armed() -> void:
	for path in _character_paths():
		var data: CharacterData = load(path)
		assert_bool(data.starting_weapons.size() >= 1).override_failure_message(
			"%s starts with no weapon" % data.display_name).is_true()


func test_starting_wb_solo_is_within_band() -> void:
	var reference: Dictionary = _reference()
	for path in _character_paths():
		var data: CharacterData = load(path)
		var wb := _wb_solo(data, _folded_stats(data))
		var ratio := wb / float(reference["wb"])
		assert_float(ratio).override_failure_message(
			"%s WB_solo %.2f is %.2fx the reference %.2f (band %.2f..%.2f)" % [
				data.display_name, wb, ratio, reference["wb"],
				1.0 - WB_SOLO_BAND, 1.0 + WB_SOLO_BAND
			]).is_between(1.0 - WB_SOLO_BAND, 1.0 + WB_SOLO_BAND)


func test_starting_ehp_is_within_band() -> void:
	var reference: Dictionary = _reference()
	for path in _character_paths():
		var data: CharacterData = load(path)
		var ehp := _ehp(data, _folded_stats(data))
		var ratio := ehp / float(reference["ehp"])
		assert_float(ratio).override_failure_message(
			"%s EHP %.1f is %.2fx the reference %.1f (band %.2f..%.2f)" % [
				data.display_name, ehp, ratio, reference["ehp"],
				1.0 - EHP_BAND, 1.0 + EHP_BAND
			]).is_between(1.0 - EHP_BAND, 1.0 + EHP_BAND)


# ---------------- no two characters are the same kit ----------------

func test_characters_have_distinct_kits() -> void:
	var seen := {}
	for path in _character_paths():
		var data: CharacterData = load(path)
		var signature := _signature(data)
		assert_bool(seen.has(signature)).override_failure_message(
			"%s has the same kit as %s" % [data.display_name, seen.get(signature, "")]).is_false()
		seen[signature] = data.display_name


# ---------------- helpers ----------------

func _character_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	_collect(CHARACTERS_DIR, paths)
	return paths


func _collect(dir_path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := dir_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect(full, out)
		elif entry.ends_with(".tres"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()


func _reference() -> Dictionary:
	var data: CharacterData = load(MULTITASKER)
	var stats := _folded_stats(data)
	return {"wb": _wb_solo(data, stats), "ehp": _ehp(data, stats)}


## DEFAULT_STATS, then the character's base_stats overwrite, then dict modifiers.
func _folded_stats(data: CharacterData) -> Dictionary:
	var stats := Stats.DEFAULT_STATS.duplicate()
	for key in data.base_stats:
		stats[key] = float(data.base_stats[key])
	for mod in data.modifiers:
		if mod is not Dictionary:
			continue
		for stat_name in mod:
			if stat_name == "condition":
				continue
			var entry: Dictionary = mod[stat_name]
			var value := float(stats.get(stat_name, 0.0)) + float(entry.get("flat", 0.0))
			stats[stat_name] = value * (1.0 + float(entry.get("percent", 0.0)))
	return stats


func _has_armor_behavior(data: CharacterData) -> bool:
	for mod in data.modifiers:
		if mod is PackedScene and mod.resource_path == ARMOR_MODIFIER_SCENE:
			return true
	return false


func _ehp(data: CharacterData, stats: Dictionary) -> float:
	var health := float(stats.get("health", 0.0))
	if not _has_armor_behavior(data):
		return health
	var armor := float(stats.get("armor", 0.0))
	return health / (10.0 / (10.0 + armor))


func _wb_solo(data: CharacterData, stats: Dictionary) -> float:
	var weapon: BaseWeapon = data.starting_weapons[0]
	var per_volley := weapon.base_damage
	if weapon is ShotgunWeapon:
		per_volley *= weapon.pellet_count
	var raw := per_volley * float(stats.get("damage", 1.0)) \
		* weapon.base_attack_speed * float(stats.get("attack_speed", 1.0))
	return raw * _uptime(weapon)


func _uptime(weapon: BaseWeapon) -> float:
	if weapon is ContactWeapon:
		return CONTACT_UPTIME
	if weapon is MeleeWeapon:
		return MELEE_UPTIME
	return RANGED_UPTIME


func _signature(data: CharacterData) -> String:
	var parts := PackedStringArray()
	var keys: Array = data.base_stats.keys()
	keys.sort()
	for key in keys:
		parts.append("%s=%s" % [key, str(data.base_stats[key])])
	for weapon in data.starting_weapons:
		parts.append("weapon=%s" % weapon.name)
	for item in data.starting_items:
		parts.append("item=%s" % item.name)
	for mod in data.modifiers:
		if mod is Dictionary:
			var mod_keys: Array = mod.keys()
			mod_keys.sort()
			for key in mod_keys:
				parts.append("mod=%s:%s" % [key, str(mod[key])])
	return "|".join(parts)
