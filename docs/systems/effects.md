# Effects

Purpose
- Every visual the game spawns to answer "what just happened" — impact sparks, blast fireballs, damage flashes, death shards — and the shared rules for authoring one.

Key scripts / scenes
- Two families, and the split is deliberate rather than historical:
  - **Manager-attached** (`src/Scenes/effects/`, `src/Scenes/particles/particle_effect_manager.gd`) — long-lived nodes that live as children of an *actor*, subscribe to that actor's `EventManager`, and spawn something per event. `HitFlashManager`, `TextureBurstManager`, `ParticleEffectManager`.
  - **One-shot emitters** (`src/Scenes/particles/area_damage_burst.tscn`, `src/Scenes/particles/explosion_burst.tscn`) — stateless scenes spawned *by* the gameplay node that caused the event, parented to it, and self-freeing.
- Nothing in either family contains combat logic. A manager reacts to an event that already happened; it never decides whether something happened.

Data flow
- Triggering: all three managers subscribe on `EventManager` events (`before_take_damage`, `after_take_damage`, `on_death`), so they are downstream of `Health` and inherit its dead-check for free — a corpse plays no further effects. See `docs/systems/event_manager.md`.
- One-shot emitters are called directly by the node whose behaviour they depict (`area_weapon.gd`, `explosion.gd`), because the thing they show is a property of *that* node's own radius and position.
- Cleanup: managers parent their spawn to the scene and connect `finished` / a lifetime tween to `queue_free`. A one-shot emitter's parent outlives it.

## The three rules that decide whether an effect works

These are the traps. Each one cost a rebuild to find, and none of them is visible from reading a `.tscn`.

### 1. The drawn size must come from the same number the damage was measured against

This is the rule the whole folder exists to enforce. An effect that authors its own size, or reads a second radius, drifts from the gameplay the moment that gameplay is retuned — and the player is the only one who can tell.

- `area_damage_burst.gd` takes `radius` from `BaseWeapon.get_range_px()`, the same conversion the `AllTargetsInRangeSelector` measures against.
- `explosion_burst.gd` takes `radius` from `Explosion.get_radius_px()`, which is also what the `CollisionShape2D` takes — and which already has `area_size_multiplier` folded in. So a Soldier's `+30%` blast looks 30% bigger, not just hits 30% bigger.
- Both set these **before** `add_child`, because `_ready` is what applies them, and they are added to the scene before `global_position` is written: an unparented `Node2D` has no parent transform to compose, so writing `global_position` first would store the world position as a *local* one and land the effect an offset away.

**Do not retarget a `ParticleProcessMaterial` in place.** A `PackedScene`'s sub-resources belong to the scene, not the instance, so writing the shared one leaks one weapon's range into the next explosion's. `area_damage_burst.gd` duplicates each material first; `explosion_burst.gd` avoids the problem entirely by scaling the *node*.

### 2. An emitter only obeys its parent if `local_coords = true`

The default is **`false`**, which simulates particles in world space and makes the emitter ignore its own parent's transform completely. A node whose `scale` is set correctly in `_ready` can therefore draw every particle at the size it was authored at — the scale is real and has no effect.

`explosion_burst.gd` scales itself by `radius / ExplosionBurst.BASE_RADIUS` and relies on this, which is why every layer in that scene sets `local_coords = true`. `test/scenes/effects/test_explosion_burst.gd` asserts it on each layer: an earlier version of that suite checked `burst.scale` alone and passed while the bug was live, because the value it read was correct and the particles ignored it.

### 3. The shipped particle art cannot be tinted, only replaced

`src/Assets/particles/particle_1.png` .. `particle_27.png` are drawn in the project's Borderlands style, whose defining feature is a heavy inked black outline — **53-72% near-black pixels** across the set, measured. A particle emitter tints its texture, and a tint cannot separate ink from fill: multiplying black and white by the same colour yields the same dark colour, so a fire layer built on those textures renders as a **black blob** regardless of its gradient. Additive blending does not rescue it, because additive *adds* the outline rather than discarding it.

This is a property of the art style, not of the emitters, and it does not affect effects that tint toward the art's own palette — the hit sparks and the Death Aura ring use the outlined textures as intended.

`test/tools/make_soft_particles.gd` generates the four ink-free sprites the explosion uses (`particle_glow`, `particle_smoke`, `particle_spark`, `particle_shard`) as pure luminance falloff on transparency. Regenerate rather than hand-editing:

```
godot --headless --path . -s res://test/tools/make_soft_particles.gd
```

Two details in that generator are load-bearing, not taste:

- **Alpha is not one profile for all four.** The additive sprites carry their shape in brightness and want a flat-alpha interior, or the edge shows as a hard disc. `particle_smoke.png` needs alpha that *decays with luminance*, or the noise in its radius turns an opaque region into a lumpy opaque silhouette — a flat grey ball at the centre of every blast.
- **The generator is seeded and deterministic.** Regenerating produces byte-identical PNGs, so a sprite never shifts under a committed scene.

## The explosion blast (`explosion.gd`, `explosion_burst.tscn`)

- `Explosion` used to draw its own visual: a `_draw()` painting one flat, half-transparent white circle at the blast radius, fading over the damage window. It read as a placeholder rather than as a blast — no shape, no direction, no aftermath. The `_draw()` is gone.
- Five layers, in draw order: `Shockwave` (debris thrown out to the blast edge — the layer that tells the player how far it reached), `Smoke`, `Fireball`, `Sparks`, `Flash`. The four hot layers share a `CanvasItemMaterial` with `blend_mode = 1` (add); `Smoke` blends normally because it is meant to be dark, and it is drawn *under* `Fireball` for that reason — on top, it punches a flat grey hole through the middle of the fire. Note `GPUParticles2D` has no `blend_mode` property of its own; additive is a material.
- **The node outlives its damage window.** `duration` (0.15s) is when the `CollisionShape2D` is switched **off**; `visual_duration` is when the node frees itself, and it exists only because it is the burst's parent. Splitting the two is what stops a blast from hurting things that walk into the smoke afterwards. `visual_duration` is floored by `ExplosionBurst.get_longest_lifetime()`, so retuning a layer's lifetime in the editor cannot leave the tail truncated.
- Spawned by `explosive_shot_modifier.gd`, `bomb_on_hit_modifier.gd`, and `spawner_modifier.gd`.

## The `AreaWeapon` aura ring (`area_damage_burst.tscn`)

- An aura has no impact point and no chosen target, so its visual is a ring rather than a hit spark: shards thrown outward that arrive at the aura's edge exactly as they die, plus a short flash where the pulse was born. `area_weapon.gd` spawns it per tick at `sprite_node.global_position`, because that sprite is what the selector measures from (and it orbits the holder, so the aura centre is offset from the character).
- `AreaDamageBurst.START_FRACTION` (0.55) is where along the outward leg the shards start. Below 1 so they travel outward as they fade; at 1 they would sit on the damage edge from the first frame and read as a static ring.
- Speed is derived from radius as well as position — a longer aura has to take longer to cross, or its shards reach the edge at full brightness and keep going, drawing damage past what was hit.

## Actor-attached managers

| Manager | Subscribes to | Spawns | Notes |
| --- | --- | --- | --- |
| `HitFlashManager` | `before_take_damage` | a sprite `modulate` tween | Colour keyed to damage type/tags: poison=green, melee=red, explosion=yellow, ranged=white. |
| `ParticleEffectManager` | `after_take_damage` | `directional_hit_particles.tscn` | Amount scales with `target_take_persent_damage`, so a bigger hit throws more sparks. Rotated to point away from `ctx.source`. |
| `TextureBurstManager` | `on_death` | `TextureBurst.tscn` | Slices the death frame into 4x4 `Sprite2D` shards; strength from the killing blow, speed from overkill. |

Each reads `get_parent().get_node_or_null("EventManager")`, so all three are only as reliable as that child existing on the owner.

## Visual checks

Tests assert structure, not looks — no suite can tell you a blast reads as fire rather than as a black blob. Render one:

```
.\run_scene_shot.bat res://test/tools/explosion_preview.tscn res://explosion_shot.png 12
```

The `frames` argument is the third parameter and matters: the shot tool's built-in settle lands on the target's *first* frame, which for a sub-second particle burst is the least representative moment available. `test/tools/explosion_preview.tscn` spawns a fresh row of blasts every few frames at three radii, so any frame count leaves blasts at a spread of ages on screen at once.

## Known limitations / TODOs

- No pooling. `Explosion` holds a five-layer burst for ~0.9s and `AreaDamageBurst` runs per weapon tick, so every spawn is a fresh node plus its materials. Fine at current rates; this is the first thing to pool if effects ever stack up.
- The explosion's sprites break from the project's art style on purpose (rule 3). A Borderlands-inked explosion needs a shader or a re-think of the art direction, not a different gradient.
- `HitFlashManager` and `ParticleEffectManager` scale their effect off damage taken; there is no screen shake, hit-stop, or camera punch anywhere in the project, and no impact variety — every hit on a given weapon looks the same.
- `particle_effect_manager.gd` uses `@onready` to reach its parent's `EventManager`, so it reads as `null` while detached. It is only ever used as a scene child, so this has not been fixed.