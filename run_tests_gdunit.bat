@echo off
setlocal

set "GODOT_BIN=F:\programs\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64.exe"
set "TEST_TARGET=res://test"
set "TIMEOUT_SECONDS=60"
set "LOG_FILE=.gdunit_timeout.log"

if not "%~1"=="" set "TEST_TARGET=res://test/%~1"

echo ========================================
echo GdUnit4 Test Runner
echo Target: %TEST_TARGET%
echo ========================================

echo [1/2] Checking test execution time...

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$cmd = '""%GODOT_BIN%"" --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a ""%TEST_TARGET%"" > ""%LOG_FILE%"" 2>&1';" ^
  "$p = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', $cmd -NoNewWindow -PassThru;" ^
  "if (-not $p.WaitForExit(%TIMEOUT_SECONDS% * 1000)) {" ^
  "    Write-Host ''; Write-Host 'TEST TIMEOUT - process exceeded %TIMEOUT_SECONDS% seconds!' -ForegroundColor Red;" ^
  "    taskkill /PID $p.Id /T /F | Out-Null;" ^
  "    exit 124;" ^
  "}" ^
  "exit $p.ExitCode"

set "FIRST_EXIT_CODE=%ERRORLEVEL%"

if %FIRST_EXIT_CODE% EQU 124 (
    echo.
    echo ========================================
    echo TESTS TIMED OUT
    echo ========================================
    echo.
    echo The test process was killed after %TIMEOUT_SECONDS% seconds.
    echo Full output was saved to:
    echo %LOG_FILE%
    echo.
    exit /b 124
)

echo First run completed in less than %TIMEOUT_SECONDS% seconds.

if exist "%LOG_FILE%" del "%LOG_FILE%"

echo.
echo [2/2] Running tests with output...

"%GODOT_BIN%" --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a "%TEST_TARGET%"

set "TEST_EXIT_CODE=%ERRORLEVEL%"

echo.
echo ========================================

if %TEST_EXIT_CODE% EQU 0 (
    echo ALL TESTS PASSED
) else (
    if %TEST_EXIT_CODE% EQU 101 (
        echo ALL TESTS PASSED - with warnings: orphan nodes detected
    ) else (
        echo TESTS FAILED - Exit code: %TEST_EXIT_CODE%
    )
)

echo ========================================

exit /b %TEST_EXIT_CODE%