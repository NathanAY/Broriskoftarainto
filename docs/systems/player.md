# Player

Purpose
- The **Player** — the runtime combat entity the human controls — and the orchestration of its equipment, stats and visual feedback. The playable archetype is a separate concept (`CharacterData`); see `docs/adr/0001-character-means-archetype.md`.

Key scripts / scenes
- `src/Scripts/character.gd` (`class_name Character`) — the Player entity, despite the class name.
- `src/Systems/Character.tscn` — the Player scene, a `CharacterBody2D`. Its children are the whole contract between the script and the scene:
  - **Equipment** — `Stats`, `Health`, `ItemHolder`, `WeaponHolder`. Each takes the `EventManager` as an exported `event_manager`.
  - **Eventing** — `EventManager`, a child *instance*, so the whole subtree shares one bus. Anything that reacts to gameplay subscribes to it.
  - **Applying the archetype** — `CharacterInitializer`, which reads `GlobalGameState.starting_character` and writes it onto `Stats` on spawn. See `docs/systems/characters.md`.
  - **Movement and collision** — `Movement` (behaviour), `Hitbox` (an `Area2D` plus its shape), and the body's own `CollisionShape2D`.
  - **Presentation** — `Node2D/Sprite2D` with `eyes` and `mouth` child sprites (the face is layered art, not one file), `Node2D/Legs` with two leg sprites, `HitFlashManager`, `ParticleEffectManager`, `AnimationPlayer`, and the HUD `HealthBar`, `DamageNumberSpawner`, `HealNumberSpawner`.
- `src/Scenes/effects/` — `HitFlashManager` (flashes on `before_take_damage`) and `TextureBurstManager` (death burst on `on_death`).
- `src/Scenes/particles/particle_effect_manager.gd` — hit particles on `after_take_damage`.
- `src/Scenes/menu/CharacterSelect.tscn` + `src/Systems/characters/CharacterData.gd` — where the archetype is picked; `CharacterData` `.tres` files live in `src/Assets/character/<id>/`.

Data flow
- Inputs: player input, `GlobalGameState` (starting character, items, weapons), and `EventManager` events from the same subtree.
- Processing: equips weapons and items through the two holders, subscribes to the damage and death events, and delegates visual feedback to the child effect managers rather than handling it itself.
- Outputs: the `character_died` signal, which stage flow and UI listen to; the holders emit `on_item_added` / `on_item_removed` / `on_weapon_changes`.

Dependencies
- `EventManager`, `Stats`, `Health`, `WeaponHolder`, `ItemHolder`, and `GlobalGameState` — the last an autoload at `src/Scripts/autoload/global_game_state.gd`, not an assumed one.

Known limitations / TODOs
- Initialization is still partly hardcoded, with commented-out example items left in the script — prototype artifacts rather than intent.
- Input handling is minimal. There is no `MainScene` scene in the project; the gameplay scene is `src/Scenes/Game.tscn`, so if you are looking for where input is wired up, that is the place, and the gap is still there.