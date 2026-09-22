# Weapons

Purpose
- Define weapon resources and runtime behavior (aiming, firing, visuals) applied to holders.

Key scripts / scenes
- `Systems/weapon/BaseWeapon.gd` and multiple concrete weapon scripts (`melee_weapon.gd`, `projectile_weapon.gd`, `laser_weapon.gd`, etc.)
- `Systems/weapon/weapon_holder.gd` (class_name `WeaponHolder`)
- `Systems/weapon/weapon_builtin_effects.gd` (class_name `WeaponBuiltinEffects`) — binds/strips per-weapon built-in modifiers and resolves tooltip lines.

Data flow
- Inputs: weapon `Resource` templates (.tres) added to `WeaponHolder` via `add_weapon`.
- Processing: `WeaponHolder` duplicates resources, calls `apply_to` on weapons, creates sprite nodes and timers for firing logic; weapon scripts manage aiming and firing.
- Outputs: weapons may add stat modifiers, spawn projectiles, emit events via `EventManager`.

Dependencies
- `WeaponHolder` depends on the owning node (holder) exposing `Stats` and `EventManager` where applicable.

Built-in modifiers (`BaseWeapon.modifiers`)
- Each weapon `.tres` can declare per-weapon built-in effects in the exported `modifiers` Dictionary, keyed by effect name (`Systems/weapon/BaseWeapon.gd`). Keys not in the registry are ignored, so the system is extensible.
- Two kinds of effects:
  - Hit-event effects (`knockback`, `poison`): `WeaponBuiltinEffects.attach_for_weapon` instantiates the existing modifier script (`knockback_modifier.gd`, `poison_modifier.gd`), applies the config, sets `bound_weapon` to this weapon instance, and adds it under the holder's `WeaponHolder`. Because each bound modifier only reacts to events whose `weapon` matches its bound weapon, effects never leak across weapons (e.g. a poisoned knife's poison never fires on fist hits).
  - Spawn-time effects (`pierce`): merged into the projectile's `properties` in `ProjectileWeapon.shoot_projectile` on top of the `projectile_pierce` stat (pistol pierce = stat + 1).
- Config schema: `modifiers = { "knockback": {"strength": 250.0, "duration": 0.2}, "poison": {"chance": 0.5, "duration": 3.0, "tick_interval": 1.0, "max_stacks": 3}, "pierce": {"amount": 1} }`.
- Lifecycle: `BaseWeapon.apply_to` attaches bound nodes; `WeaponHolder.remove_weapon` → `BaseWeapon.remove_from` detaches them (unsubscribing + freeing) via `WeaponBuiltinEffects.detach`. `WeaponHolder.add_weapon` duplicates each template, giving every holder an independent weapon instance and per-holder isolation.
- Tooltips: `ItemTooltip.tooltip_lines` appends one human-readable line per declared effect (`WeaponBuiltinEffects.builtin_tooltip_lines`), e.g. `pierce: 1`, `knockback: 120.0`, `poison: 50% chance, 3.0s`.

Known limitations / TODOs
- Weapons are resource-duplicated at runtime which is fine but requires careful `duplicate(true)` behavior for deep-copy correctness.
- No explicit pooling for projectiles shown; potential performance work if many projectiles spawn.
