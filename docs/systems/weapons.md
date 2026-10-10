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
- Distances are authored in meters (see `docs/systems/stats.md`, "Units"): `weapon_range` (e.g. `1.0` m on the Fist, `0.66` m on the Death Aura, `1.33` m on the base resource) and a built-in knockback `strength` in m/s. Each converts to pixels only at the point of use.

Dealing damage
- Every damage source follows one contract (`projectile.gd`, `melee_weapon_node.gd`, `contact_weapon.gd`, `area_weapon.gd`, `explosion.gd`, `orbiting_orb.gd`, `poison_effect.gd`):
  1. Build a `DamageContext` (`source`, `target`, amounts, tags) and emit `before_deal_damage` on the **holder's** bus.
  2. `if not target.get_node("Health").apply_damage(ctx): return` — `Health` runs the whole defender phase on the **target's** bus and rejects the hit outright if the target is already dead.
  3. Only on `true`, emit `after_deal_damage` and `on_hit`, plus `on_kill` when `current_health <= 0`.
- Step 2 is what stops a corpse being hit again while its death animation plays; see `docs/systems/event_manager.md`. Do not emit `before_take_damage` / `after_take_damage` from a damage source — that is `Health`'s job.

The `AreaWeapon` aura (`area_weapon.gd`)
- An `AreaWeapon` damages **every `damageable` node within `weapon_range` of its own `sprite_node`, on every timer tick** — an aura centred on the wielder, not a target that was picked and then exploded around. `weapon_range` is the whole of that reach: there is no second, hidden radius. An earlier version halved `weapon_range` into a private `radius`, so the card printed a range twice as large as the circle that dealt damage; the halving is gone and `try_shoot` damages the list `BaseWeapon._on_timeout` hands it instead of re-querying the selector. Paired with `AllTargetsInRangeSelector` (`src/Resources/weapons/aim/all.tres`).
- There is no impact point and no chosen target, which is why the visual is a ring rather than a hit spark. `try_shoot` spawns `src/Scenes/particles/area_damage_burst.tscn` per tick, placed at `sprite_node.global_position` because that sprite is what the selector measures from (and it orbits the holder at `weapon_orbit_radius`, so the aura centre is offset from the character by up to that much). Because `_on_timeout` calls `try_shoot` only when it found a target, the burst appears only when something is actually in range.
- The burst's `radius` (pixels) is set from `get_range_px()` — `weapon_range` converted through `meters_to_px()` — rather than authored, so the drawn circle cannot drift from the number damage is measured against. `area_damage_burst.gd` duplicates each `process_material` before retargeting it: a `PackedScene`'s sub-resources are shared across instances, so writing the ring radius on the shared one would leak one weapon's range into the next.
- The weapon is `src/Resources/weapons/DeathAura.tres`. It used to be called Knife, which described neither the sprite (`circular_saw.png`) nor the behaviour. It pulses at **half rate** — `base_attack_speed = 0.5`, so its firing timer waits 2s at a character's baseline `attack_speed` — which puts it in the snipe/burst archetype of `docs/systems/balance.md` §4.2 and halves its `WB_raw` against the `BaseWeapon` default of 1.0. The damage is tagged `melee` and is unaffected by `area_size_multiplier` — that stat only scales `src/Scripts/explosion.gd`. Its `weapon_range` is `0.66` m, which is both the number the card prints and the aura's actual reach.

Weapon tooltip contract (`BaseWeapon`)
- `ItemTooltip.weapon_card_rows` owns the card's row format; a weapon only reports *what* to show, through two virtual methods on `BaseWeapon`. `tooltip_details()` returns extra `[label, value]` rows for numbers only the subclass knows — `ShotgunWeapon` adds `Pellets` — and `has_tooltip_range()` lets a weapon drop the shared `Range` row: `ContactWeapon` returns `false`, because Thorns damages whatever enters the holder's hitbox and has no reach to report. Adding a weapon type therefore means overriding these on the weapon script, never adding an `if weapon is ...` branch to `ItemTooltip`.

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
