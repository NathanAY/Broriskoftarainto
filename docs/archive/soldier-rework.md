# Soldier Rework Plan — "Demolition"

## Goal

Soldier is currently a byte-for-byte clone of Wildling (`Assets/character/soldier/Soldier.tres` == `Assets/character/wildling/Wildling.tres`: same stats, description, modifier, and starting item). Rework it into a unique explosives-focused archetype: every hit triggers explosions, weak single-target damage, massive area pressure.

## Chosen direction

**Demolition** — a bomb-toting soldier whose attacks detonate. Distinct identity no other character has. Uses only existing item assets; no new code required.

## Step 1: Update `Assets/character/soldier/Soldier.tres`

- `display_name`: stays `"Soldier"`
- `description`: `"Demolitions specialist: every hit triggers explosions. Devastating area damage, weaker single-target."`
- `base_stats`:
  - `health: 75.0`
  - `movement_speed: 0.21`
  - `damage: 0.8`
  - (drops inert `armor: 10`; health 120 → 75; damage 0.9 → 0.8)
- `modifiers`:
  - `{ "area_size_multiplier": { "percent": 0.3 } }`
  - (removes old `armor flat +2`)
- `starting_items` (both already exist):
  - `res://src/Resources/items/ExplosiveShot.tres` (`uid://mlfohgnnpkph`) — attacks explode on hit
  - `res://src/Resources/items/BombOnHit.tres` (`uid://cx4lb8wpexm1m`) — attacks drop bombs on hit
  - (removes `res://src/Resources/items/RegenPassive.tres` and its ext_resource entry)

## Resulting identity vs. the other characters

- Wildling clone path is gone; Soldier is the only explosive AoE character.
- Medium-low HP (75), fair speed (0.21 m/s), 0.8 damage multiplier offset by on-hit explosions and bomb drops.
- `area_size_multiplier +30%` scales every explosion's AoE via `Scripts/explosion.gd`.

## Verification

1. Open `Scenes/menu/CharacterSelect.tscn`, select Soldier, confirm description/stats/items display correctly.
2. Run a game as Soldier: confirm Fist hits spawn explosions and bombs, and blast radius is visibly larger.

## Open caveat (out of scope unless requested)

`Scripts/character.gd` hardcodes Fist + RegenPassive + 2x BootsOfSpeed + 2x HealthMeat for every character on top of their defined loadout, inflating all classes equally. Wildling/Soldier previously double-stacked RegenPassive because of this.