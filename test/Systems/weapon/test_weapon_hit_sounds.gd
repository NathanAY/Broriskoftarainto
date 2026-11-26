class_name WeaponHitSoundsTest
extends GdUnitTestSuite

## Sound wiring in the weapon `.tres` files. Checks the lists and their paths, not
## playback: a list that loads but points at the wrong file would be a silent
## regression, so each entry is checked to be an AudioStream under the sounds folder.

const SOUNDS := "res://src/Assets/sounds/"
const HIT_WEAPONS := [
    "res://src/Resources/weapons/Fist.tres",
    "res://src/Resources/weapons/Pistol.tres",
    "res://src/Resources/weapons/Smg.tres",
    "res://src/Resources/weapons/Shotgun.tres",
    "res://src/Resources/weapons/Thorns.tres",
    "res://src/Resources/weapons/DeathAura.tres",
]


func test_weapons_have_hit_sounds() -> void:
    for path in HIT_WEAPONS:
        var weapon := load(path) as BaseWeapon
        assert_object(weapon).is_not_null()
        assert_array(weapon.hit_sound).override_failure_message(path + " has no hit_sound").is_not_empty()
        _assert_sounds_under_folder(weapon.hit_sound, path)


func test_death_aura_has_attack_sound() -> void:
    var aura := load("res://src/Resources/weapons/DeathAura.tres") as BaseWeapon
    assert_array(aura.attack_sound).is_not_empty()
    _assert_sounds_under_folder(aura.attack_sound, "DeathAura")


func _assert_sounds_under_folder(streams: Array, owner: String) -> void:
    for stream in streams:
        assert_bool(stream is AudioStream).override_failure_message(owner + ": not an AudioStream").is_true()
        assert_str((stream as AudioStream).resource_path).override_failure_message(owner + ": wrong folder").starts_with(SOUNDS)
