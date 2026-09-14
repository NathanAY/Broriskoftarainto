@echo off

@REM Initial run command
@REM See addons\gut\cli\gut_cli.gd:113 for all params that can be added
"F:\programs\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64.exe" ^
 -d -s --headless --path "%CD%" addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs=true -gexit

@REM Run command for one specific test only
@REM & "F:\programs\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64.exe" ^
@REM -d -s --headless --path "." addons/gut/gut_cmdln.gd ^
@REM -gtest=res://test/Systems/Items/test_item_factory_gut.gd -gexit

@REM pause
exit /b %ERRORLEVEL%