@echo off
setlocal

REM Single-run GdUnit4 wrapper: one Godot execution is logged to LOG_FILE under a
REM timeout guard; afterwards only a short tail / failure index goes to console.
REM NOTE: the Godot exit code is parsed from the log's "Exit code: N" line, NOT from
REM the process handle - Start-Process ExitCode is unreliable here (reads back empty
REM on this machine's PowerShell 5.1), so the run step only distinguishes OK vs 124.
REM Runs Godot in --headless mode (no game window) with --ignoreHeadlessMode so GdUnit4
REM allows it. Tests that rely on real window InputEvents will not work headless.
REM It's very unstable, tests relates to frame/game simulation will not work
REM To see other arguments \addons\gdUnit4\src\core\runners\GdUnitTestCIRunner.gd  

set "GODOT_BIN=F:\programs\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64.exe"
set "TEST_TARGET=res://test"
set "TIMEOUT_SECONDS=10"
set "LOG_FILE=.gdunit.log"

if not "%~1"=="" set "TEST_TARGET=res://test/%~1"

echo ========================================
echo Test Runner
echo Target: %TEST_TARGET%
echo Timeout: %TIMEOUT_SECONDS%s
echo Log: %LOG_FILE%
echo ========================================

echo Running tests, logging to file...

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$cmd = '""%GODOT_BIN%"" --headless --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a ""%TEST_TARGET%"" > ""%LOG_FILE%"" 2>&1';" ^
  "$p = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', $cmd -NoNewWindow -PassThru;" ^
  "if (-not $p.WaitForExit(%TIMEOUT_SECONDS% * 1000)) {" ^
  "    Write-Host ''; Write-Host 'TEST TIMEOUT - process exceeded %TIMEOUT_SECONDS% seconds!' -ForegroundColor Red;" ^
  "    taskkill /PID $p.Id /T /F | Out-Null;" ^
  "    exit 124;" ^
  "}" ^
  "exit 0"

set "TEST_EXIT_CODE=%ERRORLEVEL%"

if %TEST_EXIT_CODE% EQU 124 (
    echo.
    echo ========================================
    echo TESTS TIMED OUT
    echo ========================================
    echo.
    echo The test process was killed after %TIMEOUT_SECONDS% seconds.
    echo --- Last 30 lines of %LOG_FILE% ---
    powershell -NoProfile -ExecutionPolicy Bypass -Command "if (Test-Path '%LOG_FILE%') { Get-Content '%LOG_FILE%' | Select-Object -Last 30 | ForEach-Object { Write-Host $_ } } else { Write-Host 'No log captured.'; }"
    echo.
    echo Full output was saved to:
    echo %LOG_FILE%
    echo.
    exit /b 124
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$log = '%LOG_FILE%';" ^
  "if (-not (Test-Path $log)) { Write-Host ('Log file not found: ' + $log); exit 1; }" ^
  "$lines = @(Get-Content $log);" ^
  "$total = $lines.Count;" ^
  "$esc = [char]27;" ^
  "function StripAnsi([string]$s) { return ($s -replace ($esc + '\[[0-9;]*[mG]'), ''); }" ^
  "$code = 1; $found = $false;" ^
  "for ($i = 0; $i -lt $total; $i++) { $c = StripAnsi($lines[$i]); if ($c -match 'Exit code:\s*(\d+)') { $code = [int]$Matches[1]; $found = $true; } }" ^
  "if (-not $found) { Write-Host 'WARNING: no Exit code marker in log; treating as failure.'; }" ^
  "if ($code -eq 0) {" ^
  "    Write-Host ''; Write-Host '========================================';" ^
  "    Write-Host 'ALL TESTS PASSED';" ^
  "    Write-Host '========================================';" ^
  "    Write-Host ('--- Last 15 lines of ' + $log + ' ---');" ^
  "    $lines | Select-Object -Last 15 | ForEach-Object { Write-Host $_ };" ^
  "    exit 0;" ^
  "}" ^
  "if ($code -eq 101) {" ^
  "    Write-Host ''; Write-Host '========================================';" ^
  "    Write-Host 'ALL TESTS PASSED - with warnings: orphan nodes detected';" ^
  "    Write-Host '========================================';" ^
  "    Write-Host ('--- Last 15 lines of ' + $log + ' ---');" ^
  "    $lines | Select-Object -Last 15 | ForEach-Object { Write-Host $_ };" ^
  "    Write-Host '--- Orphan warnings (max 10) ---';" ^
  "    $o = @(); for ($i = 0; $i -lt $total; $i++) { if ((StripAnsi($lines[$i])) -match 'orphan') { $o += ('LOG:' + ($i + 1) + ': ' + (StripAnsi($lines[$i])).Trim()); } }" ^
  "    $o | Select-Object -Last 10 | ForEach-Object { Write-Host $_ };" ^
  "    exit 101;" ^
  "}" ^
  "Write-Host ''; Write-Host '========================================';" ^
  "Write-Host ('TESTS FAILED - Exit code: ' + $code);" ^
  "Write-Host '========================================';" ^
  "$pat = 'FAILED|ERROR|Expecting:|but was|Abnormal exit|Script errors|Headless mode|Test Session Terminated|No test cases found';" ^
  "$hits = @(); $hitLines = @();" ^
  "for ($i = 0; $i -lt $total; $i++) {" ^
  "    $c = StripAnsi($lines[$i]).Trim();" ^
  "    if ($c -match $pat) {" ^
  "        $t = $c; if ($t.Length -gt 200) { $t = $t.Substring(0, 200); }" ^
  "        $hits += ('LOG:' + ($i + 1) + ': ' + $t);" ^
  "        $hitLines += ($i + 1);" ^
  "        if ($hits.Count -ge 30) { break; }" ^
  "    }" ^
  "}" ^
  "if ($hits.Count -eq 0) { Write-Host 'No FAILED/ERROR markers found; showing tail instead:'; }" ^
  "else { Write-Host '--- Failure index (LOG:line) ---'; $hits | ForEach-Object { Write-Host $_ }; }" ^
  "Write-Host '--- Summary ---';" ^
  "$sum = @(); for ($i = 0; $i -lt $total; $i++) { $c = StripAnsi($lines[$i]); if ($c -match 'Overall Summary:|Statistics:|Executed test suites:|Executed test cases|Total execution time:|Exit code:') { $sum += ('LOG:' + ($i + 1) + ': ' + $c.Trim()); } }" ^
  "$sum | Select-Object -Last 10 | ForEach-Object { Write-Host $_ };" ^
  "if ($hits.Count -eq 0) { $lines | Select-Object -Last 30 | ForEach-Object { Write-Host $_ }; }" ^
  "$n = 0; $lastLn = -1000; foreach ($ln in $hitLines) { if ($n -ge 3) { break; } if (($ln - $lastLn) -lt 25) { continue; } $lastLn = $ln; $n++; $s = $ln - 20; if ($s -lt 1) { $s = 1; } $e = $ln + 5; if ($e -gt $total) { $e = $total; } $skip = $s - 1; $first = $e - $s + 1; Write-Host ('Investigate failure ' + $n + ' (LOG line ' + $ln + '): Get-Content ' + $log + ' | Select-Object -Skip ' + $skip + ' -First ' + $first + '   # lines ' + $s + '..' + $e); }" ^
  "Write-Host ('Full log: ' + $log + ' (' + $total + ' lines)');" ^
  "exit $code"

set "DISPLAY_EXIT_CODE=%ERRORLEVEL%"

exit /b %DISPLAY_EXIT_CODE%
