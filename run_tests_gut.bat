@echo off

@REM Initial run command
"F:\programs\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64.exe" ^
 -d -s --headless --path "%CD%" addons/gut/gut_cmdln.gd -gdir=res://test -gexit

@REM Run command with -gpo option
@REM "F:\programs\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64.exe" ^
@REM     -d -s --path "%CD%" addons/gut/gut_cmdln.gd -gdir=res://test -gexit -gpo



@REM "F:\programs\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64.exe" ^
    @REM -d --path "%CD%" -s addons/gut/gut_cmdln.gd -gtest=res://test/test_item_factory.gd -gexit

@REM "F:\programs\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64.exe" ^
@REM --path "%CD%" -s addons/gut/gut_cmdln.gd -gdir=res://test ^
@REM -gexit



@REM pause
exit /b %ERRORLEVEL%