@echo off
setlocal EnableDelayedExpansion

REM GdUnit4 wrapper that resolves a *partial* test target to one or more suites.
REM Accepted argument forms (all equivalent for the same file):
REM   .\run_tests_gdunit_custom.bat Systems/Items/test_pierce_stat.gd
REM   .\run_tests_gdunit_custom.bat test_pierce_stat.gd
REM   .\run_tests_gdunit_custom.bat test_pierce_stat
REM   .\run_tests_gdunit_custom.bat pierce_stat
REM An optional 2nd argument overrides the run timeout in seconds
REM (default: 10s for a single suite, 180s for several suites / all of them).
REM Resolution rules (case-insensitive, forward/backslash agnostic, .gd optional):
REM   1. no argument            -> every suite under res://test
REM   2. existing path          -> that file or directory (res://test/<arg>)
REM   3. fuzzy match            -> every res://test/test_*.gd whose path
REM                                  (without extension) contains <arg>
REM One Godot execution is logged to LOG_FILE under a timeout guard; afterwards
REM only a short tail / failure index goes to console.
REM NOTE: the Godot exit code is parsed from the log's "Exit code: N" line, NOT from
REM the process handle - Start-Process ExitCode is unreliable here (reads back empty
REM on this machine's PowerShell 5.1), so the run step only distinguishes OK vs 124.
REM To see other arguments \addons\gdUnit4\src\core\runners\GdUnitTestCIRunner.gd  

set "GODOT_BIN=F:\programs\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64.exe"
set "TEST_ROOT=res://test"
set "TEST_ROOT_FS=test"
set "TIMEOUT_SINGLE=10"
set "TIMEOUT_MULTI=180"
set "TIMEOUT_SECONDS=%TIMEOUT_SINGLE%"
set "LOG_FILE=.gdunit.log"
set "ARGS_FILE=.gdunit_args.txt"

REM NOTE: the target resolution below uses goto labels instead of an if/else block,
REM because cmd.exe loses the exit code of "exit /b" inside a parenthesised block.

if "%~1"=="" goto no_arg

if exist "%ARGS_FILE%" del /q "%ARGS_FILE%"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
      "$rootFs = '%TEST_ROOT_FS%'; $arg = '%~1'; $out = '%ARGS_FILE%';" ^
      "$targets = @();" ^
      "if (Test-Path $rootFs) {" ^
      "  $rootAbs = (Resolve-Path $rootFs).Path;" ^
      "  $p = ($arg -replace '\\','/') -replace '\.gd$','';" ^
      "  $direct = Join-Path $rootFs $p;" ^
      "  if (Test-Path -LiteralPath $direct) {" ^
      "    $targets = @(('res://test/' + $p));" ^
      "  } else {" ^
      "    $pEsc = $p.Replace('`','``').Replace('*','`*').Replace('?','`?').Replace('[','`[').Replace(']','`]');" ^
      "    foreach ($f in (Get-ChildItem -LiteralPath $rootFs -Recurse -File -Filter 'test_*.gd' | Sort-Object FullName)) {" ^
      "      $rel = $f.FullName.Substring($rootAbs.Length + 1).Replace('\','/');" ^
      "      $noExt = $rel.Substring(0, $rel.Length - 3);" ^
      "      if ($noExt -like ('*' + $pEsc + '*')) { $targets += ('res://test/' + $rel) }" ^
      "    }" ^
      "  }" ^
      "}" ^
      "if ($targets.Count -eq 0) { Write-Host ('No test suite matched: ' + $arg) -ForegroundColor Red; exit 1 }" ^
      "Write-Host ('Matched ' + $targets.Count + ' test target(s) for: ' + $arg);" ^
      "foreach ($t in $targets) { Write-Host ('  ' + $t) };" ^
      "$lines = @(); foreach ($t in $targets) { $lines += ('-a ""' + $t + '""') };" ^
      "Set-Content -LiteralPath $out -Value $lines -Encoding ASCII"
if errorlevel 1 goto no_match

set "TEST_TARGET=%~1 ^(resolved to the suites listed above^)"
set "GODOT_TEST_ARGS="
for /f "usebackq delims=" %%L in ("%ARGS_FILE%") do set "GODOT_TEST_ARGS=!GODOT_TEST_ARGS! %%L"
for /f %%N in ('type "%ARGS_FILE%" ^| find /c /v ""') do set "TARGET_COUNT=%%N"
del /q "%ARGS_FILE%"
goto timeout_pick

:no_arg
set "TEST_TARGET=%TEST_ROOT% ^(all suites^)"
set "GODOT_TEST_ARGS=-a ""%TEST_ROOT%"""
set "TARGET_COUNT=0"

:timeout_pick
REM an optional 2nd argument overrides the timeout in seconds
if not "%~2"=="" set "TIMEOUT_SECONDS=%~2"
if not "%~2"=="" goto ready
if "%TARGET_COUNT%"=="1" set "TIMEOUT_SECONDS=%TIMEOUT_SINGLE%"
if not "%TARGET_COUNT%"=="1" set "TIMEOUT_SECONDS=%TIMEOUT_MULTI%"
goto ready

:no_match
echo.
echo No test suite matched "%~1".
echo Use a full path, a file name, or any part of it ^(e.g. pierce_stat^).
echo.
exit /b 2

:ready
echo ========================================
echo Test Runner
echo Target: %TEST_TARGET%
echo Timeout: %TIMEOUT_SECONDS%s
echo Log: %LOG_FILE%
echo ========================================

echo Running tests, logging to file...

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$cmd = '""%GODOT_BIN%"" --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd !GODOT_TEST_ARGS! > ""%LOG_FILE%"" 2>&1';" ^
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
