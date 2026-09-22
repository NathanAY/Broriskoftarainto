extends Node

const DEFAULT_TRACKS_DIRECTORY := "res://src/Assets/music"
const MUSIC_SCENE_NAMES := ["Main.tscn", "Game.tscn"]
const FADE_IN_VOLUME_DB := -20.0
const DEFAULT_VOLUME_DB := 0.0
const FADE_DURATION := 1.5
const MUTE_VOLUME_DB := -80.0

var bus := "Music"
var target_volume := DEFAULT_VOLUME_DB

var tracks: Array[AudioStream] = []
var player: AudioStreamPlayer
var _tween: Tween
var _pending_tracks: Array[AudioStream] = []
var _last_track: AudioStream
var _music_started := false
var _tracks_loaded := false


func _ready() -> void:
    player = AudioStreamPlayer.new()
    add_child(player)
    player.bus = bus
    player.finished.connect(_on_track_finished)
    get_tree().node_added.connect(_on_node_added)


func _on_node_added(_node: Node) -> void:
    if _music_started:
        return
    _try_start_music.call_deferred()


func _try_start_music() -> void:
    if _music_started:
        return
    var scene := get_tree().current_scene
    if scene != null and scene.get_scene_file_path().get_file() in MUSIC_SCENE_NAMES:
        _music_started = true
        play()


func load_tracks(directory: String = DEFAULT_TRACKS_DIRECTORY) -> int:
    tracks.clear()
    _pending_tracks.clear()
    _last_track = null
    _tracks_loaded = true

    var dir := DirAccess.open(directory)
    if dir == null:
        push_error("MusicManager: could not open music directory: %s" % directory)
        return 0

    dir.list_dir_begin()
    var file_name := dir.get_next()
    while file_name != "":
        if not dir.current_is_dir() and file_name.get_extension().to_lower() in ["mp3", "ogg", "wav"]:
            var stream := load(directory.path_join(file_name)) as AudioStream
            if stream != null:
                tracks.append(stream)
        file_name = dir.get_next()
    dir.list_dir_end()

    return tracks.size()


func play() -> void:
    if not _tracks_loaded:
        load_tracks(DEFAULT_TRACKS_DIRECTORY)
    if tracks.is_empty():
        player.stop()
        player.stream = null
        return
    var track := _next_track()
    if track == null:
        return
    player.stream = track
    player.volume_db = FADE_IN_VOLUME_DB
    player.play()
    fade_to(target_volume, FADE_DURATION)


func stop() -> void:
    if _tween != null:
        _tween.kill()
    player.stop()


func fade_out(duration := 1.0) -> void:
    if _tween != null:
        _tween.kill()
    _tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    _tween.tween_property(player, "volume_db", MUTE_VOLUME_DB, duration)
    _tween.tween_callback(player.stop)


func skip() -> void:
    if player.playing:
        player.stop()
    play()


func set_target_volume(volume_db: float, duration := FADE_DURATION) -> void:
    target_volume = clampf(volume_db, MUTE_VOLUME_DB, 0.0)
    fade_to(target_volume, duration)


func fade_to(volume_db: float, duration: float) -> void:
    if _tween != null:
        _tween.kill()
    _tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    _tween.tween_property(player, "volume_db", volume_db, duration)


func _on_track_finished() -> void:
    play()


func _next_track() -> AudioStream:
    if _pending_tracks.is_empty():
        _pending_tracks = tracks.duplicate()
        _pending_tracks.shuffle()
        if _pending_tracks.size() > 1 and _pending_tracks[0] == _last_track:
            _pending_tracks.push_back(_pending_tracks.pop_front())
    if _pending_tracks.is_empty():
        return null
    _last_track = _pending_tracks.pop_front() as AudioStream
    return _last_track