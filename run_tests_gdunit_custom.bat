@echo off

@REM GDUNIT4 example - run all tests or a specific test file
@REM Usage:
@REM   run_tests_gdunit_custom.bat                     runs all tests in res://test
@REM   run_tests_gdunit_custom.bat test_item_factory_gdunit4.gd   runs only that test file

set GODOT_BIN=F:\programs\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64.exe

set TEST_TARGET=res://test
if not "%~1"=="" set TEST_TARGET=res://test\%~1

@REM call addons\gdUnit4\runtest.cmd -a %TEST_TARGET% --verbose
call addons\gdUnit4\runtest.cmd -a %TEST_TARGET%

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