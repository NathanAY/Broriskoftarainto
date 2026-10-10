# Main rules if changing project
- After any feature implementation: 1. Create a test 2. Read failures 3. Fix the test/code 4. Run test again
- Task -> Read relevant code -> Read testing rules/docs -> Write test -> RUN TEST -> Read error -> Fix -> RUN TEST again -> Done
- If you have questions or options for some implementation than ask about it.

# Core systems

## Player & combat
- `src/Scripts/character.gd`: player entity holds `WeaponHolder` and `ItemHolder` children.
- `src/Systems/damage/health.gd`: health/stats subsystem (uses modifiers and conditions).

## Items & modifiers
- `src/Systems/Items/item_pickup.gd`: item pickup logic.
- `src/Systems/Items/item_factory.gd`: generates item Node instances from `.tres` resources.
- `src/Systems/Items/item_holder.gd`: holds items; attaches modifier children to stats node.
- Effects live in `src/Systems/Items/modifiers/` (lowercase `modifiers`, lowercase everything else in that path). They are attached via `ItemHolder`, subscribe to events (`on_attack`, `on_hit`, `on_stat_changes`), and manipulate the holder's `Stats`/`Health` nodes.

# Testing

## Setup and run test
- Example how to run GDUnit4 all tests: `.\run_tests_gdunit.bat`
- Example how to run GDUnit4 specific tests: `.\run_tests_gdunit_custom.bat test_item_creation_stat.gd`

### `run_tests_gdunit_custom.bat` uses fuzzy test lookup
The argument is matched case-insensitively against test suite paths under `test/`; `.gd`, folders and slashes/backslashes are optional, so all of these run the same suite:
- `.\run_tests_gdunit_custom.bat Systems/Items/test_pierce_stat.gd`
- `.\run_tests_gdunit_custom.bat pierce_stat`
- `.\run_tests_gdunit_custom.bat Systems\Items` (directory -> all suites inside)

Other behavior:
- Partial words match several suites at once (e.g. `modifier` -> 7 suites, all run).
- Only `test_*.gd` files are fuzzy-matched, so shared helper scripts are not run as suites.

## Running tests from PowerShell
Call the batch file directly — PowerShell runs `.bat` files through `cmd.exe` on its own, and no wrapper is needed:
- `.\run_tests_gdunit_custom.bat pistol`
- `$LASTEXITCODE` carries the runner's exit code (0 pass, 101 pass-with-orphan-warnings, 124 timeout, 125 stall, or the Godot exit code).
- Run it from the repository root (`F:\programs\Godot projects\BRT\Broriskoftarainto`). `--path .`, `.gdunit.log` and the `test\` target lookup are all resolved against the current directory, so from anywhere else the runner finds no suites and writes its log to the wrong place.

## Runner exit codes and the stall watchdog
All three GdUnit4 wrappers (`run_tests_gdunit.bat`, `run_tests_gdunit_custom.bat`, `run_tests_gdunit_custom_headless.bat`) share the same guard:
- **124** = the run hit `TIMEOUT_BASE` + `TIMEOUT_PER_EXTRA` per extra suite.
- **125** = **stall**, and this fires much earlier. A script error inside a test makes Godot drop into its `debug>` REPL, and because stdin is redirected from `nul` the break aborts and then *re-breaks forever*, appending the same block of lines to `.gdunit.log` at full speed until the wall-clock timeout. So while the process is alive the wrapper polls the log every 500 ms and kills the tree as soon as the tail is one block of lines repeated three times in a row — seen on two consecutive polls with the file growing in between, so a one-off coincidence cannot trip it. Expect 125 within a few seconds of the hang.
- On 125 the log tail is the repeating block; the **first** `Debugger Break, Reason:` line is the real error, and the `*Frame 0 - res://...` line under it is the test line to fix. Nearly always it is a read on a node that was freed mid-test (`'previously freed'`), which `WeaponTestSupport.health_left()` avoids — see `src/Systems/Items/modifiers/` suites.


## Keep `.gdunit.log` clean
Both runners overwrite `.gdunit.log` at the repo root, so it is the complete warning list for the last run. **A green run can still be noisy** — read the log after any run that touched a script, and check the totals rather than only the lines you expected. One hand-written `.tscn` with a missing `uid` once accounted for 58 of the log's 108 warnings, because Godot re-warns on *every* load of that resource.

### Baseline: 6 warnings, 20 errors — all of them expected
- **All 20 errors are negative tests**: 15 `[EventContracts]` violations, 4 `CharacterUI` / `BuffUI` "no character assigned" guards, and `Debug scenario index out of range`. They assert that validation *rejects* bad input. Not yours.
- **5 of the warnings are guard paths** too: `ShopMenu: No item_factory assigned!`, `Stats node not found under holder`, and three `BaseModifier.attach:` messages.
- The 6th warning is `ObjectDB instances leaked at exit`.

Anything in the log that is not on that list was introduced by your change.

### Traps that have actually bitten this repo
- **A bare `int` assigned to an enum-typed property.** `ItemCardRow.tone` is typed `Tone`, so a helper declared `-> int` warns at *every* call site. Type the helper's return as the enum instead of casting at each assignment; where an `int` sentinel is unavoidable, narrow it once in a helper — see `_forced_tone()` in `src/ui/item_tooltip.gd`.
- **Parameters and locals that shadow an inherited or class member.** Rename the parameter, do not suppress: `cover_fit()` and `required_art_width()` take `slack_margin` rather than `margin`, `sway_offset()` takes `amplitude` rather than `travel`, `make_texture_icon()` takes `plate_size` rather than `size`.
- **Never pin a balance number in an assertion.** `base_damage`, `base_attack_speed`, `weapon_range`, `damage_multiplier`, poison `chance` / `duration` / `tick_interval` / `max_stacks`, item budgets — these are `.tres` **data**, and rebalancing them is a normal, frequent edit. An `assert_float(aura.base_attack_speed).is_equal(0.5)` goes red on every balance pass, and the fix is always to weaken the suite, so the assertion rots into a stale copy of the `.tres`. Assert the **mechanic** instead, deriving the expectation from the values under test:
  - Rate: `assert_float(equipped.timer.wait_time).is_equal_approx(1.0 / (equipped.base_attack_speed * holder_speed))` — and assert the *proportionality* too (double the rate, expect half the wait), so a timer hardcoded to a plausible cadence still fails.
  - Damage: assert health dropped and that it scales with `weapon.current_damage` — never against a literal.
  - Range: compare the weapon's own accessor to the selector's radius, both read live (e.g. `_aura_range_px()`), not to a meter figure.
  - Counts, ordering and structural facts (`weapons.size() == 1`, "both enemies were hit in one tick", "the burst is centred on the sprite") **are** mechanics; keep asserting those as literals.
  If a number really is invariant, say why in the test's doc comment — otherwise it is a balance value wearing a test's clothes.
- **Never name a test local `before` or `after`.** Those are `GdUnitTestSuite` assertion methods; a local of that name shadows them and reads as though it still refers to the hook. Use `count_before`, `rect_before`, `tiles_before`.
- **A name redeclared in a nested block.** Reusing the enclosing block's name is the "declared below in the parent block" warning. Give the inner one its own name (`hovered`).
- **Unused locals, and private class vars written from elsewhere.** Delete unused locals. If a member is written from another class, a leading underscore is a lie and GDScript reports it unused — `BaseWeapon.bound_effect_nodes` is filled and cleared by `weapon_builtin_effects.gd`, so it carries no underscore.
- **Integer division and narrowing.** Write `int(x / 2.0)` when the truncation is the intent, and never pass a float expression to an `int` parameter — `simulate_frames(60 * 2.5)` warns and wants `simulate_frames(150)`.
- **Assigning `size` on a `Control` whose opposite anchors are unequal.** Godot overrides it after `_ready()` and warns. Use `set_deferred("size", ...)`, which is also the path a real window resize takes.
- **A `.tscn` or `.tres` hand-written rather than saved from the editor.** A missing `uid="..."` attribute makes the invalid-UID warning repeat on every load. Re-save the file from the editor rather than pasting the UID in by hand.
- **`await` on something that is not a coroutine.** gdUnit4 helpers such as `runner.simulate_frames()` return immediately, so the `await` is redundant.
- **Do not reach for a child or the parent through `@onready`.** `@onready` waits for `_ready`, so the field reads as `null` for as long as the node is detached, and a plain initializer is no better: a scene's root runs its member initializers *before* its children are attached. Use a getter, which runs on access — `get_parent()` and `get_node_or_null()` are both valid the moment the node is parented, tree or no tree. `Character`'s five refs and both holders' `hold_owner` / `stats` / `event_manager` are getters for this reason; see `src/Scripts/character.gd`. It also means a detached character can be equipped into with no wiring, which is what `test/Systems/weapon/test_weapon_equip_detached_character.gd` pins. Do not "optimise" these back into a cached field.

`@warning_ignore("...")` is a last resort and each use wants a comment saying why. It is never the fix for a shadowed name or a mistyped enum.

## Visual checks (rendering a scene to a PNG)
Tests assert structure, not looks. After changing a UI, render it:
```
.\run_scene_shot.bat res://path/to/Scene.tscn [res://out.png]
```
- Writes `res://scene_shot.png` by default, prints the path, and quits. Measured at ~1.5s end to end, because run, capture and quit all happen inside that one call.
- **Prefer this over MCP for a plain render.** Every tool call is a separate round trip that costs model time before the request is even sent, so `run_project` + `get_runtime_screenshot` + `stop_project` is 3 calls and several times slower for the same PNG.
- The window flashes up briefly — a headless viewport has no framebuffer to read back.
- The target scene must render standalone (no gameplay set up behind it). `res://test/tools/character_ui_preview.tscn` and `res://test/tools/shop_ui_preview.tscn` exist for the character menu and the shop, which both need a character in `GlobalGameState.current_character`.

### MCP screenshots (live game, when you need to interact first)
`get_editor_screenshot` (2D/3D viewport), `run_project` and `get_runtime_screenshot` Use them when the check needs a running game rather than a one-shot render: firing `simulate_input_action`, inspecting nodes mid-run, or screenshotting after several actions. `stop_project` exits cleanly, leaving only the editor process.

# Project documentation.
- This is top-down brotato style rogulike game project on godot 4.6.
- If docs outdatet than updated them.

## The most important docs located by those path:
- `docs/ai_overview.md` — the reading order, and an index of every other doc
- `docs/architecture.md` — which scene/script owns what, and how systems talk

## Doc conventions
- **Paths are repo-root-relative.** `src/Systems/stats/stats.gd`, not the path with the `src/` prefix dropped. This is enforced, not stylistic.
- **`test/test_doc_links.gd` enforces it.** It asserts every project path a doc backticks resolves, every bare filename a doc cites still exists somewhere, and that `docs/ai_overview.md` indexes every doc that exists. Run it with `.\run_tests_gdunit_custom.bat doc_links`. If you rename a file the docs cite, that test is what tells you.
- Two spans are skipped as patterns rather than literals: anything containing `%`, `*`, `<` or `>` (e.g. `src/Assets/stats/%s.png`). Everything else in backticks is treated as a real reference.
- `docs/archive/` is deliberately **not** checked — those are frozen logs of shipped work.

## Balance rules
- `docs/systems/balance.md` says how much power a weapon, item or modifier is allowed to give. **Read it before designing a new weapon, item, modifier or character** — it has per-stat budget tables, the weapon tier table, and copy-paste checklists for weapons and modifiers.
- Hard rule: **one item may add at most +15%** to a character's offense or survivability. Bigger than that is a weapon, not an item.
- That file is prescriptive and the game does not currently obey it. **`docs/systems/balance_audit.md` holds the 23 measured violations, the fix order, and the assumptions those numbers rest on. Do not start "fixing" them unless the task asks for it.**
- The two files are split on purpose. `balance.md` changes only when a design decision changes; the audit changes every time someone edits a `.tres`. When you fix an audit row, delete the row rather than editing the measurement.

## Major systems docs
The per-system docs live in `docs/systems/` and are indexed, with one-line descriptions, in `docs/ai_overview.md`. Do not maintain a second copy of that list here — the link test only checks the index in `ai_overview.md`, so a list that drifts in two places is exactly the problem the index replaced.

## Dev tooling (`test/tools/`, not shipped)
- `test/tools/scene_shot.tscn` + `test/tools/scene_shot.gd` — instantiates a scene named by `OS.get_cmdline_user_args()`, screenshots it, quits. Driven by `run_scene_shot.bat`.
- `test/tools/character_ui_preview.tscn`, `test/tools/shop_ui_preview.tscn` — the character menu and the shop with a stub character wearing sample items/weapons, so they render standalone for a visual check.
- The shop fixture pins its offers: it builds its own `ItemFactory` (which needs a `Stats` child), seeds `drop_pool` with a fixed `rng.seed`, and calls `load_items([])` to jump from phase 1 (icon tiles) to phase 2 (the card row whose `InfoLabel` carries the tone-coloured stat body). Phase 1 shows icons only, so it cannot show card colours. The offer pool is small and weighted (`_offer_items()`) because `get_item_from_pool_or_generate()` picks *with* replacement, so a big pool would leave the items you care about off the 4-card row. The character menu only renders icon tiles, so card-body checks must go through the shop fixture.
- `SAMPLE_ITEMS` in the character fixture is the place to add an item you want to see rendered. Neither preview is named `test_*.gd`, so the gdUnit and GUT runners skip them.

## Debug scenarios (`test/scenarios/`, not shipped)
The main menu's **Debug scenarios** button opens a picker that jumps into a run already mid/endgame; **New game** is still the default route. A scenario is one `.tscn` that instances `src/Scenes/Game.tscn` and adds a single `ScenarioSetup` node, so the scene file *is* the configuration — add a scenario by adding a dict to `SCENARIOS` in `test/scenarios/debug_scenario_menu.gd` plus a `.tscn` next to it. `docs/systems/debug_scenarios.md` has the details, including why the loop-3 scenario sets `StageManager.current_loop` and both spawners' counters by hand instead of calling `start_new_loop()`.
