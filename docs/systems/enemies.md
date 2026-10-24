# Enemies

## Purpose
- Represent hostile actors (AI-controlled) with health, stats, weapons and movement behaviour.

## Key scripts / scenes
- `src/Scripts/Enemy.gd` (`Enemy` class)
- `src/Systems/Enemy.tscn`, `src/Systems/EnemyBoss.tscn` (boss variant), `src/Systems/EnemyBulwark.tscn`, `src/Systems/EnemyGunner.tscn` and `src/Systems/EnemySlimeling.tscn` (roster variants) — see "The roster" below
- Movement behaviours under `Scenes/` or `Systems/` (referenced as `MovementBehaviour`).
- `src/Systems/movement/bahaviour/charge_movement_behaviour.gd` (`ChargeMovementBehaviour`) — the charger: walk in, telegraph, then charge along a locked direction. See "Charging" below.
- `src/Systems/damage/area_burst_on_enter.gd` (`AreaBurstOnEnter`) — an optional enemy child that damages everything standing in its radius when the enemy dies.
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
| Grunt | `src/Systems/Enemy.tscn` | The baseline. Walks at you and hurts on touch. |
| Bulwark | `src/Systems/EnemyBulwark.tscn` | A slow wall. Three times the grunt's health at a third of its speed, and it still hurts on touch. |
| Gunner | `src/Systems/EnemyGunner.tscn` | Shoots from a fixed distance. No contact damage: its threat arrives as projectiles, so it asks you to break line of sight or close the gap. |
| Slimeling | `src/Systems/EnemySlimeling.tscn` | Dies into three smaller copies of itself. Frailer than the grunt and just as fast, so the fight is the second and third wave of bodies rather than the first one. |
| Boss | `src/Systems/EnemyBoss.tscn` | The loop's boss, with a weapon loadout of its own. See `docs/systems/spawners.md`. |

Adding a type is therefore: copy `src/Systems/Enemy.tscn`, point the sprite at new art, change the stats, and add a row to the spawn table in `src/Scenes/Game.tscn`. No script changes, because the behaviour is duck-typed against the enemy.

The Gunner is the row that proves an enemy can be a *ranged* threat: it is the basic enemy with `contact_weapon` cleared, the shared `Pistol.tres` placed in its `WeaponHolder`, and `ChaseDistanceMovementBehaviour` walking it in to a firing distance instead of onto the player. Its pistol targets whatever is in the `damageable` group that its holder is not grouped with, which is the player: the `enemies` group is what keeps an enemy from shooting its own kind.

The numbers are `.tscn` data, so they are rebalanced without touching a script. That is also why `test/Systems/test_enemy_variant_loadouts.gd` compares one enemy against another instead of against a literal.

### The stats are the whole dictionary
`Stats.stats` is exported as a dictionary, and a scene that overrides it **replaces** the default dictionary rather than merging into it. A variant that sets only the three stats it cares about therefore loses `movement_speed` and `damage` along with everything else, and the enemy never moves. Every enemy scene writes the full dictionary out and changes the entries it wants.

### The collider has to match the art
The body collider is a circle around the drawn creature, so it scales with the sprite. A bigger sprite wearing the old collider is a wall the player walks straight through; a collider far larger than the art is a wall the player cannot touch. The roster's enemies share the 100x100 canvas the asset table specifies, so they share the basic enemy's collider.

### The art is a 100x100 canvas
Every roster sprite is a 100x100 PNG with the creature filling about 85% of its longest side, and the scene draws it at `scale 1`. That is what makes the collider comparison meaningful: the test reads the texture's width, not the drawn width.

The roster's art was generated as one six-creature sheet and cut up afterwards. `test/tools/extract_enemy_sprites.gd` does the cutting: it flood-fills the white backdrop in from the sheet's border, splits what is left into connected components and writes each one out as a 100x100 PNG. The grid in a generated sheet is never clean, so slicing it into equal rectangles cuts creatures in half.

The Gunner and the Slimeling were delivered as single images instead of being cut from the sheet, so their cells are not listed in the extractor's `CELLS` table — running the tool must not overwrite them. Each is normalised to the same 100x100 / 85%-fill canvas before it is saved into `src/Assets/enemies/`, and the untouched source is kept at `docs/plans/images/enemies/gunner.png` and `docs/plans/images/enemies/jelly-splitter.png`. A sprite left at its delivered resolution would draw at the wrong size against the rest of the roster, because `Sprite2D` draws a texture at its pixel size.

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

## Dependencies
- `Stats` (child), `Health`, `WeaponHolder`, `ItemHolder`, `EventManager`, MovementBehaviour.

## Known limitations / TODOs
- The roster is four types deep: the grunt, the Bulwark, the Gunner and the Slimeling. The rest of the variety plan - a charger, a bomber - is not built yet.
- Death handling uses animation_finished connect with a short anonymous callback — works but can be fragile if animations change. `_die` is re-entrancy guarded, so a duplicate `on_death` cannot restart the animation, but the callback still depends on the animation being named `death`.
- `StageManager` and `EnemySpawner` end a stage on `Nodes/Enemies.get_child_count() == 0`, so a corpse still holds the stage open for the remainder of its death animation.
- The charger's telegraph plays the shared `idle` animation. There is no windup clip, and `src/animations/enemy_animations.res` is shared with the player, so a charger needs its own animation library before it can telegraph with one.
- Behavior implementation details are delegated to movement behaviour nodes; those should be inspected if modifying AI.
