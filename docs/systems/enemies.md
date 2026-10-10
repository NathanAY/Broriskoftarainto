# Enemies

Purpose
- Represent hostile actors (AI-controlled) with health, stats, weapons and movement behaviour.

Key scripts / scenes
- `src/Scripts/Enemy.gd` (`Enemy` class)
- `src/Systems/Enemy.tscn` and `src/Systems/EnemyBoss.tscn` (boss variant)
- Movement behaviours under `Scenes/` or `Systems/` (referenced as `MovementBehaviour`).
- Visual managers live as children: `HitFlashManager`, `TextureBurstManager` and `ParticleEffectManager`. All three are shared with the Player and documented together in `docs/systems/effects.md`.

Data flow
- Inputs: spawn position and modifiers from spawners; target set by spawner or StageManager.
- Processing: `behaviour.process_movement(self, delta)` computes the desired velocity (also flips the `sprite` via `creature_self.sprite.flip_h`); `Enemy._physics_process` then adds a soft separation force (crowd spacing) and calls `move_and_slide()`. Weapons in `WeaponHolder` fire based on their logic.
- Crowding: enemies do NOT hard-collide with each other (`collision_mask` includes only walls). Instead `_separation_force()` repels overlapping neighbours softly, so large groups spread naturally instead of being shoved side to side by physics.
- Outputs: on death, subscribe to event manager `on_death` handlers; play the death animation and free the node when it finishes.
- Leaving the world on death: `Enemy._die` is re-entrancy guarded (`if not _alive: return`) and, because the corpse stays in the tree for the whole ~0.7s death animation, it also
  - leaves the `enemies` and `damageable` groups, so target selectors stop acquiring it (`lowest_hp` used to actively prefer a corpse with health <= 0),
  - disables both colliders: the body `CollisionShape2D` and `Hitbox/CollisionShape2D`. The hitbox is an `Area2D`, so it outlives the body shape going away and the melee sweep's area raycast would otherwise keep resolving the corpse through it.
  - `Health.apply_damage` then rejects anything that still reaches the corpse, so no hit effect plays on it.

Damage taken
- `Health.apply_damage(damage_context) -> bool` (`src/Systems/damage/health.gd`) is the single entry point for damage and the only place the dead check lives. It latches `Health.is_dead` on death, so a dying enemy is neither damaged nor heard from again.
- Returning `false` means "the hit did not land": callers must skip their attacker-side events (`after_deal_damage`, `on_hit`, `on_kill`) for a rejected hit, or kill rewards pay out once per corpse. See `docs/systems/event_manager.md`.

Dependencies
- `Stats` (child), `Health`, `WeaponHolder`, `ItemHolder`, `EventManager`, MovementBehaviour.

Known limitations / TODOs
- Death handling uses animation_finished connect with a short anonymous callback — works but can be fragile if animations change. `_die` is re-entrancy guarded, so a duplicate `on_death` cannot restart the animation, but the callback still depends on the animation being named `death`.
- `StageManager` and `EnemySpawner` end a stage on `Nodes/Enemies.get_child_count() == 0`, so a corpse still holds the stage open for the remainder of its death animation.
- Behavior implementation details are delegated to movement behaviour nodes; those should be inspected if modifying AI.
