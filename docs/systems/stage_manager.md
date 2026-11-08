# Stage Manager

Purpose
- Orchestrates the high-level flow: enemy waves, boss encounters, shop stages, and the end-of-run choice.

Key scripts / scenes
- `src/Scripts/stage_manager.gd` (`StageManager`)
- `src/Systems/loop_choice_portal.gd` (`LoopChoicePortal`) + `src/Systems/LoopChoicePortal.tscn` — the two "final boss or one more loop?" world portals.

Data flow
- Inputs: timing (stage_duration), enemy counts (from `Nodes/Enemies`), player actions (shop next, loop choice), boss/enemy spawner states.
- Processing: advances `current_stage` and `current_loop`, toggles spawners, spawns the shop portal when a boss is cleared, and offers the end-of-run choice after the last guaranteed loop.
- Outputs: starts/stops spawners, spawns the shop portal, the loop-choice portals and run end screens.
- Wave entry (`go_to_stage(1)`) calls `EnemySpawner.start_wave()` so each Wave restarts at ~1s cadence. Stage 1 end rule is unchanged: time-expired + kill-all mop-up.

## Stage numbers

`current_stage` is one of the `STAGE_*` constants on `StageManager`, not a bare int at the call sites:

| Constant | Value | What runs |
|---|---|---|
| `STAGE_WAVE` | 1 | timed spawning, then kill-all mop-up |
| `STAGE_BOSS` | 2 | one boss; clearing it opens the shop |
| `STAGE_SHOP` | 3 | waits for the player; nothing processes |
| `STAGE_FINAL_BOSS` | 4 | the run's last fight; killing it wins |

## Loops and how a run ends

A **loop** is one `Wave -> Boss -> Shop` round. `current_loop` starts at 1 and only climbs — there is no `max_loops` ceiling, because the player decides when the run ends.

Below `FINAL_BOSS_LOOP` (3) the shop's **Go next** starts the next loop, exactly as it always did. At and past it, **Go next** instead spawns **two portals** next to the player, in `Nodes`:

| Portal | What `StageManager` does |
|---|---|
| `LoopChoicePortal.Choice.FINAL_BOSS` | `go_to_stage(STAGE_FINAL_BOSS)` → `BossSpawner.spawn_final_boss()` |
| `LoopChoicePortal.Choice.EXTRA_LOOP` | `start_new_loop()` → loop + 1, back to `STAGE_WAVE` |

Taking an extra loop does **not** close the choice off: clearing it returns to the same two-portal question. Only the final boss ends the run in a win, and only `character_died` ends it in a loss.

**The win fires on the final boss dying, not on leaving a shop.** `_end_stage()` in `STAGE_FINAL_BOSS` is the only path to `_show_win_screen()`, and the only way out of that stage is killing the boss or dying.

`LoopChoicePortal` is a dumb reporter extending `Interactable` — it emits `chosen(choice)` when the player interacts with it and knows nothing about loops or bosses, so it can be driven from a test with no `StageManager` present. `StageManager.offer_loop_choice()` spawns one of each, keeps both in `loop_portals`, and frees both through `clear_loop_portals()` as soon as either is entered.

Two things the portals have to get right, both pinned by `test/Systems/test_loop_choice.gd`:
- **Both portals go away on either answer.** Picking one ends the question; the other must not keep offering a fight.
- **A death while the choice is open frees them too.** `_on_character_died()` calls `clear_loop_portals()`, or a portal would sit over the run-end screen offering a fight to a player with no character.

## Final boss scaling

`BossSpawner.spawn_final_boss()` is the same encounter as an ordinary boss, scaled `final_boss_extra_loops` (2) loops past `current_loop` — so it always out-scales the loop that led to it, and keeps climbing if the player banked extra loops first.

The weapon ramp stops at `BossSpawner.LOADOUT_LOOP_CAP` (4). Past the cap the boss carries the loop-4 loadout rather than another pair of shotguns per loop, which would cost frames instead of adding threat.

The final-boss stage runs on no stage clock, so the HUD shows `FINAL BOSS` in place of the wave countdown (`src/ui/player_ui.gd`).

Dependencies
- `EnemySpawner`, `BossSpawner`, `ShopPortal.tscn`, `LoopChoicePortal.tscn`, `RunEndScreen` UI, and the `Character` signal `character_died`.

Known limitations / TODOs
- `spawn_shop_portal` uses `get_tree().current_scene.get_node("Nodes").add_child(portal)` — assumes scene node naming conventions.
- No debug scenario reaches the loop-choice portals; loop 3 gets there by playing a shop exit. `go_to_stage(STAGE_SHOP)` followed by `_on_shop_next_pressed()` is the seam to use.
