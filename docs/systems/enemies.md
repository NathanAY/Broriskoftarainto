# Enemies

Purpose
- Represent hostile actors (AI-controlled) with health, stats, weapons and movement behaviour.

Key scripts / scenes
- `Scripts/Enemy.gd` (`Enemy` class)
- `Systems/Enemy.tscn` and `Systems/EnemyBoss.tscn` (boss variant)
- Movement behaviours under `Scenes/` or `Systems/` (referenced as `MovementBehaviour`).

Data flow
- Inputs: spawn position and modifiers from spawners; target set by spawner or StageManager.
- Processing: `behaviour.process_movement(self, delta)` handles movement; weapons in `WeaponHolder` fire based on their logic.
- Outputs: on death, subscribe to event manager `on_death` handlers; remove collision and play death animation.

Dependencies
- `Stats` (child), `Health`, `WeaponHolder`, `ItemHolder`, `EventManager`, MovementBehaviour.

Known limitations / TODOs
- Death handling uses animation_finished connect with a short anonymous callback — works but can be fragile if animations change.
- Behavior implementation details are delegated to movement behaviour nodes; those should be inspected if modifying AI.
