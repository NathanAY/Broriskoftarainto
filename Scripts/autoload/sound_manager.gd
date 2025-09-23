#class_name SoundManager2d
extends Node

enum {SOUND, VOLUME, PITCH_RAND, POSITION}

const MAX_SOUNDS = 32

var num_players = 12
var bus = "Sound"

var players_available: Array[AudioStreamPlayer]  = []
var players_available2d: Array[AudioStreamPlayer2D]  = []
var sounds_to_play: Array = []
var sounds_to_play2d: Array = []

func _ready() -> void :
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
        players_available[0].pitch_scale = 1.0 + randi_range(-sound_to_play[PITCH_RAND], sound_to_play[PITCH_RAND])#
        players_available[0].play()
        players_available.pop_front()

func _playSound2d() -> void :
    if not sounds_to_play2d.is_empty() and not players_available.is_empty():
        var sound_to_play = sounds_to_play2d.pop_front()
        players_available2d[0].global_position = sound_to_play[POSITION]
        players_available2d[0].stream = sound_to_play[SOUND]
        players_available2d[0].volume_db = sound_to_play[VOLUME]
        players_available2d[0].pitch_scale = 1.0 + randi_range(-sound_to_play[PITCH_RAND], sound_to_play[PITCH_RAND])
        players_available2d[0].play()
        players_available2d.pop_front()

func play(sound: Resource, volume_mod: float = 0.0, pitch_rand: float = 0.0, always_play: bool = false) -> void :
    if (not players_available.is_empty() and sounds_to_play.size() < MAX_SOUNDS) or always_play:
        sounds_to_play.append([sound, volume_mod, pitch_rand])

func play2d(sound: Resource, pos: Vector2, volume_mod: float = 0.0, pitch_rand: float = 0.0, always_play: bool = false) -> void :
    if (not players_available2d.is_empty() and sounds_to_play2d.size() < MAX_SOUNDS) or always_play:
        sounds_to_play2d.append([sound, volume_mod, pitch_rand, pos])
