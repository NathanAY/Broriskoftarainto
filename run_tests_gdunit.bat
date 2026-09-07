@echo off

@REM GDUNIT4 example
set GODOT_BIN=F:\programs\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64.exe 

@REM call addons\gdUnit4\runtest.cmd -a res://test --verbose
call addons\gdUnit4\runtest.cmd -a res://test

set TEST_EXIT_CODE=%ERRORLEVEL%

if %TEST_EXIT_CODE% EQU 0 (
    echo.
    echo ALL TESTS PASSED
) else (
    echo.
    echo TESTS FAILED - Exit code: %TEST_EXIT_CODE%
)

@REM pause
exit /b %ERRORLEVEL%