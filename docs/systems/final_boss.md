# Final boss — the Vault Baron

## Purpose
The run's last fight: a scripted three-phase boss, faced when the player picks the Finale Gate. Stage bosses are still `src/Systems/enemies/EnemyBoss.tscn` with a shotgun loadout. The full design (all planned attacks, art prompts, milestones) is `docs/plans/final-boss-vault-baron.md`.

**Built so far (M1-M4):** the whole fight. Phase 1: Coin Spray, Dividend Ring, Ram. Phase 2: Coin Spray, Dividend Ring, Double Ram, Safe Drop, Burrow, Coin Spiral, and Debt Collector adds. Phase 3: Coin Spray, Gold Rush, Golden Beam, Margin Call. Plus the phase-change shockwave, the plate popping off at phase 3, enrage and the death sequence. Plus presentation: the name card, a boss bar with phase ticks, screen shake and sounds. What is left is M5, balance playtesting, and real boss sounds (the ones wired in are placeholders).

**To play it:** main menu → **Debug scenarios** → **Final boss** starts the fight at stage 3 with a stage-3 build. Pause for **Boss: phase 2** / **Boss: phase 3** to skip ahead (`BossBrain.skip_to_phase()`). See `docs/systems/debug_scenarios.md`.

**To play it:** main menu → **Debug scenarios** → **Final boss** starts the fight at stage 3 with a stage-3 build. Pause for **Boss: phase 2** / **Boss: phase 3** to skip ahead (`BossBrain.skip_to_phase()`). See `docs/systems/debug_scenarios.md`.

## Key files
- `src/Systems/enemies/EnemyFinalBoss.tscn` — the boss. An ordinary `Enemy` (health, stats, death, hit flash all work as for any enemy) with the art, a `FrontShield` and a `BossBrain` as its `MovementBehaviour`.
- `src/Systems/boss/boss_brain.gd` (`BossBrain`) — phases, attack choice, movement between attacks.
- `src/Systems/boss/boss_attack.gd` (`BossAttack`) — the base every attack extends.
- `src/Systems/boss/boss_bullets.gd` (`BossBullets`) — coin projectiles, the `fan()` / `ring()` patterns, `blast()` (explosion damage + visual) and the arena clamp.
- `src/Systems/boss/ground_marker.gd` (`GroundMarker`) — a drawn ground circle: the Safe Drop shadow and the shockwave ring and the Margin Call ring.
- `src/Systems/boss/boss_hud.gd` (`BossHud`) and `src/Systems/boss/boss_health_bar.gd` (`BossHealthBar`) — the boss bar and the name card.
- `test/tools/final_boss_preview.tscn` — renders the boss mid-attack for a visual check: `.\run_scene_shot.bat res://test/tools/final_boss_preview.tscn res://boss_shot.png 5`. `GroundMarker`s sit at `z_index` -1, above the arena floor's -10, so the preview's backdrop sits at -10 too.
- `src/Systems/boss/attacks/` — one script per attack.
- `src/Assets/enemies/vault_baron.png`, `src/Assets/enemies/vault_baron_broken.png`, `src/Assets/boss/` — art, cut by `test/tools/extract_vault_baron.gd` from the sources in `docs/plans/images/boss/`.
- `test/Systems/boss/test_final_boss.gd` — the suite.

## How it is wired
- `BossSpawner.spawn_final_boss()` instantiates `final_boss_scene` instead of `boss_scene`. It gets the same health and damage scaling as before, but **no weapon loadout**: the attacks replace it. Coin damage is `coin_damage × attack damage_mult × the boss's damage stat`, so the spawner's damage scaling reaches the attacks without either knowing about the other.
- `BossBrain` **is** the boss's `MovementBehaviour`, so `Enemy._physics_process` calls `process_movement()` every frame and the brain decides everything: transition, run the current attack, or walk to `keep_distance` and count down to the next attack. Nothing swaps behaviour nodes.
- Attacks are the `BossAttack` children of the brain. Adding one is a script under `src/Systems/boss/attacks/`, a child node with `config_key` set, and a block under `final_boss.attacks` in `game_config.json`.

## The attack timeline
Every attack runs TELEGRAPH → ACTIVE → RECOVER, driven by `tick(delta)`, which returns true when done. The boss stands still during telegraph and recovery; the telegraph pulses the boss gold (on the `Node2D` container, because `HitFlashManager` owns the sprite's modulate). A subclass overrides only the hooks it needs: `_on_telegraph`, `_telegraph_tick`, `_on_active`, `_active_tick`, `_on_active_end`. `stop()` ends an attack early (phase change, death) and runs `_on_active_end`, so anything the attack put on the boss comes off.

It is tick-driven rather than built on `await`ed timers so a test can step it frame by frame with no waiting.

| Attack | Active part |
|---|---|
| Coin Spray | `volleys` fans of `count` coins over `spread_deg`, re-aimed each volley |
| Dividend Ring | one ring of `count` coins with `gap` slots left out, centred on the player |
| Ram / Double Ram | one script, `charges` 1 or 2. Charges along the direction locked when the telegraph ends (a red line shows it); between charges it pauses `between` s with the line re-aiming. A wall hit ends a charge early; on the last charge it adds `wall_stagger` to the recovery. Speed is a `Stats` modifier, for the reason in `docs/systems/enemies.md` "Charging" |
| Safe Drop | `count` `GroundMarker` shadows fill over `fall_time` while a safe sprite drops into each; then each `blast()`s at its radius. The first lands on the player, the rest around where the player is heading (`velocity × fall_time`), scattered by `scatter` |
| Burrow | the boss goes underground: hidden, off its collision layers, out of the `damageable` group, and `blocks_damage()` is true so the brain zeroes any hit that still reaches it. A mound tracks the player for `track_time` at `mound_speed`, holds still for `lock_time`, then the boss erupts there with a `blast()` and a coin ring. Everything comes back in `_come_up()`, which `stop()` also runs |
| Coin Spiral | `arms` coins every `interval` for `duration`, the arms turning `turn_deg` per shot |
| Gold Rush | the ram script again (`charges` 4, a long `max_duration`, a long `wall_stagger`): each charge runs until it hits a wall, then the line re-aims at the player and it goes again. The last wall hit leaves the longest opening in the fight |
| Golden Beam | an aim line tracks the player during the telegraph, offset to where the sweep starts; then a beam (`length` x `width`) sweeps `arc_deg` over `sweep_time` in a random direction, drawn behind the body so it comes out of the vault. `is_in_beam()` is a point-to-segment distance; each body is hit at most once per `hit_interval` |
| Margin Call | a `GroundMarker` ring starts outside the arena's farthest corner (or at `start_radius` with no arena), blinks through the telegraph, closes to `min_radius` around the boss over `close_time`, holds for `hold_time`, opens over `open_time`. Anything outside the ring takes `damage` every `hit_interval` |

`BossBullets.victims()` (every `damageable` body that is not an enemy) and `hurt()` are shared by `blast()`, the beam and Margin Call. A group scan, like `AreaBurstOnEnter`, so the hit lands on the frame it is called and a test can assert it without physics.

## Phases
- A phase ends when health drops to its `phase_thresholds` fraction. The running attack is stopped and the boss stands still, taking no damage, for `transition_time`.
- **A hit cannot skip a phase**: before the last phase, damage is cut so health stops at the next threshold.
- Each phase sets the boss's speed (`speed_mult`, a `Stats` modifier replacing the last one) and its `keep_distance`.
- Entering phase 3 frees the `FrontShield` (unsubscribing it first), swaps the sprite to `broken_texture` (both PNGs share one crop so nothing jumps) and multiplies incoming damage by `phase3_damage_taken_mult`.
- **Every phase change opens with a shockwave**: a gold ring expands to `shockwave_radius`, and a target inside it gets a `KnockbackController` push away from the boss (`shockwave_force` m/s). No damage — it is a reset, so the new phase never starts with the player on top of the boss.
- Phase 3 also pops the ram plate: a damage-free blast visual at the boss's front (`plate_burst_radius`). A `TextureBurst` was not used: it shatters the whole body texture and reads as the boss dying.

## Enrage
After `enrage_time` seconds of fight the boss turns `enrage_tint` and every recovery and attack gap is multiplied by `enrage_recover_mult`. The attacks read both through the brain (`recover_mult()`, `rest_tint()`), so a telegraph pulse settles back on red, not white. The plan also had Margin Call stop retreating; that was left out, the shorter recoveries already end a stalled fight.

## Death
The kill sets `Engine.time_scale` to `death_time_scale`, and a fountain of `death_coins` coin particles (`CPUParticles2D`) bursts from the body while the usual death animation and shards play. The restore is a tween **owned by the tree, animating the `Engine` singleton**, that ignores time scale and runs while paused: it waits `death_slowmo_time` real seconds and eases back to 1 over `death_ramp_time`. A tween or timer bound to the brain would die with the boss and leave the game in slow motion. Suites that kill the final boss reset `Engine.time_scale` in `after_test`.

## Debt Collectors (adds)
In the phases listed in `adds_phases` the brain spawns `adds_pack_size` of `add_scene` (the Swarmer, tinted gold on its `Node2D`) in a ring `adds_spawn_distance` from the player: one pack the moment the phase starts, then one every `adds_interval`, never more than `adds_max_alive` alive. They go into the boss's own parent (`Nodes/Enemies`) like any enemy, so the arena sees them — and so they **must** die before the fight can end: `kill_adds()` runs when their phase ends and when the boss dies. Spawned outside `EnemySpawner`, they carry no `SpawnerModifier` and drop nothing.

## Presentation
- **Boss bar and name card.** `BossBrain` builds a `BossHud` (a `CanvasLayer`) under the boss when the boss emits `ready`. Not in `_ready` with a deferred call: a deferred `add_child` / `setup` on a boss freed in the same frame leaked the HUD. The bar is drawn (`BossHealthBar._draw`), listens to the boss's `on_health_changed`, puts a white tick at each `phase_thresholds` fraction and turns red on enrage. The name card (`boss_name`, `boss_epithet` on the brain) fades in and out over `name_card_time`; `intro_time` matches it so the first attack comes as the card goes. The scene has no floating `HealthBar`: the screen bar replaces it.
- **Screen shake.** `BossBullets.shake(node, moment)` kicks the current `Camera2D` (`src/Scripts/camera_2d.gd`, scaled by the options slider) by `shake.<moment>`: `phase`, `wall`, `blast`, `erupt`, `death`.
- **Sounds.** Every attack has `telegraph_sound`, `active_sound` and `impact_sound` exports (played through `SoundManager.play2d` at `sound_volume_db`); the brain has `phase_sound` and `death_sound`. **They are placeholders**: the project only has the fist, pistol, shotgun and UI sounds, so the scene points at those. Swap the exports on `EnemyFinalBoss.tscn` when real boss audio exists; no code changes.

## Coins
A coin is the shared `src/Systems/weapon/Projectile.tscn` with the coin art and a collider sized from `coin_size`. It ignores the `enemies` group and carries no weapon, so it never procs on-hit effects. Coins go into the current scene, **not** `Nodes/Enemies`: `StageManager` ends a phase when that container is empty, and a coin must not hold it open.

## Config
Every number is in the `final_boss` section of `game_config.json`; keys are in `docs/systems/game_config.md`.
