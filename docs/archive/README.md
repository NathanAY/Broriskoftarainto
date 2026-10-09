# Archive

Implementation logs for work that has already shipped. They are kept for
provenance — "why did we do it this way" — and are **not** current truth.

Nothing here is linked from the live docs, and `test/test_doc_links.gd`
deliberately skips this folder, so these files are not kept in sync with the
code. Read them to recover a past decision; do not read them to learn how a
system works. For that, start at `docs/ai_overview.md`.

| File | What it decided |
|---|---|
| `buff-ui-remake.md` | Replaced the text buff readout with a two-row grid of icon tiles: one tile per live effect, `BuffEntry` as the presentation model, a duration arc, and the debuff row made reachable via a debug scenario. |
| `bug with infinite loop late process kill.md` | Why a script error inside a test hung the runner to its wall-clock timeout instead of failing, and the log-tail watchdog that catches it now. |
| `character-ui-item-tooltip.md` | Added the hover tooltip to the character menu, and moved the line builders out of `character_ui.gd` into a reusable static `ItemTooltip`. |
| `dynamic-provided-stats.md` | Replaced `compute_provided_stat` with the reference-counted `claim_provided_stat` / `release_provided_stat` pair, so a stat can be owned by a modifier. |
| `item-builder.md` | Made `ItemBuilder` the single construction entry point for items, so `ItemFactory` and `configure_panel.gd` stopped building `Item`s by hand. |
| `item-tooltip-clarity.md` | Fixed tooltip readability: display contract on `BaseModifier`, separation of the buff/debuff payload, and the effect-row ordering. |
| `main_menu_parallax_background.md` | Added the layered parallax main-menu background, and why the generated art was re-cut against the *art* palette rather than the UI one. |
| `soldier-rework.md` | Rebuilt the Soldier character data around the item `.tres` catalog. |
| `test-runner-single-run.md` | Why `run_tests_gdunit_custom.bat` resolves one fuzzy target to possibly several suites, and how its timeout is budgeted. |
| `weapon-builtin-modifiers.md` | Let a weapon declare its own effects via `BaseWeapon.modifiers`, instantiated through `weapon_builtin_effects.gd` and scoped by `bound_weapon`. |

Adding a new one: name it after the feature, put it here when the work lands,
and add a row to the table above. It stops being current the moment it is
written, which is the point.
