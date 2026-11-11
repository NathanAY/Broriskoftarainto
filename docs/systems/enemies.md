# Enemies

## Purpose
- Represent hostile actors (AI-controlled) with health, stats, weapons and movement behaviour.

## Key scripts / scenes
- `src/Scripts/Enemy.gd` (`Enemy` class)
- `src/Systems/enemies/Enemy.tscn`, `src/Systems/enemies/EnemyBoss.tscn` (boss variant), `src/Systems/enemies/EnemyBulwark.tscn`, `src/Systems/enemies/EnemyGunner.tscn`, `src/Systems/enemies/EnemySlimeling.tscn`, `src/Systems/enemies/EnemyLancer.tscn`, `src/Systems/enemies/EnemyToadstinker.tscn`, `src/Systems/enemies/EnemyBlink.tscn`, `src/Systems/enemies/EnemyShieldbearer.tscn` and `src/Systems/enemies/EnemySwarmer.tscn` (roster variants) — see "The roster" below
- Movement behaviours under `Scenes/` or `Systems/` (referenced as `MovementBehaviour`).
- `src/Systems/movement/bahaviour/charge_movement_behaviour.gd` (`ChargeMovementBehaviour`) — the charger: walk in, telegraph, then charge along a locked direction. See "Charging" below.
- `src/Systems/movement/bahaviour/blink_movement_behaviour.gd` (`BlinkMovementBehaviour`) — chases, then teleports to a ring around its target. See "Blinking" below.
- `src/Systems/damage/area_burst_on_enter.gd` (`AreaBurstOnEnter`) — an optional enemy child that damages everything standing in its radius when the enemy dies.
- `src/Systems/damage/front_shield.gd` (`FrontShield`) — an optional enemy child that ignores hits landing on its front arc. See "Front shield" below.
- `src/Systems/enemies/split_on_death.gd` (`SplitOnDeath`) — an optional enemy child that spawns smaller copies of the enemy when it dies. See "Splitting" below.
- Visual managers live as children: `HitFlashManager`, `TextureBurstManager` and `ParticleEffectManager`. All three are shared with the Player and documented together in `docs/systems/effects.md`.

## Data flow
- Inputs: spawn position and modifiers from spawners; target set by spawner or StageManager.
- Processing: `behaviour.process_movement(self, delta)` computes the desired velocity (also flips the `sprite` via `creature_self.sprite.flip_h`); `Enemy._physics_process` then adds a soft separation force (crowd spacing) and calls `move_and_slide()`. Weapons in `WeaponHolder` fire based on their logic.
- Crowding: enemies do NOT hard-collide with each other (`collision_mask` includes only walls). Instead `_separation_force()` repels overlapping neighbours softly, so large groups spread naturally instead of being shoved side to side by physics.
- Outputs: on death, subscribe to event manager `on_death` handlers; play the death animation and free the node when it finishes.
- Leaving the world on death: `Enemy._die` is re-entrancy guarded (`if not _alive: return`) and, because the corpse stays in the tree for the whole ~0.7s death animation, it also
  - leaves the `enemies` and `damageable` groups, so target selectors stop acquiring it (`lowest_hp` used to actively prefer a corpse with health <= 0),
  - disables both colliders: the body `CollisionShape2D` and `Hitbox/CollisionShape2D`. The hitbox is an `Area2D`, so it outlives the body shape going away and the melee sweep's area raycast would otherwise keep resolving the corpse through it.
  - disarms its weapons. A weapon's firing timer lives on the `WeaponHolder` and keeps ticking after `_physics_process` returns early, so without this a ranged enemy fired one last shot out of its own corpse.
  - `Health.apply_damage` then rejects anything that still reaches the corpse, so no hit effect plays on it.

## Damage taken
- `Health.apply_damage(damage_context) -> bool` (`src/Systems/damage/health.gd`) is the single entry point for damage and the only place the dead check lives. It latches `Health.is_dead` on death, so a dying enemy is neither damaged nor heard from again.
- Returning `false` means "the hit did not land": callers must skip their attacker-side events (`after_deal_damage`, `on_hit`, `on_kill`) for a rejected hit, or kill rewards pay out once per corpse. See `docs/systems/event_manager.md`.

## An enemy is configured, not just a scene
One export on `Enemy` is what lets one scene stand in for several enemy types. Everything else about an enemy is still its `.tscn`.

- **`contact_weapon`** — the weapon that hurts on touch. It defaults to `Thorns`, so every existing enemy, debug scenario and test fixture keeps working untouched, and it is armed only when it is non-null. An enemy that should not hurt on touch clears it and gets its threat from something else (a ranged weapon, a death burst). Thorns hooks the body's own `Hitbox`, so the weapon and the hitbox travel together.

Everything an enemy does *not* share lives in an optional child node, so `Enemy.gd` stays the code every enemy needs: a splitter carries a `SplitOnDeath` node, a bomber carries an `AreaBurstOnEnter` node, and an enemy that does neither carries neither.

## The roster
An enemy type is a **scene**, not a class. `Enemy.gd` is the script every enemy runs, and everything that makes one type different from another lives in its `.tscn`: the sprite, the stats, the movement behaviour, and the optional child nodes that give it its trick.

| Type | Scene | Threat shape |
|---|---|---|
| Grunt | `src/Systems/enemies/Enemy.tscn` | The baseline. Walks at you and hurts on touch. |
| Bulwark | `src/Systems/enemies/EnemyBulwark.tscn` | A slow wall. Three times the grunt's health at a third of its speed, and it still hurts on touch. |
| Gunner | `src/Systems/enemies/EnemyGunner.tscn` | Shoots from a fixed distance. No contact damage: its threat arrives as projectiles, so it asks you to break line of sight or close the gap. |
| Slimeling | `src/Systems/enemies/EnemySlimeling.tscn` | Dies into three smaller copies of itself. Frailer than the grunt and just as fast, so the fight is the second and third wave of bodies rather than the first one. |
| Lancer | `src/Systems/enemies/EnemyLancer.tscn` | Walks in, telegraphs, then charges along the direction it locked. Hurts on touch, so the charge is what connects. |
| Toadstinker | `src/Systems/enemies/EnemyToadstinker.tscn` | Arms no weapon and detonates when it dies. Frailer and a little faster than the grunt: it wants to die next to you, and killing it at range is how you decline. |
| Blink | `src/Systems/enemies/EnemyBlink.tscn` | Chases, then reappears in a ring around you every few seconds. It keeps the contact weapon, so the repositioning is the threat. |
| Shieldbearer | `src/Systems/enemies/EnemyShieldbearer.tscn` | Turns away every hit that lands on its front arc. Tougher and slower than the grunt; you have to get behind it. |
| Swarmer | `src/Systems/enemies/EnemySwarmer.tscn` | Tiny, one hit point, faster than the grunt, and arrives in packs of eight. The pack is the threat, not any one body. |
| Boss | `src/Systems/enemies/EnemyBoss.tscn` | The loop's boss, with a weapon loadout of its own. See `docs/systems/spawners.md`. |

Adding a type is therefore: copy `src/Systems/enemies/Enemy.tscn`, point the sprite at new art, change the stats, and add a row to the spawn table in `src/Scenes/Game.tscn`. No script changes, because the behaviour is duck-typed against the enemy.

The Gunner is the row that proves an enemy can be a *ranged* threat: it is the basic enemy with `contact_weapon` cleared, the shared `Pistol.tres` placed in its `WeaponHolder`, and `ChaseDistanceMovementBehaviour` walking it in to a firing distance instead of onto the player. Its pistol targets whatever is in the `damageable` group that its holder is not grouped with, which is the player: the `enemies` group is what keeps an enemy from shooting its own kind.

The numbers are `.tscn` data, so they are rebalanced without touching a script. That is also why `test/Systems/test_enemy_variant_loadouts.gd` compares one enemy against another instead of against a literal.

### The stats are the whole dictionary
`Stats.stats` is exported as a dictionary, and a scene that overrides it **replaces** the default dictionary rather than merging into it. A variant that sets only the three stats it cares about therefore loses `movement_speed` and `damage` along with everything else, and the enemy never moves. Every enemy scene writes the full dictionary out and changes the entries it wants.

### The collider has to match the art
The body collider is a circle around the drawn creature, so it scales with the sprite. A bigger sprite wearing the old collider is a wall the player walks straight through; a collider far larger than the art is a wall the player cannot touch. The roster's enemies share the 100x100 canvas the asset table specifies, so they share the basic enemy's collider.

### The art is drawn on a 100x100 canvas

Every roster sprite is **drawn** on a 100x100 square with the creature filling about 85% of its longest side. The file itself may be authored larger — `src/Assets/enemies/lancer.png` is 512x512 — and `Enemy.art_width` (default `AssetSizes.ENEMY_SPRITE`) plus `Enemy._fit_sprite()` scale it onto the canvas. The fit is written on the `Node2D` container, not on the sprite, because the shared `idle` and `move` animations animate `Sprite2D:scale` and would overwrite it; `Enemy.drawn_width()` folds both scales together. That is what makes the collider comparison meaningful: the test compares the collider to the **drawn** width, not to the file's width.

The roster's art was generated as one six-creature sheet and cut up afterwards. `test/tools/extract_enemy_sprites.gd` does the cutting: it flood-fills the white backdrop in from the sheet's border, splits what is left into connected components and writes each one out as a 100x100 PNG. The grid in a generated sheet is never clean, so slicing it into equal rectangles cuts creatures in half.

The Gunner, the Slimeling and the Lancer were delivered as single images instead of being cut from the sheet, so their cells are not listed in the extractor's `CELLS` table — running the tool must not overwrite them. The Gunner and the Slimeling are normalised to the 100x100 / 85%-fill canvas before they are saved into `src/Assets/enemies/`, and the untouched source for those two is kept at `docs/plans/images/enemies/gunner.png` and `docs/plans/images/enemies/jelly-splitter.png`. The Lancer keeps a 512x512 source at the same proportions. `Sprite2D` draws a texture at its pixel size, so a file left at its delivered resolution used to draw at the wrong size against the rest of the roster; `Enemy._fit_sprite()` is what now makes the file resolution irrelevant.

## Splitting
`SplitOnDeath` is an optional child on an enemy scene. It subscribes to the owner's `on_death` and spawns smaller copies of the enemy when it dies.

- **`split_scene`** — the scene the children are built from. Empty means the owner's *own* scene, which is the usual case: a scene cannot point at itself, Godot refuses the cyclic reference, so the fallback is the only way a splitter can split into copies of itself.
- **`split_count`** — how many children the split produces.
- **`split_scale`** — multiplies the children's health, movement speed and damage stat, and shrinks their collider and sprite.

A spawned child is told not to split again (`suppressed`), or the stage would never end: a stage ends when the enemy container is empty.

Two ordering rules the split path depends on:

- The children's stats are scaled **before** they enter the tree, because `Health._ready()` reads the health stat once and never looks again.
- The collider shape is a **shared sub-resource** of the scene, so it is duplicated before its radius is changed. Shrinking it in place would shrink every instance of that enemy scene.

The children are added with `call_deferred`, into the same container the spawner uses (`Nodes/Enemies`), because the death event fires from inside `Health.apply_damage` and touching the tree from a physics callback is a flushing error. `StageManager` ends a stage on `Nodes/Enemies.get_child_count() == 0`, so the children hold the stage open until they are dead too.

The shipped splitter is the Slimeling: three children at `split_scale` 0.6, with no `split_scene`, so every mini is another Slimeling. Its art at `src/Assets/enemies/slimeling.png` is a fully opaque green jelly, normalised to the roster's 100x100 / 85%-fill canvas from the delivered source at `docs/plans/images/enemies/jelly-splitter.png`. The sheet's jelly cell is not used because it is translucent, and a see-through enemy reads as a hole in the arena (`docs/visual_style.md`).

## Death burst
`AreaBurstOnEnter` is an optional child on an enemy scene. It subscribes to the owner's `on_death` and, when the enemy dies, damages everything in the `damageable` group inside its radius, then detaches itself.

It is a group scan rather than a physics overlap: the enemy that died has just left the `damageable` group, so the corpse is not a target and everything else standing in the radius is. That includes other enemies.

## Charging
`ChargeMovementBehaviour` is a movement behaviour, so it is a node on the enemy scene like any other. It runs four states on a timer:

| State | What it does |
|---|---|
| `APPROACH` | Walks towards the target until it is within `stop_distance` |
| `WINDUP` | Stands still and faces the player |
| `CHARGE` | Drives along the direction locked at the end of the windup |
| `RECOVER` | Stands still, then goes back to `APPROACH` |

Two things about it are the mechanic rather than the tuning:

- **The direction is locked when the windup ends** and is not re-aimed during the charge. A charge that tracks the player is just a fast walk, and the player would have no way to dodge it.
- **The charge speed is a temporary `Stats` boost, not a velocity.** `Enemy._physics_process` clamps the velocity to `stats.get_movement_speed_px()` after the behaviour has run, so a behaviour that set `velocity = direction * 400` would be clamped straight back to walk speed. The boost is a `Stats` modifier, so it comes off again at the start of `RECOVER` — and on death, which the behaviour watches for on the enemy's own event bus.

## Blinking
`BlinkMovementBehaviour` is a movement behaviour node, like the charger. It chases normally, and every `blink_interval` it teleports to a random point in a ring around its target:

- **`blink_interval`** — seconds between blinks.
- **`blink_radius`** / **`min_blink_distance`** — the ring the creature reappears in, in pixels.
- **`fade_time`** — the reappearance fade.

The blink clears the velocity, so the creature does not carry its old heading into the new spot. The fade runs on the `Node2D` container rather than the sprite, because `HitFlashManager` tweens the sprite's own modulate and would wipe a fade placed there.

The shipped Blink uses the shared default sprite while its own art is pending; the behaviour is what the row adds.

## Front shield
`FrontShield` is an optional child on an enemy scene. It subscribes to the owner's `before_take_damage` and zeroes `final_amount` when `DamageContext.source` sits inside a frontal arc of the sprite's facing.

- **`half_arc_degrees`** — half the width of the protected arc, measured from the facing direction. The shipped Shieldbearer uses 70°, which leaves its sides and rear open.
- The facing is the sprite's `flip_h`, which every movement behaviour already writes. A source with no position, or the owner itself, is not blocked.
- It is a targeting puzzle rather than a damage wall: every other roster type asks you to move, and this one asks you to move *around*.

## Packs and elites
Both are spawner rows rather than enemy scripts, so they apply to any scene:

- **`pack_size`** on `EnemySpawnEntry` — one draw spawns this many copies of the row's scene. The Swarmer row uses 8. A pack overrides the spawner's ordinary group size for that draw, and the spawn budget still caps it.
- **`elite_min_loop`** and the multipliers on `EnemySpawnEntry` — from that loop on, the row spawns the same scene with multiplied health and damage and a tint on its `Node2D` container. Every shipped row turns elite at loop 3. The tint lives on `Node2D` so the hit flash cannot reset it.

## Dependencies
- `Stats` (child), `Health`, `WeaponHolder`, `ItemHolder`, `EventManager`, MovementBehaviour.

## Known limitations / TODOs
- The roster's newer types use the shared default enemy sprite until their own art arrives: `src/Systems/enemies/EnemyShieldbearer.tscn` and `src/Systems/enemies/EnemySwarmer.tscn` all point at `src/Assets/enemies/spitter.png`. Replace the texture on each scene when the art ships. The Lancer now has its own `src/Assets/enemies/lancer.png`, the Blink its own `src/Assets/enemies/blink.png` and the Toadstinker its own `src/Assets/enemies/toadstinker.png` (full-resolution 1024px art, generated per `docs/visual_style.md`). The Toadstinker is deliberately larger than the rest of the roster: its scene sets `art_width = 260` and scales its colliders to match.
- The Swarmer is drawn small on purpose: its scene sets `art_width = 55` (the old 0.55 scale of the shared canvas) and keeps a smaller collider, so the collider test reads the drawn width rather than the texture width.
- Death handling uses animation_finished connect with a short anonymous callback — works but can be fragile if animations change. `_die` is re-entrancy guarded, so a duplicate `on_death` cannot restart the animation, but the callback still depends on the animation being named `death`.
- `StageManager` and `EnemySpawner` end a stage on `Nodes/Enemies.get_child_count() == 0`, so a corpse still holds the stage open for the remainder of its death animation.
- The charger's telegraph plays the shared `idle` animation. There is no windup clip, and `src/animations/enemy_animations.res` is shared with the player, so a charger needs its own animation library before it can telegraph with one.
- Behavior implementation details are delegated to movement behaviour nodes; those should be inspected if modifying AI.
