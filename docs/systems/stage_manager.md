# Stage Manager

Purpose
- Orchestrates the high-level flow: enemy waves, boss encounters, shop phases, and the end-of-run choice.

Key scripts / scenes
- `src/Scripts/stage_manager.gd` (`StageManager`)
- `src/Systems/stage_choice_portal.gd` (`StageChoicePortal`) + `src/Systems/StageChoicePortal.tscn` — the two "final boss or one more stage?" world portals.

Data flow
- Inputs: timing (phase_duration), enemy counts (from `Nodes/Enemies`), player actions (shop next, stage choice), boss/enemy spawner states.
- Processing: advances `current_phase` and `current_stage`, toggles spawners, spawns the shop portal when a boss is cleared, and offers the end-of-run choice after the last guaranteed stage.
- Outputs: starts/stops spawners, spawns the shop portal, the stage-choice portals and run end screens.
- Wave entry (`go_to_phase(1)`) calls `EnemySpawner.start_wave()` so each Wave restarts at ~1s cadence. Stage 1 end rule is unchanged: time-expired + kill-all mop-up.

## Phases

A **stage** is one full difficulty round; it is made of **phases** (Wave, Boss, Shop). The player only ever sees "Stage N" (HUD `Stage N.`, run history, portal text); phases never reach the UI under that word. Code and UI use the same two words, so do not reintroduce "loop" (the old name for a stage).

`current_phase` is one of the `PHASE_*` constants on `StageManager`, not a bare int at the call sites:

| Constant | Value | What runs |
|---|---|---|
| `PHASE_WAVE` | 1 | timed spawning, then kill-all mop-up |
| `PHASE_BOSS` | 2 | one boss; clearing it opens the shop |
| `PHASE_SHOP` | 3 | waits for the player; nothing processes |
| `PHASE_FINAL_BOSS` | 4 | the run's last fight; killing it wins |

## Stages and how a run ends

A **stage** is one `Wave -> Boss -> Shop` round. `current_stage` starts at 1 and only climbs — there is no `max_stages` ceiling, because the player decides when the run ends.

Below `FINAL_BOSS_STAGE` (3) the shop's **Go next** starts the next stage, exactly as it always did. At and past it, **Go next** instead spawns **two portals** next to the player, in `Nodes`:

| Portal | What `StageManager` does |
|---|---|
| `StageChoicePortal.Choice.FINAL_BOSS` | `go_to_phase(PHASE_FINAL_BOSS)` → `BossSpawner.spawn_final_boss()` |
| `StageChoicePortal.Choice.EXTRA_STAGE` | `start_new_stage()` → stage + 1, back to `PHASE_WAVE` |

The portals are the **Finale Gate** (`Choice.FINAL_BOSS`) and the **Deeper Gate** (`Choice.EXTRA_STAGE`). The Deeper Gate's text says the Finale is only postponed, so a player who is not ready can bank more stages first.

Taking an extra stage does **not** close the choice off: clearing it returns to the same two-portal question. Only the final boss ends the run in a win, and only `character_died` ends it in a loss.

**The win fires on the final boss dying, not on leaving a shop.** `_end_phase()` in `PHASE_FINAL_BOSS` is the only path to `_show_win_screen()`, and the only way out of that phase is killing the boss or dying.

`StageChoicePortal` is a dumb reporter extending `Portal` (`src/Systems/portal.gd`) — it emits `chosen(choice)` once the player has entered it and the entry animation has played (about 0.8s after Enter, see `docs/systems/effects.md`) and knows nothing about stages or bosses, so it can be driven from a test with no `StageManager` present. `StageManager.offer_stage_choice()` spawns one of each, keeps both in `stage_portals`, and frees both through `clear_stage_portals()` as soon as either is entered.

Two things the portals have to get right, both pinned by `test/Systems/test_stage_choice.gd`:
- **Both portals go away on either answer.** Picking one ends the question; the other must not keep offering a fight.
- **A death while the choice is open frees them too.** `_on_character_died()` calls `clear_stage_portals()`, or a portal would sit over the run-end screen offering a fight to a player with no character.

## Final boss scaling

`BossSpawner.spawn_final_boss()` is the same encounter as an ordinary boss, scaled `final_boss_extra_stages` (2) stages past `current_stage` — so it always out-scales the stage that led to it, and keeps climbing if the player banked extra stages first.

The weapon ramp stops at `BossSpawner.LOADOUT_STAGE_CAP` (4). Past the cap the boss carries the stage-4 loadout rather than another pair of shotguns per stage, which would cost frames instead of adding threat.

The final-boss phase runs on no phase clock, so the HUD shows `FINAL BOSS` in place of the wave countdown (`src/ui/player_ui.gd`).

The HUD objective line (`PlayerUI.objective_text()`) reads `Stage N. Survive X seconds` during the wave, `Stage N. Kill remaining enemies` once the wave timer has run out, `Stage N. Kill the boss` during a stage's boss phase, and `Stage N. Explore area` from the boss kill until the next stage or the final boss starts.

Dependencies
- `EnemySpawner`, `BossSpawner`, `ShopPortal.tscn`, `StageChoicePortal.tscn`, `RunEndScreen` UI, and the `Character` signal `character_died`.

Known limitations / TODOs
- `spawn_shop_portal` uses `get_tree().current_scene.get_node("Nodes").add_child(portal)` — assumes scene node naming conventions.
- No debug scenario reaches the stage-choice portals; stage 3 gets there by playing a shop exit. `go_to_phase(PHASE_SHOP)` followed by `_on_shop_next_pressed()` is the seam to use.
