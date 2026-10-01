# Test Runner Single-Run Improvement Plan

## Goal
Replace the 2-pass `run_tests_gdunit*.bat` flow (silent timeout-check run + full live run)
with a single Godot run that always logs to file and prints only a short,
AI-context-friendly tail to console. Fixes: (1) 2x execution time, (2) huge
console output consuming AI context. Timeout safety is preserved.

## Current state (facts)
- `run_tests_gdunit.bat` (TIMEOUT 20s) and `run_tests_gdunit_custom.bat` (TIMEOUT 10s)
  are 95% duplicated, 69 lines each.
- Pass 1: Godot run redirected to `.gdunit_timeout.log` under a PowerShell
  `WaitForExit(TIMEOUT*1000)` guard; on timeout `taskkill /PID /T /F`, exit 124.
- On pass-1 success the log is **deleted** and pass 2 re-runs everything live.
- GdUnit exit codes (from `addons/gdUnit4/src/core/runners/`):
  `0` = success, `100` = errors/failures, `101` = warning (orphans), `124` = wrapper timeout (not GdUnit).
- GdUnit console markers useful for grep: `FAILED`, `ERROR`, `Expecting:`, `but was`,
  `line <N>:`, `at 'func' in res://...:<line>`, `Statistics:`, `Overall Summary:`,
  `Executed test suites:`, `Executed test cases :`, `Exit code:`, `orphan nodes`, `WARNING:`.
- Note: GdUnit console writer emits ANSI/CSI escapes; plain-substring grep still
  matches, but parsing should strip `\x1b\[[0-9;]*[mG]` first.

## Design (agreed)
- **Execution model:** single run + log tail (no conditional second run).
- **Log policy:** keep overwriting `.gdunit_timeout.log` every run (no per-target names, no history).
- **Timeouts:** keep `10s` custom / `20s` full, `taskkill` + exit `124`, log preserved on timeout.
- **Script structure:** keep two `.bat` files separate (no unification); apply the same
  template to both, differing only in `TIMEOUT_SECONDS`.
- **Verbosity:** do NOT change GdUnit flags; filter only at display time.
- **Green console:** raw last-15-lines tail only (no parsed counts).
- **Red console:** ~80 lines max: failure index with log line numbers + hint to open
  the log at specific lines (user asked: "see only previous 20 lines of that number").

## New flow (both .bats)
1. Print header (`Target`, `Timeout`, `Log`).
2. Single PowerShell-guarded run:
   `Godot --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a "<TARGET>" > LOG 2>&1`
   under `WaitForExit`. The run step only distinguishes OK (exit 0) vs timeout (124).
   The true GdUnit verdict is parsed from the log (see step 4) because
   `Start-Process -PassThru` `.ExitCode` reads back empty on this machine's
   PowerShell 5.1 (verified: even `cmd /c exit 42` reports empty ExitCode).
3. On timeout (exit 124): print `TESTS TIMED OUT`, print last ~30 lines of LOG,
   print `Full output: .gdunit_timeout.log`, exit 124. Keep LOG.
4. On completion: parse the verdict from the log — last `Exit code: N` match on
   ANSI-stripped lines (GdUnit always prints it via `report_exit_code()`).
   Missing marker = abnormal completion → treat as failure, exit 1.
   - `0` → print `ALL TESTS PASSED`, print raw last 15 lines of LOG, exit 0.
   - `101` → print `ALL TESTS PASSED - with warnings: orphan nodes detected`,
     print last 15 lines + orphan lines (`orphan nodes` grep, max 10), exit 101.
   - else (`100`, `103/104/105`, other) → red path, exit with original code.
5. Red path (PowerShell, capped at ~80 console lines):
   a. Print `TESTS FAILED - Exit code: N`.
   b. Grep LOG (ANSI-stripped) for `FAILED|ERROR|Expecting:|but was|Abnormal exit|Script errors|Headless mode|Test Session Terminated`
      with 1-based log line numbers; print at most ~30 index lines as
      `LOG:<lineno>: <trimmed to 200 chars>`.
   c. Print `Overall Summary:` / `Statistics:` / `Executed test ...` / `Exit code:` lines if present (max ~10).
   d. For the first max-3 failures, print hint:
      `Read LOG lines <N-20>..<N+5>, e.g. PowerShell: Get-Content .gdunit_timeout.log | Select-Object -Skip <N-21> -First 26`
      Do NOT dump full context inline (context budget).
   e. Print `Full log: .gdunit_timeout.log (<total> lines)`, exit with original code.
6. Never delete LOG on success (keep for inspection); overwrite next run.

## Changes per file
- `run_tests_gdunit.bat`: replace `[1/2]+[2/2]` blocks with flow above, `TIMEOUT_SECONDS=20`.
- `run_tests_gdunit_custom.bat`: same template, `TIMEOUT_SECONDS=10`, keep `%~1` target override.
- Both stay batch + inline PowerShell (no PS1 rewrite); shared logic duplicated
  intentionally per user decision.

## Verification (per AGENTS.md)
1. `.\run_tests_gdunit_custom.bat test_stat_creation_stat.gd` → expect green + 15-line tail, exit 0.
2. Temporarily break a test (or run a known-failing target) → expect red index with
   `LOG:<lineno>` entries + 20-line window hints, exit 100.
3. Timeout check: set `TIMEOUT_SECONDS=1` temporarily → expect exit 124 + preserved log.
4. `.\run_tests_gdunit.bat` (full suite) → green/red path within single-run time
   (~half of previous wall time).
5. Update `AGENTS.md` testing section if the command UX changes (log-tail note).

## Risks / notes
- ANSI escapes in log: strip before grep or matching still works on substrings.
- `findstr` in batch is weak → do all parsing in the inline PowerShell step.
- Console cap (~80 red / 15 green) is a convention; PowerShell must enforce with
  `Select-Object -First`.
- Future option (out of scope): unify the two .bats via shared `_gdunit_run.bat`.
