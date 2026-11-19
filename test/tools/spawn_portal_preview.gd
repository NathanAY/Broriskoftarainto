# The enemy teleport-in effect on a dark backdrop. Pass frames to see it mid-play:
# .\run_scene_shot.bat res://test/tools/spawn_portal_preview.tscn res://portal.png 30
extends Node2D


func _ready() -> void:
    var backdrop := ColorRect.new()
    backdrop.color = Color(0.12, 0.12, 0.15)
    backdrop.size = Vector2(400, 300)
    add_child(backdrop)
    SpawnPortal.play(self, Vector2(200, 150))
