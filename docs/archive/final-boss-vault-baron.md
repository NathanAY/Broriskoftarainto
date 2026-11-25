# Plan: the final boss — The Vault Baron

Status: **M1-M4 implemented**: the whole fight is playable and presented (name card, boss bar with phase ticks, screen shake, placeholder sounds), see `docs/systems/final_boss.md`. Three phases with the shockwave, the no-skip clamp, shield break (a blast pop at the plate) and broken art, Debt Collector adds in phase 2, all ten attacks, enrage, and the slow-motion coin-fountain death. Art is in, cut by `test/tools/extract_vault_baron.gd`. The debug scenario below is in (`test/scenarios/scenario_final_boss.tscn`, with pause-menu phase skips). **Next: M5** balance playtesting and real boss sounds. Differences from the text below: attacks are tick-driven (`start` / `tick` / `stop`) instead of one `run()` coroutine; the brain is the boss's `MovementBehaviour` itself; the shockwave fires on both phase changes; Gold Rush is the ram script with more charges; enrage shortens recoveries but does not stop Margin Call retreating; no intro invulnerability or burning-fuse swell on death.

All numbers below are **starting values for `game_config.json`**, not constants (see "Config" at the end). They are written here so the fight can be read; the config is the source of truth once it exists.

---

## 1. Concept

**The Vault Baron** — the wasteland's richest creature. A colossal legless iron slug that dragged a whole bank vault out of a dead town and welded it onto its back. Its snout is a riveted battering ram, its mouth is full of gold teeth, and its "bullets" are coins, safes and gold.

Why this boss for *this* game:
- The run is built around money (economy items, the Tycoon, debt, interest). The last enemy is the embodiment of it, so the fight reads as the run's punchline without any economy mechanic in the fight itself (the final boss pays no bounty and no shop follows — `BossSpawner.bounty_for()`).
- It is a **blob**, so it obeys every enemy art rule in `docs/visual_style.md`: legless, side-on, facing right, one solid silhouette.
- Its parts give natural telegraphs: the ram plate (front = shielded), the vault door (opens = vulnerable / attacks coming), the gold glow (charging up).

Tone: Borderlands boss intro — big name card, a little absurd, genuinely threatening.

---

## 2. Fight rules (apply to every attack)

These are what make a bullet-hell-lite boss fair in a top-down auto-shooter where the player only moves:

1. **One attack at a time.** The brain never overlaps two attacks; adds and hazards are the only things that run in parallel.
2. **Every attack telegraphs** for at least `telegraph_min` (0.6 s) with a visual (ground decal, glow, wind-up animation) *and* a sound. No unreadable damage.
3. **Every attack is dodgeable at base movement speed** with no items. Pattern projectiles are slower than the player's base speed.
4. **Every attack ends in a recovery window** (`recover_time`) where the boss stands still. That is the damage window, and it is where melee builds get their hits in.
5. **No attack repeats twice in a row** (weighted pick excluding the last one).
6. **The front is armoured.** The ram plate turns away hits on its front arc (`FrontShield`, as on the Shieldbearer) in phases 1–2. Ranged builds must circle; the recovery windows face the boss away from the player often enough that nobody is locked out. Phase 3 breaks the plate.
7. **Target fight length 70–100 s** for an expected stage-3 build. Health is still scaled by `BossSpawner._apply_scaling()`, so banking extra stages still makes the fight longer.

---

## 3. Phases

Phase changes at health thresholds. Each transition is an invulnerable set piece (`transition_time`, ~2 s) so a burst build cannot skip a phase's opener.

| Phase | Health | Name | Feel |
|---|---|---|---|
| 1 | 100–65% | **Collection** | Slow, armoured, readable. Teaches the shield and the basic patterns. |
| 2 | 65–30% | **Hostile Takeover** | Uses the whole arena: mortars, burrowing, debt-collector adds. |
| 3 | 30–0% | **Bankruptcy** | Plate shattered, vault burst open, gold core exposed. Faster, desperate, more damage taken. |

### Intro (before phase 1)
- The boss teleports in through `SpawnPortal` as today, then plays a **name card** ("THE VAULT BARON — Chairman of the Wastes") across the top of the screen for ~1.5 s. Invulnerable, no attacks, during the card.
- The HUD swaps the wave timer line for a **boss bar**: name + health bar with two tick marks at 65% and 30% so the player sees the phases coming.

### Phase 1 — Collection (100–65%)
**Movement:** `ChaseDistanceMovementBehaviour` at `p1_keep_distance` (~350 px), slow. Contact damage on (Thorns).

| Attack | Telegraph | What it does | Counterplay |
|---|---|---|---|
| **Coin Spray** | Mouth glows gold, 0.7 s | Fan of 7 coin projectiles aimed at the player, 50° spread. Fired 3 times, 0.4 s apart, re-aimed each volley. | Strafe sideways; the fan has gaps at range. |
| **Dividend Ring** | Vault door rattles, coins orbit the body, 0.8 s | One ring of 20 slow coins outward, **with a 2-coin gap** aimed at the player. | Walk into the gap, or outrun the ring (it is slow). |
| **Hostile Ram** | Rears back, dust under the snout, red line decal along the locked direction, 0.9 s | `ChargeMovementBehaviour`-style charge on a locked direction, stops at the arena wall with a stagger (longer recovery if it hits the wall). | Step off the line. Hitting it in the back during the stagger is the reward. |

### Transition 1 → 2 (at 65%): "Vault Opens"
- Boss roars, invulnerable `transition_time`. A **knockback shockwave** pushes the player out to `shockwave_radius` (no damage — it is a reset, not a punish).
- The vault door swings open (sprite swap or overlay). From now on coins visibly spill out while moving (cosmetic).
- Spawns the first **Debt Collector** pack (see below).

### Phase 2 — Hostile Takeover (65–30%)
**Movement:** chase-distance, faster (`p2_speed_mult`). Alternates with burrowing.

| Attack | Telegraph | What it does | Counterplay |
|---|---|---|---|
| **Safe Drop** (mortar) | Boss lobs safes upward; a **shadow circle grows on the ground** at each landing spot for 1.0 s | 4–6 safes land around/at the player and explode (`Explosion.tscn`, radius `safe_radius`). One always targets the player's current position, the rest predict along their velocity. | Keep moving; don't stand in shadows. |
| **Burrow** | Sinks into the sand, a dust mound trail follows the player for 1.5 s (untargetable while under) | Erupts under where the mound stops: damage ring + a Dividend Ring from the eruption point. Reuses the blink idea of `BlinkMovementBehaviour`, but the travel is visible. | The mound locks 0.5 s before eruption — move away from it once it stops. |
| **Coin Spiral** | Spins in place, vault glowing, 0.8 s | Two-armed rotating spiral of coins for 3 s. | Circle with the spiral's rotation, or get close (spirals are wide at the boss). |
| **Double Ram** | As Hostile Ram | Two charges back to back, the second re-aimed after a short pause. | Same as the ram, twice. |

**Debt Collectors (adds):** every `adds_interval` (~12 s) in phase 2, a small pack of Swarmers (`src/Systems/enemies/EnemySwarmer.tscn`, existing scene, optional gold tint) spawns at the arena edge. Capped at `adds_max_alive`. They keep auto-aim weapons busy and give on-kill items something to proc on. Adds never block phase progress: they die with the boss.

### Transition 2 → 3 (at 30%): "Bankruptcy"
- Invulnerable `transition_time`. The ram plate **shatters** (texture-burst shards, `TextureBurstManager`), `FrontShield` is removed.
- The vault bursts; the **gold core** is visible. The boss takes `p3_damage_taken_mult` (×1.25) more damage from now on — the player gets a payoff for surviving phase 2.
- Remaining adds are killed (they "run away with the money").

### Phase 3 — Bankruptcy (30–0%)
**Movement:** plain chase, fast (`p3_speed_mult`). Desperate and aggressive, shorter recoveries.

| Attack | Telegraph | What it does | Counterplay |
|---|---|---|---|
| **Gold Rush** | Glows bright gold, screen shake, 1.0 s | Charge that **bounces off arena walls** 3 times, re-aiming at the player on each bounce (each bounce shows a short line decal first). Long stagger after. | Read each bounce line; the long stagger is the best damage window in the fight. |
| **Golden Beam** | Core charges, a thin aim line sweeps, 1.0 s | A beam from the core that sweeps a 120° arc over 2.5 s (laser, reuse `src/Systems/weapon/laser_weapon.gd`'s beam scene if it fits, else a custom `Line2D` + raycast). | Move with the sweep or get behind the boss. |
| **Margin Call** | Arena edge turns gold and ticks, 1.5 s | A damaging ring closes from the arena edge to `margin_call_min_radius` around the **boss**, holds 3 s, then retreats. Forces the fight close. | Stay near the boss — dangerous for kiting builds, great for melee. |
| **Coin Spray** | Shorter telegraph (0.6 s) | As phase 1, 5 volleys. | Same. |

### Death
- Slow-motion (`Engine.time_scale` 0.3 for ~1 s), the body swells (reuse the `DetonationFuse` swell look), then a **coin fountain** explosion — hundreds of coin particles, no damage.
- Then the existing win flow: `StageManager` `PHASE_FINAL_BOSS` → `_show_win_screen()`. Nothing in StageManager changes.

### Enrage (safety net)
If the fight runs past `enrage_time` (~150 s), recovery windows halve and the Margin Call ring stops retreating. Keeps a pure-defence build from stalling forever. Shown as the boss bar turning red.

---

## 4. Implementation

Kept as small as the design allows. The boss is still an `Enemy` (`src/Scripts/Enemy.gd`) — health, stats, damage, death, hit flash all work as they do now. What is new is one brain node and one small script per attack.

### Files

| File | What |
|---|---|
| **src/Systems/enemies/EnemyFinalBoss.tscn** (new) | New scene: a copy of `EnemyBoss.tscn` with the new art, `art_width` 195, a `FrontShield`, an empty `WeaponHolder`, and a `BossBrain` child with its attack children. Save it from the editor (UIDs). |
| **src/Systems/boss/boss_brain.gd** (new) (`BossBrain`) | Phase state machine. Reads phase thresholds from config, listens to `after_take_damage` on the boss's event bus, runs transitions, picks the next attack (weighted, no repeat), waits `attack_gap` between attacks, swaps `boss.behaviour` per phase. Pauses the boss's movement while an attack that needs it runs. |
| **src/Systems/boss/boss_attack.gd** (new) (`BossAttack`) | Base node: `phases: Array[int]`, `weight`, and one coroutine `run(boss, target)` that does telegraph → perform → recover and returns. Nothing else. |
| **src/Systems/boss/attacks/** (new) | One script per attack: `coin_spray`, `dividend_ring`, `ram`, `safe_drop`, `burrow`, `coin_spiral`, `gold_rush`, `golden_beam`, `margin_call`. |
| **src/Systems/boss/boss_bullets.gd** (new) | Static helpers: `fire(from, dir, speed, damage)` spawning `src/Systems/weapon/Projectile.tscn` with the enemy's ignore groups, and `ring(...)` / `fan(...)` built on it. All pattern attacks share this. |
| `src/Scenes/effects/` | Telegraph decals: line decal, growing shadow circle, dust mound. Read `docs/systems/effects.md` first. |
| `src/ui/` | Boss bar + name card on the HUD (`src/ui/player_ui.gd` already special-cases the final boss phase). |

### Changes to existing code
- `src/Systems/boss_spawner.gd`: add `@export var final_boss_scene: PackedScene`. `spawn_final_boss()` instantiates it instead of `boss_scene` and **skips the shotgun loadout ramp** (the attacks replace it). Health/damage scaling stays as is.
- `ChargeMovementBehaviour`: the ram attacks can either drive it directly or copy its "locked direction + temporary speed modifier" approach. Note from `docs/systems/enemies.md`: the speed **must** be a `Stats` modifier, not a raw velocity, because `Enemy._physics_process` clamps velocity to movement speed.
- Phase-3 damage-taken multiplier: a `before_take_damage` listener on the boss (same hook `FrontShield` uses) — no change to `Damage`.

### Open technical questions (check before M1)
- Can `projectile.gd` be spawned without a `source_weapon`, and does `do_damage` route through `Damage.deal`? If not, boss_bullets.gd needs a tiny weapon stub as the source.
- Does a projectile count as a hit for player `on_hit`-style reactions (thorns, armour)? It should behave like a Gunner bullet.
- Invulnerability during transitions: a `before_take_damage` listener zeroing `final_amount` (as `FrontShield` does) is the simplest route.

### Config — new `final_boss` section in `game_config.json`
Documented in `docs/systems/game_config.md`. Keys (starting values):

```
phase2_threshold 0.65, phase3_threshold 0.30, transition_time 2.0,
telegraph_min 0.6, attack_gap 0.8, recover_time 1.2, enrage_time 150,
p1_keep_distance 350, p2_speed_mult 1.25, p3_speed_mult 1.6, p3_damage_taken_mult 1.25,
coin_speed 260, coin_damage_mult 1.0, spray_count 7, spray_spread_deg 50,
ring_count 20, ring_gap 2, spiral_arms 2, spiral_duration 3.0,
safe_count 5, safe_radius 90, safe_fall_time 1.0,
burrow_track_time 1.5, burrow_lock_time 0.5, ram_speed_mult 3.0,
gold_rush_bounces 3, beam_arc_deg 120, beam_sweep_time 2.5,
margin_call_min_radius 300, margin_call_hold 3.0,
adds_interval 12, adds_pack_size 5, adds_max_alive 10,
shockwave_radius 400, attack weights per attack
```

Projectile/attack damage scales off the boss's `damage` stat, so `BossSpawner._apply_scaling()` keeps working without knowing about attacks.

### Tests (per AGENTS.md: assert mechanics, never balance numbers)
- `BossBrain` changes phase when health crosses each threshold read from config, and only once.
- The boss takes no damage during a transition.
- The picker never returns the same attack twice in a row and only picks attacks whose `phases` contain the current phase.
- `FrontShield` exists in phases 1–2 and is gone in phase 3; phase-3 damage is `p3_damage_taken_mult` × phase-2 damage for the same hit.
- `fan()` fires `spray_count` projectiles symmetric around the aim direction; `ring()` leaves exactly `ring_gap` missing slots, centred on the player.
- Each attack's `run()` returns (no hang) and leaves the boss's `behaviour` and speed modifiers as they were — including when the boss dies mid-attack.
- `spawn_final_boss()` uses `final_boss_scene` and adds no shotguns; `spawn_boss()` is unchanged.
- Killing the final boss still reaches the win screen (existing stage manager suite).

### Milestones
1. **M1 — skeleton:** scene, brain, base attack, bullets helper, phase 1 (Coin Spray, Dividend Ring, Ram) with placeholder art and plain decals. Playable end to end.
2. **M2 — phase 2:** Safe Drop, Burrow, Coin Spiral, Double Ram, Debt Collector adds, transition 1.
3. **M3 — phase 3:** shield break, Gold Rush, Golden Beam, Margin Call, enrage, death sequence.
4. **M4 — presentation:** final art, name card, boss bar, VFX, screen shake, sounds.
5. **M5 — balance:** play stage-3 runs with 3+ characters (melee, ranged, economy build); tune toward the 70–100 s target. Record results in `docs/systems/balance_audit.md` if the boss is out of budget.

### Debug scenario
Add a `test/scenarios/` scenario that starts directly in `PHASE_FINAL_BOSS` with a stage-3 loadout, plus a sandbox button to jump to phase 2 / phase 3 (set health to just above the threshold). Iterating on phase 3 without it means playing 3 stages each time.

---

## 5. Art

Asset class: **boss sprite**, **src/Assets/enemies/vault_baron.png** (new) (and vault_baron_broken.png for phase 3), source-size ~1024 px, drawn at `AssetSizes.BOSS_SPRITE` (225) with `art_width` 195. Mipmaps on, `Linear with Mipmaps` filter, white keyed out, trimmed to the creature. Ink band target ~19 px at drawn size (~90 px on the 1024 generation) — expect the generator to deliver about half; measure it.

Generate with the `generate-image` skill, aspect **1:1**, mode **Vivid and natural**. Each prompt below follows the enemy template of `docs/visual_style.md` word for word except the creature description, and stays under Bing's 2000-character cap.

### Prompt 1 — the boss (phases 1–2)

```
A single top-down arena roguelite boss creature drawn side-on, one solid legless blob body: a colossal armoured iron slug tycoon with a huge rusted riveted bank vault welded onto its back, the round vault door with a big brass wheel handle on the side of the vault, a massive iron battering ram plate bolted across the blunt front of its body, a wide grinning mouth full of gold teeth, a tiny battered top hat on its head, gold coins stuck in its hide, dark gunmetal and rust brown hide with one saturated hero colour of tarnished gold. No legs, no feet, no arms, no hands, no tail and no separate limbs of any kind, just the body, exactly like a legless blob monster. The creature faces to the right: its body lies horizontally and points to the right-hand side of the frame, the ram plate is on the right-hand end of the body, and its two big angry cartoon eyes and wide mouth sit on the right-hand side of its head, looking right. Seen from above at a steep, almost directly overhead angle. Every shape is bordered by a very thick, uniform black ink outline drawn with a loaded black marker, about one tenth of the creature's width thick, roughly 90 pixels on the 1024-pixel image, the boldest element in the drawing. Flat solid muted dusty frontier colour fills with only one flat darker tone used for shading, plus thin black hatch strokes, rivets and crack lines inside the hide and the plates. Chunky rounded exaggerated cartoon proportions, threatening but cartoon and not gory, 2D cel-shaded comic book game art in the style of Borderlands 2. The creature fills about 85 percent of the frame, is centred, and its silhouette is one solid shape with no see-through gap. Plain pure white background, no text, no letters, no numbers, no labels, no border, no frame, no watermark, no drop shadow, no gradients, no realistic shading, no 3d render, no isometric perspective, no front view, no face-on view, no three-quarter view, no tilted pose, no legs, no limbs, no thin outline
```

### Prompt 2 — phase 3 "Bankruptcy" variant

Generate **after** prompt 1 is accepted, and attach/describe the accepted image so the body matches. Only the description changes:

```
A single top-down arena roguelite boss creature drawn side-on, one solid legless blob body: the same colossal armoured iron slug tycoon, now broken and furious: the rusted bank vault on its back is burst open with its door torn off, a glowing molten gold core blazing inside it, the iron battering ram plate on its front is cracked and half shattered, bent rivets and torn metal edges, gold coins spilling from the cracks, its top hat crumpled, a wide snarling mouth of gold teeth, dark gunmetal and rust brown hide with one saturated hero colour of bright molten gold. No legs, no feet, no arms, no hands, no tail and no separate limbs of any kind, just the body, exactly like a legless blob monster. The creature faces to the right: its body lies horizontally and points to the right-hand side of the frame, the cracked plate is on the right-hand end of the body, and its two big furious cartoon eyes and mouth sit on the right-hand side of its head, looking right. Seen from above at a steep, almost directly overhead angle. Every shape is bordered by a very thick, uniform black ink outline, about one tenth of the creature's width thick, roughly 90 pixels on the 1024-pixel image. Flat solid muted dusty frontier colour fills with only one flat darker tone used for shading, plus thin black hatch strokes and crack lines inside the hide and the plates. Small glow accent on the gold core only. Chunky rounded exaggerated cartoon proportions, threatening but cartoon and not gory, 2D cel-shaded comic book game art in the style of Borderlands 2. The creature fills about 85 percent of the frame, is centred, one solid silhouette with no see-through gap. Plain pure white background, no text, no letters, no numbers, no border, no frame, no watermark, no drop shadow, no gradients, no realistic shading, no 3d render, no isometric perspective, no front view, no face-on view, no three-quarter view, no legs, no limbs, no thin outline
```

### Prompt 3 — projectile and prop sheet (2×2)

```
A sprite sheet of four separate 2D top-down arena roguelite boss attack props arranged in a clean 2 by 2 grid with even spacing and identical cell sizes, each completely separated from the others with plain empty space between them and nothing overlapping or touching. Every prop has a completely different silhouette, no two alike. The four are: a single thick tarnished gold coin seen flat from above with a dollar-like skull emblem stamped on it, a small heavy rusted iron safe with a brass dial and a lit fuse on top, a low cracked mound of desert sand with small rocks and dust puffs as if something is burrowing under it, and a small fat bulging gold-coloured money sack tied with rope. Heavy inked black outline around every shape, about one tenth of each object's width thick, completely flat solid colour fills with only one flat darker tone used for shading, thin black hatch strokes inside each shape, muted dusty frontier palette with tarnished gold as the hero colour, chunky exaggerated cartoon proportions, 2D cel-shaded comic book game art in the style of Borderlands 2. Plain pure white background, no text, no letters, no numbers, no labels, no UI chrome, no border, no frame, no watermark, no drop shadow, no gradients, no realistic shading, no 3d render, no isometric perspective, square 1:1.
```

Coin and safe are projectiles (draw small, ~24 px and ~48 px); the mound is the Burrow telegraph; the sack is optional art for the Debt Collector adds.

---

## 6. Decisions for you

1. **Theme/name.** The Vault Baron ties the boss to the money theme. If the final boss should be something else (e.g. a sand worm or a scrap war machine), the phase structure and attacks survive a re-skin; only names and art change.
2. **Stage bosses.** Should the stage-1–3 bosses also get the brain, running a phase-1-only subset (Coin Spray + Ram)? It would make them more than "an enemy with shotguns" for little extra code. Not in this plan's scope by default.
3. **Margin Call.** The closing ring is the one attack that needs an arena-wide hazard. Cut it if it feels unfair to ranged builds; Gold Rush and Golden Beam carry phase 3 alone.
