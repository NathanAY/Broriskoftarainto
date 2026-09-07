@echo off
setlocal

set "GODOT_BIN=F:\programs\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64.exe"
set "TEST_TARGET=res://test"

if not "%~1"=="" set "TEST_TARGET=res://test/%~1"

"%GODOT_BIN%" --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a "%TEST_TARGET%"

set "TEST_EXIT_CODE=%ERRORLEVEL%"

if %TEST_EXIT_CODE% EQU 0 (
    echo.
    echo ALL TESTS PASSED
) else (
    echo.
    echo TESTS FAILED - Exit code: %TEST_EXIT_CODE%
)

exit /b %TEST_EXIT_CODE%