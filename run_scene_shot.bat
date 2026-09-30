@echo off
@REM Renders a scene to a PNG and quits, for eyeballing a UI change.
@REM
@REM   run_scene_shot.bat <res://path/to/Scene.tscn> [res://out.png]
@REM
@REM Example (the character menu, which needs a character set up for it):
@REM   run_scene_shot.bat res://test/tools/character_ui_preview.tscn
@REM
@REM Defaults to res://scene_shot.png. Runs windowed, because a headless
@REM viewport has no framebuffer to read the screenshot back from, so the game
@REM window will flash up for a moment. The target scene must render on its own,
@REM with no gameplay set up around it.

set "SCENE=%~1"
if "%SCENE%"=="" (
  echo usage: %~nx0 ^<res://Scene.tscn^> [res://out.png]
  exit /b 1
)

set "OUT=%~2"
if "%OUT%"=="" set "OUT=res://scene_shot.png"

"F:\programs\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64.exe" ^
  --path "%CD%" test/tools/scene_shot.tscn -- %SCENE% %OUT%

@REM Godot imports the new PNG on the way out, which is what keeps the output
@REM out of the next `git status`.
exit /b %ERRORLEVEL%
