# Weapons

Purpose
- Define weapon resources and runtime behavior (aiming, firing, visuals) applied to holders.

Key scripts / scenes
- `src/Systems/weapon/BaseWeapon.gd` and multiple concrete weapon scripts (`melee_weapon.gd`, `projectile_weapon.gd`, `laser_weapon.gd`, etc.)
- `src/Systems/weapon/weapon_holder.gd` (class_name `WeaponHolder`)
- `src/Systems/weapon/weapon_builtin_effects.gd` (class_name `WeaponBuiltinEffects`) — binds/strips per-weapon built-in modifiers and resolves tooltip lines.

Data flow
- Inputs: weapon `Resource` templates (.tres) added to `WeaponHolder` via `add_weapon`.
- Processing: `WeaponHolder` duplicates resources, calls `apply_to` on weapons, creates sprite nodes and timers for firing logic; weapon scripts manage aiming and firing.
- Outputs: weapons may add stat modifiers, spawn projectiles, emit events via `EventManager`.
- Distances are authored in meters (see `docs/systems/stats.md`, "Units"): `weapon_range` (e.g. `1.0` m on the Fist, `1.33` m on the base resource), a built-in knockback `strength` in m/s, and the `AreaWeapon` `radius` (half of `weapon_range`). Each converts to pixels only at the point of use.

Dealing damage
- Every damage source follows one contract (`projectile.gd`, `melee_weapon_node.gd`, `contact_weapon.gd`, `area_weapon.gd`, `explosion.gd`, `orbiting_orb.gd`, `poison_effect.gd`):
  1. Build a `DamageContext` (`source`, `target`, amounts, tags) and emit `before_deal_damage` on the **holder's** bus.
  2. `if not target.get_node("Health").apply_damage(ctx): return` — `Health` runs the whole defender phase on the **target's** bus and rejects the hit outright if the target is already dead.
  3. Only on `true`, emit `after_deal_damage` and `on_hit`, plus `on_kill` when `current_health <= 0`.
- Step 2 is what stops a corpse being hit again while its death animation plays; see `docs/systems/event_manager.md`. Do not emit `before_take_damage` / `after_take_damage` from a damage source — that is `Health`'s job.

The `AreaWeapon` aura (`area_weapon.gd`)
- `AreaWeapon` re-queries the selector itself with its own `radius` (half of `weapon_range`) rather than damaging the list `BaseWeapon._on_timeout` hands it. `_on_timeout` measures with the full `weapon_range`, so the aura narrows the range after that point; without the re-query only the burst visual shrinks and the damage still reaches the full range. Paired with `AllTargetsInRangeSelector` (`src/Resources/weapons/aim/all.tres`) that means **every `damageable` node within `radius` of the weapon's own `sprite_node`, on every timer tick** — an aura centred on the wielder, not a target that was picked and then exploded around.
- There is no impact point and no chosen target, which is why the visual is a ring rather than a hit spark. `try_shoot` spawns `src/Scenes/particles/area_damage_burst.tscn` per tick, placed at `sprite_node.global_position` because that sprite is what the selector measures from (and it orbits the holder at `weapon_orbit_radius`, so the aura centre is offset from the character by up to that much).
- The burst's `radius` (pixels) is set from the weapon's `radius` getter, half of `weapon_range` **in meters** converted through `meters_to_px()`, rather than authored, so the drawn circle cannot drift from the number damage is measured against. `area_damage_burst.gd` duplicates each `process_material` before retargeting it: a `PackedScene`'s sub-resources are shared across instances, so writing the ring radius on the shared one would leak one weapon's range into the next.
- The weapon is `src/Resources/weapons/DeathAura.tres`. It used to be called Knife, which described neither the sprite (`circular_saw.png`) nor the behaviour. It pulses at **half rate** — `base_attack_speed = 0.5`, so its firing timer waits 2s at a character's baseline `attack_speed` — which puts it in the snipe/burst archetype of `docs/systems/balance.md` §4.2 and halves its `WB_raw` against the `BaseWeapon` default of 1.0. Note the damage is tagged `melee` and is unaffected by `area_size_multiplier` — that stat only scales `src/Scripts/explosion.gd`, and the aura's radius is half of `weapon_range`. That number lives in the weapon's `description` (`DeathAura.tres`), which `ItemTooltip.tooltip_lines()` / `weapon_card_rows()` now surface as a FLAVOR row — the item tooltip path skips descriptions, but a weapon's carries mechanical detail, so it is shown rather than hidden.

Debug visibility (`weapon_holder.gd`, `weapon_visual.gd`)
- A weapon is a `Resource`, so it can never be a child itself. `WeaponHolder._create_visual` therefore builds the one node per weapon that represents it in the tree: a `WeaponVisual` (a `Sprite2D` subclass) child of the `WeaponHolder`, named after the weapon (`Shotgun`, and `Shotgun2` for a second copy).
- `weapons` stays the single source of truth. There is no weapon -> node lookup table: `BaseWeapon.sprite_node` points at the weapon's own `WeaponVisual`, and the node points back through its exported `weapon` field, so selecting the node in the inspector shows the weapon. `_reposition_weapons` and weapon scripts (spawn position, aim, melee) all read `sprite_node` directly. `remove_weapon` frees it via `BaseWeapon.remove_from`.
- `WeaponHolder.tscn`'s root is a `Node2D`, not a `Node`: a `Node2D` under a plain `Node` does not inherit the canvas transform, so the visuals would sit at the world origin instead of orbiting the holder.
- The visual's `z_index` is 1 because it used to be appended as the last child of the holder; nesting it under the `WeaponHolder` changes the tree order, and the bump keeps the weapon drawn on top of the holder's other visuals.
- In the editor, run the game and use the Scene dock's **Remote** tree - these nodes only exist at runtime.

Dependencies
- `WeaponHolder` depends on the owning node (holder) exposing `Stats` and `EventManager` where applicable.

Built-in modifiers (`BaseWeapon.modifiers`)
- Each weapon `.tres` can declare per-weapon built-in effects in the exported `modifiers` Dictionary, keyed by effect name (`src/Systems/weapon/BaseWeapon.gd`). Keys not in the registry are ignored, so the system is extensible.
- Two kinds of effects:
  - Hit-event effects (`knockback`, `poison`, `explosive_shot`): `WeaponBuiltinEffects.attach_for_weapon` instantiates the existing modifier script (`knockback_modifier.gd`, `poison_modifier.gd`, `explosive_shot_modifier.gd`), applies the config, sets `bound_weapon` to this weapon instance, and adds it under the holder's `WeaponHolder`. Because each bound modifier only reacts to events whose `weapon` matches its bound weapon, effects never leak across weapons (e.g. the Death Aura's poison never fires on fist hits, and the Shotgun's explosive shot only fires on its own pellets). A built-in modifier script must subscribe via `_subscribe` for that scoping to apply.
  - Spawn-time effects (`pierce`): merged into the projectile's `properties` in `ProjectileWeapon.shoot_projectile` on top of the `projectile_pierce` stat (pistol pierce = stat + 1).
- Config schema: `modifiers = { "knockback": {"strength": 0.83, "duration": 0.2}, "poison": {"chance": 0.5, "duration": 3.0, "tick_interval": 1.0, "max_stacks": 3}, "explosive_shot": {"fraction": 0.2, "radius": 0.21}, "pierce": {"amount": 1} }`. A `knockback` `strength` is in m/s (0.83 m/s on the Fist, 0.4 on the Pistol); an `explosive_shot` `fraction` is the share of the triggering hit's damage the explosion deals (the Shotgun uses 0.2, per `balance.md` §6.2's +20% on-hit-rider budget).
- Lifecycle: `BaseWeapon.apply_to` attaches bound nodes; `WeaponHolder.remove_weapon` → `BaseWeapon.remove_from` detaches them (unsubscribing + freeing) via `WeaponBuiltinEffects.detach`. `WeaponHolder.add_weapon` duplicates each template, giving every holder an independent weapon instance and per-holder isolation.
- Tooltips: `ItemTooltip.tooltip_lines` appends one human-readable line per declared effect (`WeaponBuiltinEffects.builtin_tooltip_lines`), e.g. `pierce: 1`, `knockback: 0.4 m/s`, `poison: 50% chance, 3.0s`, `explosive shot: 20% of hit damage`.

Known limitations / TODOs
- Weapons are resource-duplicated at runtime which is fine but requires careful `duplicate(true)` behavior for deep-copy correctness.
- No explicit pooling for projectiles shown; potential performance work if many projectiles spawn.
