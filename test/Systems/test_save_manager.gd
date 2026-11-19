# GdUnit generated TestSuite
class_name SaveManagerTest
extends GdUnitTestSuite

## The save file is one JSON document of named sections. These pin the parts a
## future section (progress, achievements) relies on: sections do not disturb
## each other, a crash cannot truncate the save, and a damaged file is kept.

const SCRATCH_PATH := "res://saves/test_save_manager.json"

var _saved_save_path := ""
var _scratch := ""


func before_test() -> void:
    _saved_save_path = SaveManager.save_path
    _scratch = ProjectSettings.globalize_path(SCRATCH_PATH)
    SaveManager.save_path = _scratch
    _remove_scratch_files()
    SaveManager.load_from_disk()


func after_test() -> void:
    SaveManager.save_path = _saved_save_path
    SaveManager.load_from_disk()
    _remove_scratch_files()
    collect_orphan_node_details()


func _remove_scratch_files() -> void:
    for suffix in ["", ".tmp", ".bak"]:
        if FileAccess.file_exists(_scratch + suffix):
            DirAccess.remove_absolute(_scratch + suffix)


func test_default_save_path_is_inside_the_project() -> void:
    var project_dir := ProjectSettings.globalize_path("res://")
    assert_bool(SaveManager.default_save_path().begins_with(project_dir)).override_failure_message(
        "the save must live in the project, not in user:// or Documents"
    ).is_true()


func test_sections_round_trip_through_the_file() -> void:
    SaveManager.set_section("options", {"music_volume": 42.0, "show_stats": true})
    SaveManager.set_section("progress", {"best_loop": 3})

    SaveManager.load_from_disk()

    assert_float(SaveManager.get_section("options")["music_volume"]).is_equal(42.0)
    assert_bool(SaveManager.get_section("options")["show_stats"]).is_true()
    assert_int(int(SaveManager.get_section("progress")["best_loop"])).is_equal(3)


func test_writing_one_section_leaves_the_others_alone() -> void:
    SaveManager.set_section("progress", {"best_loop": 3})
    SaveManager.set_section("options", {"show_stats": true})

    assert_int(int(SaveManager.get_section("progress")["best_loop"])).is_equal(3)


func test_file_carries_a_version_but_the_data_does_not() -> void:
    SaveManager.set_section("options", {"show_stats": true})

    var written: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_scratch))
    assert_int(int(written["version"])).is_equal(SaveManager.SAVE_VERSION)
    SaveManager.load_from_disk()
    assert_bool(SaveManager.data.has("version")).is_false()


func test_get_section_returns_a_copy() -> void:
    SaveManager.set_section("options", {"show_stats": true})
    var copy := SaveManager.get_section("options")
    copy["show_stats"] = false

    assert_bool(SaveManager.get_section("options")["show_stats"]).is_true()


func test_missing_file_and_missing_section_are_empty_not_errors() -> void:
    assert_bool(SaveManager.get_section("options").is_empty()).is_true()


func test_saving_leaves_no_temp_file_behind() -> void:
    SaveManager.set_section("options", {"show_stats": true})

    assert_bool(FileAccess.file_exists(_scratch + ".tmp")).is_false()
    assert_bool(FileAccess.file_exists(_scratch)).is_true()


## Losing a file that is merely unreadable would be losing the player's
## progress, so it is moved aside rather than overwritten by the next save.
func test_a_corrupt_file_is_kept_as_bak_and_the_game_starts_empty() -> void:
    var file := FileAccess.open(_scratch, FileAccess.WRITE)
    file.store_string("{ not json")
    file.close()

    SaveManager.load_from_disk()

    assert_bool(SaveManager.data.is_empty()).is_true()
    assert_bool(FileAccess.file_exists(_scratch + ".bak")).is_true()
    assert_bool(FileAccess.file_exists(_scratch)).is_false()
