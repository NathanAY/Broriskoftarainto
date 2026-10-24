# Enemy variety

Goal: the arena stops being one grey blob walking at you. Six distinct enemy types,
each a different *shape of threat* rather than a different number, plus the
infrastructure to spawn a mix of them and swap their stats from the editor.

Status: **Stage 0 — the enabling work — is implemented** (0.1 to 0.5, each with its
own test suite), and **Stage 1 rows 1 and 2 — the Gunner and the Bulwark — are
shipped**: the sprites, the enemy scenes, the spawn-table rows and the gallery
preview. The other three rows of Stage 1 and the two stretch items (0.6 Blink,
0.7 front shield) are not started. The "What exists today" section below describes
the state *before* Stage 0 and is left as the record of why the enabling work was
needed.

## What exists today (and why this plan is not just "add 6 scenes")

- There are exactly two enemy scenes: the grunt and the boss. Every wave spawns
  `src/Systems/Enemy.tscn`, always — `src/Systems/enemy_spawner.gd` hardcodes it as a
  plain `var`, not even an export.
- `src/Scripts/Enemy.gd` has **zero exports**. An enemy is entirely its `.tscn`. That is
  fine for one enemy type and unworkable for eight.
- `src/Scripts/Enemy.gd` `_ready()` loads Thorns on **every** enemy, hardcoded. So today an
  enemy that shoots cannot exist — it would also have to be a touch-damage enemy.
- `src/Systems/movement/bahaviour/chase_distance_movement_behaviour.gd` exists, works, and
  is referenced by **nothing**. It is a finished kiting behaviour waiting for a user.
- Behaviours are duck-typed against a `CharacterBody2D`, so adding an AI is a 40-line
  script plus a `.tscn`, not a new enemy class.
- The boss already proves enemies can carry real weapons: `src/Systems/boss_spawner.gd`
  hands it `src/Resources/weapons/boss/*.tres`. Ranged enemies are a config problem, not a
  code problem.

So the plan is ~70 lines of enabling work and then a row of scenes.

## The reference sheet

`docs/plans/images/enemies/A_sprite_sheet_of_six_enemies.jpg` already has six creatures
and every one of them gets a role. Read it as three across, two down:

```
+---------------------------+---------------------------+---------------------------+
| purple slug, one huge eye | spiked iron-shell turtle  | squat grey goblin,        |
| (top left)                | (top middle)              | huge ears (top right)     |
+---------------------------+---------------------------+---------------------------+
| green jelly blob          | crimson segmented worm    | fat orange toad (bottom   |
| (bottom left)             | (bottom middle)           | right)                    |
+---------------------------+---------------------------+---------------------------+
```

## The roster

Six types from the sheet, then three that need fresh art.

| # | Name | Sheet creature | Mechanic in one line | Movement behaviour |
|---|------|----------------|----------------------|--------------------|
| 1 | **Goblin Gunner** | grey goblin | Fires a pistol, holds a firing distance, closes if you get inside it | `ChaseDistanceMovementBehaviour` (existing) |
| 2 | **Bulwark** | spiked turtle | Very slow, very high health, contact damage that hurts | `ChaseMovementBehaviour` (existing) |
| 3 | **Slimeling** | green jelly | Dies into three half-size minis | `ChaseMovementBehaviour` (existing) |
| 4 | **Lancer** | crimson worm | Walks in, stops, telegraphs, then charges the spot it locked | **new** `ChargeMovementBehaviour` |
| 5 | **Toadstinker** | orange toad | Detonates on death, damaging whatever is standing there | `ChaseMovementBehaviour` (existing) |
| 6 | **Blink** | purple slug | Reappears closer to you every few seconds, out of nowhere | **new** `BlinkMovementBehaviour` (stretch) |
| 7 | **Shieldbearer** | *needs art* | Ignores hits that land on its front arc; you have to get behind it | `ChaseMovementBehaviour` |
| 8 | **Swarmer** | *needs art* | Tiny, 1 HP, arrives in packs of eight | `ChaseMovementBehaviour` |
| 9 | **Elites** | any, tinted | A loop-3+ version of any of the above, scaled and recoloured | inherited |

Two of the four the brief asked for map onto rows 1-4 directly: the pistol gunner, the slow
high-life Bulwark, the splitter, and the charger. Two more came free from the same sheet.

## Stage 0 — enabling work

Nothing else can start until these land. Each is small and independently testable.

### 0.1 Contact damage becomes optional

`src/Scripts/Enemy.gd` `_ready()`:

```gdscript
# every enemy gets Thorns, and it is coupled to the hitbox
$WeaponHolder.add_weapon(load("res://src/Resources/weapons/Thorns.tres"))
```

becomes an export with the same default, so every existing enemy, debug scenario and test
fixture keeps working untouched:

```gdscript
## Contact damage. Thorns hooks the body's own Hitbox, so an enemy that
## should not hurt on touch sets this to null and arms itself some other way.
@export var contact_weapon: Resource = preload("res://src/Resources/weapons/Thorns.tres")
```

and `_ready()` only adds it when non-null. The Goblin Gunner and the Toadstinker set it
empty. Without this, half the roster cannot be authored at all.

### 0.2 The spawner spawns a table, not one scene

`src/Systems/enemy_spawner.gd` line 42 is `var enemy_scene = preload(...)`, used in both
`spawn_enemy_group()` and `spawn_enemy()`. Replace it with a weighted, loop-gated table.

New files: `src/Systems/enemies/enemy_spawn_entry.gd` and its
`src/Systems/enemies/enemy_spawn_entry.gd.uid` sidecar.

A `Resource` rather than two parallel exported arrays, because the inspector cannot check
that `enemy_scenes` and `enemy_weights` are the same length, and eight rows of
hand-synchronised parallel arrays rot the first time someone adds a row.

```gdscript
class_name EnemySpawnEntry
extends Resource

@export var scene: PackedScene
@export var weight: float = 1.0
## Loop the entry unlocks on. 1 = from the first wave.
@export_range(1, 3) var min_loop: int = 1
```

On the spawner:

```gdscript
@export var spawn_table: Array[EnemySpawnEntry] = []
## Used when the table is empty, so a scene that forgot to fill it still spawns.
@export var fallback_enemy_scene: PackedScene = preload("res://src/Systems/Enemy.tscn")
```

plus one helper, and both call sites swap `enemy_scene.instantiate()` for
`pick_enemy_scene().instantiate()`:

```gdscript
func pick_enemy_scene() -> PackedScene:
    var open: Array[EnemySpawnEntry] = []
    for entry in spawn_table:
        if entry.scene != null and current_loop >= entry.min_loop:
            open.append(entry)
    if open.is_empty():
        return fallback_enemy_scene
    return open[randi_range(0, open.size() - 1)].scene
```

Weighted picking lands later if the mix reads wrong — an unweighted draw across a table
whose entries are already curated by `min_loop` is the simplest thing that can work, and
`min_loop` is what actually controls difficulty. Do not build the weight roll until the
roster has been played for a few runs and one type is visibly over-represented.

> **Shipped differently.** The weight roll was built anyway, because a `weight` field
> that nothing reads is a lie waiting to happen: a designer sets it to 5, nothing
> changes, and the bug is invisible. The roll is eight lines, and with every row at
> its default `1.0` it *is* the uniform draw this section describes. A row with a
> weight of zero never comes up, and a table whose every row is zero falls back.

### 0.3 Death-time spawning, on the enemy itself

The splitter is the only type that needs to act *after* death starts. `Enemy._die` has no
hook, but the event bus does — `src/Scripts/spawner_modifier.gd` already subscribes to
`on_death` and spawns explosions, items and altars from it, so the pattern is established.

> **Shipped differently.** The split does **not** live on `Enemy`. It is an optional child
> node, `src/Systems/enemies/split_on_death.gd` (`SplitOnDeath`) plus
> `src/Systems/enemies/SplitOnDeath.tscn`, and `Enemy.gd` carries none of it.
>
> `Enemy.gd` is the script *every* enemy runs, so code only one enemy type uses does not
> belong there: the grunt, the boss and the five roster types would all carry the split
> machinery to serve one of them. An optional child node is the same pattern 0.4 uses for
> the death burst, and it means an enemy that does not split simply does not have the
> node. The config moved with the code: `split_scene`, `split_count` and `split_scale`
> are exports on the node, not on the enemy.
>
> The plan's `_is_minion` flag became `suppressed` on the node: a spawned child is told
> not to split again.
>
> **The trap this also fixed.** The plan had `split_scene` pointing at the splitting
> enemy's own scene. A scene cannot point at itself — Godot rejects the cyclic
> reference with a parse error — so that config was impossible to author. An empty
> `split_scene` now means "the owner's own scene", taken from the owner's
> `scene_file_path`.

The splitter is a `Node` on the enemy scene. It watches the enemy's own `on_death`, and
when the enemy dies it spawns the children into the same container the spawner uses, so
`StageManager`'s `get_child_count() == 0` stage-end still works. Stats must be scaled
**before** `add_child`, because `src/Systems/damage/health.gd` `_ready()` reads
`stats.get_stat("health")` once. `enemy_spawner.gd::_apply_stage_scaling` already relies on
that ordering; the split path does the same.

The mini is the same scene at reduced scale, which means **its collider and sprite scale
too** — the collider radius feeds `Enemy.body_radius()` and therefore the whole crowd
separation force. Set `CollisionShape2D` shape radius and `Node2D/Sprite2D` scale from
`split_scale` at spawn.

### 0.4 Death explosion

`src/Scenes/Explosion.tscn` is a visual. The Toadstinker needs a damage source, so one new
small script:

```
src/Systems/damage/area_burst_on_enter.gd
src/Systems/damage/AreaBurstOnEnter.tscn
```

> **Shipped as** `src/Systems/damage/area_burst_on_enter.gd` and
> `src/Systems/damage/AreaBurstOnEnter.tscn`.

An `Area2D` that, when the death event fires, collects everything in
`group "damageable"` inside its radius and calls `Health.apply_damage` on each, then
detaches itself. It goes in the enemy scene as an optional child with a `blast_damage`
export. `group "damageable"` is the right filter because every `TargetSelector` already
walks it and the dead target has just left it.

> **Shipped as described**, with two additions: the radius is an export in **meters**
> (`blast_radius`), the unit the project authors distances in, and the burst skips its
> own owner explicitly rather than relying on the corpse having left the group first.

### 0.5 Charging behaviour

a new charge behaviour script and its scene under the existing behaviour
folder, next to the
existing three. Four states, driven by a timer rather than a `Tree` timer so it stays
inside the existing `process_movement` contract:

```
APPROACH  walk to within stop_distance
WINDUP    stand still, face the player, play a telegraph animation
CHARGE    drive along the direction locked at the end of WINDUP, ignoring the player
RECOVER   stand still, then back to APPROACH
```

> **Shipped as** `src/Systems/movement/bahaviour/charge_movement_behaviour.gd` and
> `src/Systems/movement/bahaviour/ChargeMovementBehaviour.tscn`.

Exports: `stop_distance`, `windup_time`, `charge_speed_scale`, `charge_duration`,
`recover_time`.

**The trap.** `Enemy._physics_process` clamps velocity to
`stats.get_movement_speed_px()` after the behaviour runs, so a behaviour cannot simply set
`velocity = dir * 400.0` — it gets clamped straight back to walk speed. The charge has to
be expressed as a temporary `Stats` boost, or `Enemy` needs a per-frame speed override. A
stat boost is smaller: multiply `movement_speed` at the start of `CHARGE` and restore it
at the start of `RECOVER`. Whatever this ends up doing, it must restore the stat on every
exit path including death, or a dying Lancer leaves its corpse walking at triple speed.

The other behaviour rule worth writing down: the Lancer locks its direction when the
windup ends and does not track during the charge. A charge that re-aims every frame is just
a fast walk and the player cannot dodge it.

### 0.6 Blinking behaviour (stretch)

A new blink behaviour script in that same folder. Every `blink_interval`,
teleport to a random point within `blink_radius` of the target and re-enter `APPROACH`,
with a short fade so the jump is not a pop-in. This is the cheapest "unfair-feeling but
fair" enemy in the set and is worth doing after the five core rows ship.

### 0.7 Front shield (stretch)

A front-shield scene plus script under `src/Systems/damage/`, as an optional enemy
child. Subscribes to the
enemy's own `EventManager` `before_take_damage`, reads `DamageContext.source`, and zeroes
`final_amount` when the source sits inside a frontal arc of the sprite's facing. Useful
precisely because every other enemy in the roster is a positioning problem and this one is
a targeting problem.

## Stage 1 — the five core enemies

One row each. Proposed numbers are **starting points in `.tscn` data**, not design
constants — see "Numbers are data" below.

### 1. Goblin Gunner — pistol at range

- Sprite: grey goblin, top right of the sheet.
- Movement behaviour: the existing orphan,
  `src/Systems/movement/bahaviour/ChaseDistanceMovementBehaviour.tscn`, with
  `stop_distance` set to roughly a third of the pistol's range.
- Weapon: `src/Resources/weapons/Pistol.tres` equipped from the scene, with a
  `contact_weapon` of null so it does not also body-check.
- **Placement trap:** do **not** drop the enemy weapon `.tres` directly into
  `src/Resources/weapons/`. The shop, the starter loadout and the configure panel scan
  that directory non-recursively and would sell it.
  `src/Resources/weapons/boss/` exists precisely because of this, pinned by
  `test/Systems/weapon/test_boss_loadout.gd`. Enemy weapons go in their own subdirectory
  beside it.
- Reads as a ranged enemy that stands still and shoots. If it turns out to be pure kite,
  the retreat half of the behaviour is a small follow-up (`back away when closer than
  `retreat_distance`); do not add it before the stand-and-shoot version has been played.

> **Shipped** as `src/Systems/EnemyGunner.tscn`, with the art at
> `src/Assets/enemies/gunner.png`. The sheet's top-right cell was the
> placeholder; the shipped art is a hand-delivered high-resolution image
> (source kept at `docs/plans/images/enemies/Goblin.png`) normalised to the
> roster's 100x100 / 85%-fill canvas. The sheet cell is therefore **not** in
> the extractor's `CELLS` table, so re-running the tool cannot overwrite it.
> Leaving the delivered resolution in place is the trap here: `Sprite2D` draws
> a texture at its pixel size, so a 313x273 file rendered several times larger
> than the 100x100 roster sprites and the collider no longer matched it.
>
> The row is config on top of 0.1 and 0.2, as planned: `contact_weapon` is null,
> the shared `src/Resources/weapons/Pistol.tres` sits in the `WeaponHolder`, and
> `ChaseDistanceMovementBehaviour` walks it in to `stop_distance` 140 - about a
> third of the pistol's 1.33 m reach. Because it reuses the existing pistol
> instead of adding a file to `src/Resources/weapons/`, the shop-placement trap
> did not come up; an enemy weapon that needs its own numbers would still go in
> a subdirectory beside `boss/`.
>
> **Three things the row turned up.**
>
> The first is that a weapon placed in an enemy scene is equipped **one idle
> frame after** the enemy enters the tree: `WeaponHolder._ready` defers the
> equip so the firing timer can be attached to a settled parent. The loadout
> test therefore has to await `process_frame` before it reads
> `weapon_holder.weapons`, or it sees the template still sitting in the array.
>
> The second is that `ChaseDistanceMovementBehaviour` had never been used, so
> its unused `delta` parameter had never been compiled into a warning. Renaming
> it `_delta` is the whole fix, and the row is what surfaced it.
>
> The third is that a weapon spawns its projectiles into
> `get_tree().current_scene`, which a GdUnit suite does not have. The suite that
> fires the Gunner parents its world to the tree root and makes it the current
> scene; `current_scene` only accepts a child of the root, so it cannot live
> under the suite.
>
> Re-running the extraction tool also rewrote `src/Assets/enemies/bulwark.png`
> from the same sheet cell: the committed cut predated the tool's current
> transparent-pixel handling, and the tool now reproduces the newer one
> deterministically.
>
> The row also surfaced a defect the grunt could never show: a weapon's firing
> timer lives on the `WeaponHolder` and keeps ticking after `Enemy._physics_process`
> returns early for a corpse, so a Gunner that died mid-cycle fired one last shot
> out of its own body. `Enemy._die` now disarms the corpse (`_silence_weapons`),
> pinned by `test_a_dead_enemy_stops_firing` in the variant suite. That is a
> change to every enemy, including the boss.

### 2. Bulwark — slow, high life

- Sprite: spiked iron-shell turtle, top middle.
- The existing `ChaseMovementBehaviour`, with a much lower `movement_speed` base stat.
- High `health`. Keeps Thorns — this is the contact-damage wall you walk into.
- Existing sprite and animation are enough; this row needs **no new code at all** beyond
  0.1. It is the row that proves the enabling work.

> **Shipped** as `src/Systems/EnemyBulwark.tscn`, with the art at
> `src/Assets/enemies/bulwark.png`.
>
> The row is data all the way down, exactly as planned: the scene is a copy of
> `src/Systems/Enemy.tscn` with the sprite swapped and the stats written out, and
> nothing else changed. It uses `ChaseMovementBehaviour`, keeps the default
> contact weapon, and carries `health 30` at `movement_speed 0.4` — three times
> the grunt's health at a third of its speed.
>
> **Two things the row turned up.**
>
> The first is that `Stats.stats` is exported as a **whole dictionary**, and a
> scene that overrides it replaces the default rather than merging into it. A
> variant that sets only the three stats it cares about loses `movement_speed`
> and `damage` with them, and the enemy never moves. Every enemy scene writes
> the full dictionary out.
>
> The second is that the collider is a circle around the *drawn* creature, so it
> has to scale with the art: a bigger sprite wearing the old collider is a wall
> the player walks through. The roster's enemies share the 100x100 canvas, so
> they share the grunt's collider, and the test asserts the collider against the
> sprite's own width rather than against a number.
>
> The row also proves the sheet-to-scene pipeline: the art is cut out of the
> sheet by `test/tools/extract_enemy_sprites.gd`, and the roster is rendered by
> `test/tools/enemy_gallery_preview.tscn`.

### 3. Slimeling — splits on death

- Sprite: green jelly blob, bottom left.
- Existing `ChaseMovementBehaviour`, normal speed, low `health`.
- `split_count = 3`, `split_scale` around 0.6, and no `split_scene` — the splitter falls
  back to the enemy's own scene, which is how it splits into copies of itself.
- **Trap:** the sheet's jellyfish is translucent and the visual style doc already flags
  translucency as a rules violation — a see-through enemy reads as a hole in the arena.
  Either regenerate this one opaque or use the turtle for the splitter. Do not ship the
  translucent cell as-is.

### 4. Lancer — telegraph and charge

- Sprite: crimson worm, bottom middle.
- The new `ChargeMovementBehaviour`.
- Needs a telegraph animation to be fair. `src/animations/enemy_animations.res` has no
  windup clip, and that library is **shared with the player** (the character scene
  instances it too), so adding one there changes the player. A new `.res` library for the
  Lancer is the clean route.
- **Trap:** the sheet's worm is a closed curl with a hole in the silhouette, and
  `docs/visual_style.md` already records that as a shape rule. Either regenerate as a
  shallow S or accept that the collider circle and the sprite disagree.

### 5. Toadstinker — detonates on death

- Sprite: fat orange toad, bottom right.
- Existing `ChaseMovementBehaviour`, normal speed, **low** health — it wants to die next to
  you, and the player should be able to kill it at range to make that happen or not happen.
- Optional `AreaBurstOnEnter` child from 0.4. `contact_weapon` null.
- `src/Scenes/effects/` already has the blast visuals, so this is mostly wiring.

### Elites

A cheap multiplier on the whole roster: at `min_loop` 2 or 3 an entry spawns the same scene
with a stat multiplier and a tinted sprite. This is deliberately **not** a seventh enemy
type — it reuses every scene and every behaviour, and it is the difference between a mix
that stays readable at loop 3 and a mix that turns into the same numbers in a different
colour.

## Numbers are data

Every number above lives in a `.tscn` and will be rebalanced. Consequences for the tests
that ship with this work:

- **Do not pin a stat in an assertion.** A test that asserts `max_health == 60` goes red on
  the first balance pass and the fix is always to weaken the test, which turns it into a
  stale copy of the `.tscn`. Assert the mechanic instead: that the Bulwark's health is
  *greater than* the Gunner's, that a mini's health is *approximately* `split_scale` of its
  parent's, that a charge covers more ground than a walk in the same time.
- Structural facts are fine as literals: three children spawned, the minis did not split
  again, the charge direction did not change once locked.
- `docs/systems/balance.md` computes enemy TTK against one basic enemy and has a per-type
  budget table. New types get a row there, and the enemy DPS numbers in that doc change.

## Tests

One suite per row, following `AGENTS.md`: write the test, run it, read the failure, fix,
run again.

```
test/Systems/test_enemy_contact_weapon.gd      # 0.1: null contact_weapon arms nothing
test/Systems/test_enemy_spawn_table.gd         # 0.2: loop gating, empty-table fallback
test/Systems/test_enemy_split_on_death.gd      # 0.3: three minis, minis do not split
test/Systems/damage/test_area_burst_on_enter.gd # 0.4: only damageable, only in radius
test/Systems/test_charge_movement_behaviour.gd # 0.5: state order, locked direction
test/Systems/test_enemy_variant_loadouts.gd    # 1.x: each scene arms what it should
```

> **Shipped so far**: `test/Systems/test_enemy_contact_weapon.gd`,
> `test/Systems/test_enemy_spawn_table.gd`, `test/Systems/test_enemy_split_on_death.gd`,
> `test/Systems/damage/test_area_burst_on_enter.gd`,
> `test/Systems/test_charge_movement_behaviour.gd` and
> `test/Systems/test_enemy_variant_loadouts.gd`. The last one is the Stage 1 suite, and it
> has the Bulwark and the Gunner in it: each row declares the weapon its role arms, and
> the Gunner also gets tests for its firing distance sitting inside its own weapon's
> reach, for holding that distance instead of walking into the player, and for actually
> damaging a body at range.
>
> One extra shared helper came out of it:
> `test/Systems/damageable_body.gd` (`DamageableBody`) — a minimal body with a `Health`
> node that the damage suites can hurt, so they do not have to pay for the whole
> `Character` scene.

Reusable harness, do not reinvent:

- `test/Systems/test_spawner_arena.gd` — its `_build_tree()` already assembles
  `TestRoot/{Arena?, Nodes/Enemies, StageManager/<spawner>, Character}`. That is the tree
  every enemy-spawning test wants.
- `test/Systems/weapon/weapon_test_support.gd` — `spawn_enemy_behind()`,
  `equip_only_weapon()`, `give_enemy_health()`, and `health_left()`, which is the only safe
  way to read health off an enemy mid-death. Reading a freed `Health` is the single most
  common cause of a 125 stall in this repo.
- `test/Systems/test_wander_arena.gd` — the precedent for testing a behaviour on a bare
  `CharacterBody2D` instead of a full enemy scene.

## Dev tooling this needs

A new enemy gallery preview scene plus script in `test/tools/` — instances all six+ enemy
types in a row on a plain background, so the whole roster can be rendered in one shot with
the existing tool:

```
.\run_scene_shot.bat res://test/tools/enemy_gallery_preview.tscn res://enemies.png
```

Without it, checking six new sprites means six runs. The rest of the work has a visual
component too — the telegraph pose, the blink fade, the blast radius ring — and each of
those is a screenshot away.

> **Shipped** as `test/tools/enemy_gallery_preview.tscn` and
> `test/tools/enemy_gallery_preview.gd`. It holds a `ROSTER` list of the scenes that
> exist, and a row is added to it when that enemy ships.

## Sprite prompts

All six sheet creatures already exist as art. These are the ones that do not.

### Sheet cells (extract, do not regenerate)

Extract the six cells from `docs/plans/images/enemies/A_sprite_sheet_of_six_enemies.jpg`
into `src/Assets/enemies/<snake_case>.png`, 100x100 each, collision radius around 0.4x
half-width per the asset table in `docs/visual_style.md`. The grid is not clean — detect
each creature's bounding box per cell rather than slicing equal rectangles.

Two cells are known-bad per that same doc: the jellyfish is translucent and the worm has a
hole in its silhouette. Both regenerate before use if their enemy ships.

> **Shipped** as `test/tools/extract_enemy_sprites.gd`, which segments the sheet rather
> than slicing it: the white backdrop is flood-filled in from the border and what is left
> is split into connected components, one per creature. The turtle's cell is already
> extracted, as `src/Assets/enemies/bulwark.png`.
>
> The tool does the cutting, but the **collision radius is not 0.4x half-width**. The
> asset table's rule is the *character's* rule, and the shipped enemies do not follow it:
> the grunt's collider is 41 on a 100x100 sprite, because the rule that holds for an enemy
> is that the collider matches the **drawn** creature. So the roster's enemies share the
> grunt's collider, and the test asserts the collider against the sprite's own width
> instead of against a number.
>
> Two more traps the extraction has: a transparent pixel that still carries the sheet's
> white blends that white into the creature's outline as a pale halo when the cut-out is
> resized, so the transparent pixels are zeroed before the resize and the result is
> un-premultiplied after it. And the white *inside* the artwork — an eye highlight — must
> not be keyed out, which is why the backdrop is flood-filled from the border rather than
> keyed by colour.

```
A translucent floating jellyfish-like enemy seen from directly above, 2D cel-shaded comic
book game art, heavy inked black outline, completely opaque solid green body with no
transparency and no see-through areas, three stubby tentacles, chunky rounded exaggerated
cartoon proportions, centered, filling the frame. Plain pure white background, no text, no
frame, no border, no drop shadow, square 1:1, isolated single creature.
```

```
A long segmented enemy worm seen from directly above, 2D cel-shaded comic book game art,
heavy inked black outline, crimson segmented body with a yellow underbelly and a needle
mouth, body stretched into a wide shallow S-curve with completely empty space inside the
curve and no closed loop, chunky rounded exaggerated cartoon proportions, centered, filling
the frame. Plain pure white background, no text, no frame, no border, no drop shadow,
square 1:1, isolated single creature.
```

### Shieldbearer (row 7)

```
A stocky armoured enemy creature seen from directly above, 2D cel-shaded comic book game
art, heavy inked black outline, flat solid muted colours, dusty steel-blue body with one
saturated hero colour of a bright red riveted iron face shield held forward on one side of
its body, chunky rounded exaggerated cartoon proportions, centered, filling the frame.
Plain pure white background, no text, no frame, no border, no drop shadow, square 1:1,
isolated single creature.
```

### Swarmer (row 8)

```
A tiny insect-like enemy creature seen from directly above, 2D cel-shaded comic book game
art, heavy inked black outline, flat solid muted colours, small round lime-green body with
six thin legs and two short antennae, chunky rounded exaggerated cartoon proportions,
centered, filling the frame. Plain pure white background, no text, no frame, no border, no
drop shadow, square 1:1, isolated single creature.
```

### Extra cells for a second sheet, if the roster grows past eight

The rules that made the weapon and character sheets work apply to enemies too, and both
are recorded in `docs/visual_style.md`: say the grid and the separation, name a hero colour
per subject inline, break the shape family rather than listing six variations of one
silhouette, ask for pure white and key it, and ban drop shadows and whatever went wrong
last time.

```
A sprite sheet of four separate 2D top-down arena roguelite enemy creatures arranged in a
clean 2 by 2 grid with even spacing and identical cell sizes, all seen from directly above,
each one completely separated from the others with plain empty space between them and
nothing overlapping. Every creature has a completely different silhouette and a completely
different dominant colour, no two alike. The four are: a tall spindly enemy with two long
thin legs and a small head, in bone white; a squat square enemy with a hinged metal jaw, in
rust red; a wide flat enemy shaped like a heavy disc with a single slit eye, in dark teal;
and a small round enemy with a ring of stubby spikes, in mustard yellow. Every shape has a
heavy inked black outline, completely opaque flat solid colour fills, chunky rounded
exaggerated cartoon proportions, thick bold line work, threatening but cartoon and not gory.
Plain pure white background, no text, no letters, no numbers, no labels, no UI chrome, no
border, no frame, no watermark, no drop shadow, no gradients, no realistic shading, no 3d
render, square 1:1.
```

## Order of work

1. **0.1** contact weapon export, with its test. Smallest change, unblocks the most rows. **Done.**
2. **Stage 1 row 2 (Bulwark)** — no new code, proves the sheet-to-scene pipeline end to
   end including sprite extraction and the gallery preview. **Done.**
3. **0.2** spawn table, with its test. Needed before any of the rows are actually *seen*. **Done.**
4. **Stage 1 rows 1, 3, 5** — the three that need only config on top of 0.1/0.2.
   **Row 1 (Gunner) done**, rows 3 and 5 are not.
5. **0.5 + Stage 1 row 4 (Lancer)** — the first genuinely new AI plus its own animation
   library. **0.5 done**, the row itself is not.
6. **0.4** was folded into row 5; if that lands late, split it back out. **Done, split back out.**
7. Stretch: **0.6** Blink, **0.7** Shieldbearer, **Swarmer**, **Elites**.

## Docs to update when this ships

- `docs/systems/enemies.md` — the roster, and the death-animation and stage-end
  limitations it already lists, which the splitter interacts with. **The Stage 0 half is
  updated, and so are the roster rows for the Bulwark and the Gunner.**
- `docs/systems/spawners.md` — the spawn table replaces "always `Enemy.tscn`". **Done.**
- `docs/systems/balance.md` — per-type budget rows and the enemy TTK numbers. **The
  contact-weapon note is updated, and the per-type rows carry the Bulwark and the Gunner.**
- `docs/architecture.md` — the new behaviours and the enemy scenes it names. **The Stage 0
  half is updated, and so is the list of enemy scenes.**

**Do not index this plan in `docs/ai_overview.md`.**
`test/test_doc_links.gd::test_index_does_not_list_archived_plans_as_live` asserts that
`docs/plans/` appears nowhere in that index. The link suite *does* walk this file, so every
project path named here has to resolve — which is why proposed new paths above live in
fenced blocks rather than inline backticks. Keep it that way, and when each file lands,
move its path into an inline backtick.