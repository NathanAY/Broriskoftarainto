#class_name SoundManager
extends Node

enum {SOUND, VOLUME, PITCH_RAND, POSITION}

const MAX_SOUNDS = 32

## Lowest pitch_scale the engine accepts; below this the player refuses to play.
const MIN_PITCH_SCALE := 0.01

var num_players = 12
var bus = "SFX"

var players_available: Array[AudioStreamPlayer]  = []
var players_available2d: Array[AudioStreamPlayer2D]  = []
var sounds_to_play: Array = []
var sounds_to_play2d: Array = []

func _ready() -> void :
    # Keep draining the queue while the tree is paused. PauseMenu sets
    # PROCESS_MODE_ALWAYS, so its buttons stay interactive during a pause and
    # keep queuing sounds; without this the autoload stops in _process and the
    # whole queue stalls until the game resumes, then fires all at once.
    process_mode = Node.PROCESS_MODE_ALWAYS

    for i in num_players:
        var p = AudioStreamPlayer.new()
        add_child(p)
        players_available.append(p)
        p.finished.connect(func():
            players_available.append(p)
        )
        p.bus = bus

        var p2d =  AudioStreamPlayer2D.new()
        add_child(p2d)
        players_available2d.append(p2d)
        p2d.finished.connect(func():
            players_available2d.append(p2d)
        )
        p2d.bus = bus

func _process(_delta) -> void :
    _playSound()
    _playSound2d()

func _playSound() -> void :
    if not sounds_to_play.is_empty() and not players_available.is_empty():
        var sound_to_play = sounds_to_play.pop_front()
        players_available[0].stream = sound_to_play[SOUND]
        players_available[0].volume_db = sound_to_play[VOLUME]
        players_available[0].pitch_scale = _pick_pitch(sound_to_play[PITCH_RAND])
        players_available[0].play()
        players_available.pop_front()

func _playSound2d() -> void :
    if not sounds_to_play2d.is_empty() and not players_available2d.is_empty():
        var sound_to_play = sounds_to_play2d.pop_front()
        players_available2d[0].global_position = sound_to_play[POSITION]
        players_available2d[0].stream = sound_to_play[SOUND]
        players_available2d[0].volume_db = sound_to_play[VOLUME]
        players_available2d[0].pitch_scale = _pick_pitch(sound_to_play[PITCH_RAND])
        players_available2d[0].play()
        players_available2d.pop_front()

## Returns a pitch_scale randomly offset from 1.0 by +/- `pitch_rand`.
## `AudioStreamPlayer.pitch_scale` must stay strictly positive, so the result is
## clamped: without this, a `pitch_rand` of 1.0 or more can yield a zero or
## negative scale and the player errors out instead of playing the sound.
func _pick_pitch(pitch_rand: float) -> float :
    return maxf(MIN_PITCH_SCALE, 1.0 + randf_range(-pitch_rand, pitch_rand))

func play(sound: Resource, volume_mod: float = 0.0, pitch_rand: float = 0.0, always_play: bool = false) -> void :
    if (not players_available.is_empty() and sounds_to_play.size() < MAX_SOUNDS) or always_play:
        sounds_to_play.append([sound, volume_mod, pitch_rand])

func play2d(sound: Resource, pos: Vector2, volume_mod: float = 0.0, pitch_rand: float = 0.0, always_play: bool = false) -> void :
    if (not players_available2d.is_empty() and sounds_to_play2d.size() < MAX_SOUNDS) or always_play:
        sounds_to_play2d.append([sound, volume_mod, pitch_rand, pos])
