# GdUnit generated TestSuite
class_name MusicManagerTest
extends GdUnitTestSuite

const MUSIC_MANAGER_PATH := "res://src/Scripts/autoload/music_manager.gd"
const TRACKS_DIRECTORY := "res://src/Assets/music"
const EXPECTED_TRACK_COUNT := 17

var music_manager: Node


func before_test() -> void:
    music_manager = load(MUSIC_MANAGER_PATH).new()
    add_child(music_manager)


func after_test() -> void:
    if is_instance_valid(music_manager):
        music_manager.get_tree().node_added.disconnect(music_manager._on_node_added)
        music_manager.queue_free()
        music_manager = null
    collect_orphan_node_details()


func test_music_does_not_autostart_in_tests() -> void:
    assert_that(music_manager._music_started).is_false()
    assert_that(music_manager.player.playing).is_false()


func test_tracks_not_loaded_until_play() -> void:
    assert_that(music_manager._tracks_loaded).is_false()
    assert_that(music_manager.tracks.is_empty()).is_true()
    music_manager.play()
    assert_that(music_manager._tracks_loaded).is_true()
    assert_that(music_manager.tracks.is_empty()).is_false()


func test_music_starts_when_game_scene_is_loaded() -> void:
    validate_music_starts_for_scene("res://src/Scenes/Game.tscn")


func test_music_starts_when_menu_scene_is_loaded() -> void:
    validate_music_starts_for_scene("res://src/Scenes/menu/Main.tscn")


func validate_music_starts_for_scene(scene_path: String) -> void:
    var previous_scene := get_tree().current_scene
    var fake_scene := Node.new()
    fake_scene.scene_file_path = scene_path
    get_tree().get_root().add_child(fake_scene)
    get_tree().current_scene = fake_scene
    music_manager._music_started = false
    music_manager._try_start_music()
    assert_that(music_manager._music_started).is_true()
    assert_that(music_manager.player.playing).is_true()
    get_tree().current_scene = previous_scene
    fake_scene.queue_free()


func test_autoload_is_registered() -> void:
    var autoload := get_tree().get_root().get_node_or_null("MusicManager")
    assert_that(autoload).is_not_null()


func test_all_music_files_loaded() -> void:
    music_manager.load_tracks(TRACKS_DIRECTORY)
    assert_that(music_manager.tracks.size()).is_equal(EXPECTED_TRACK_COUNT)


func test_play_sets_a_stream() -> void:
    music_manager._last_track = null
    music_manager.play()
    assert_that(music_manager.player.stream).is_not_null()
    assert_that(music_manager.tracks).contains(music_manager.player.stream)


func test_no_consecutive_repeats_over_multiple_rounds() -> void:
    music_manager.load_tracks(TRACKS_DIRECTORY)
    music_manager._pending_tracks.clear()
    music_manager._last_track = null
    var previous: AudioStream = null
    for i in music_manager.tracks.size() * 3 + 1:
        var next: AudioStream = music_manager._next_track()
        assert_that(next).is_not_null()
        if previous != null:
            assert_that(next != previous).is_true()
        previous = next


func test_skip_changes_track() -> void:
    music_manager.player.stream = null
    music_manager.skip()
    assert_that(music_manager.player.stream).is_not_null()
    var first: AudioStream = music_manager.player.stream
    music_manager.skip()
    assert_that(music_manager.player.stream).is_not_null()
    assert_that(music_manager.player.stream != first).is_true()


func test_stop_stops_playback() -> void:
    music_manager.play()
    music_manager.stop()
    assert_that(music_manager.player.playing).is_false()


func test_target_volume_is_clamped() -> void:
    music_manager.set_target_volume(50.0)
    assert_that(music_manager.target_volume).is_equal(0.0)
    music_manager.set_target_volume(-100.0)
    assert_that(music_manager.target_volume).is_equal(-80.0)


func test_play_without_tracks_is_safe() -> void:
    var empty_manager: Node = load(MUSIC_MANAGER_PATH).new()
    add_child(empty_manager)
    empty_manager._tracks_loaded = true
    empty_manager.tracks.clear()
    empty_manager._pending_tracks.clear()
    empty_manager.play()
    assert_that(empty_manager.player.stream).is_null()
    empty_manager.queue_free()
