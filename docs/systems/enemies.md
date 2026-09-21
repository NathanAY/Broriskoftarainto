# Enemies

Purpose
- Represent hostile actors (AI-controlled) with health, stats, weapons and movement behaviour.

Key scripts / scenes
- `Scripts/Enemy.gd` (`Enemy` class)
- `Systems/Enemy.tscn` and `Systems/EnemyBoss.tscn` (boss variant)
- Movement behaviours under `Scenes/` or `Systems/` (referenced as `MovementBehaviour`).
- Visual managers live as children (see `Scenes/effects/`): `HitFlashManager` (damage flash via `before_take_damage`), `TextureBurstManager` (death burst via `on_death`), `Scenes/particles/ParticleEffectManager` (hit particles via `after_take_damage`).

Data flow
- Inputs: spawn position and modifiers from spawners; target set by spawner or StageManager.
- Processing: `behaviour.process_movement(self, delta)` computes the desired velocity (also flips the `sprite` via `creature_self.sprite.flip_h`); `Enemy._physics_process` then adds a soft separation force (crowd spacing) and calls `move_and_slide()`. Weapons in `WeaponHolder` fire based on their logic.
- Crowding: enemies do NOT hard-collide with each other (`collision_mask` includes only walls). Instead `_separation_force()` repels overlapping neighbours softly, so large groups spread naturally instead of being shoved side to side by physics.
- Outputs: on death, subscribe to event manager `on_death` handlers; remove collision and play death animation.

Dependencies
- `Stats` (child), `Health`, `WeaponHolder`, `ItemHolder`, `EventManager`, MovementBehaviour.

Known limitations / TODOs
- Death handling uses animation_finished connect with a short anonymous callback — works but can be fragile if animations change.
- Behavior implementation details are delegated to movement behaviour nodes; those should be inspected if modifying AI.
