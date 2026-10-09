# Balance

Purpose
- The single source of truth for **how much power a weapon, item, modifier or character is allowed to give**, and how to check a new one before it ships.
- **Read this before adding a weapon, an item, a modifier or a character.** Section 5 (weapons) and Section 7 (modifiers) end in copy-paste checklists.
- This document is **prescriptive** — it states rules, not facts about the code. It is deliberately kept free of audit material so it stays stable: when the game changes, this file should not need to. What the game does *today*, including where it breaks these rules, lives in **`docs/systems/balance_audit.md`**.
- Conventions: **[CURRENT]** marks a statement about the code as written. **[PROPOSED]** marks the intended target state, not yet implemented. A rule marked **[PROPOSED]** is not enforced by code.

---

## 1. The core rule

> ### An item changes a character's power by **at most +15%**. Never more.
>
> A single item may never add more than 15% to a character's offense or its
> survivability, no matter what it does mechanically. If an item needs to feel
> bigger than that, it is a weapon (Section 5), not an item.

Why 15% and not "as much as feels good":

- With a +15% ceiling, reaching **5× baseline power takes ~12 items** (`ln 5 / ln 1.15 ≈ 11.9`). That is a normal roguelike run length, and it means every item you pick is a real decision instead of a rounding error.
- Without a ceiling, one item decides the run. A build is only as strong as its luckiest offer, and the shop cannot be balanced by tuning enemy HP because the player's power has no upper bound.
- The ceiling is per item, **not per stack**. Three cheap items that each give +15% are fine (+49%). One item that gives +300% is not, because the player cannot decline it without declining the whole offer row.

### 1.1 How power is measured

Two independent axes. An item is legal only if it is under the cap on **both**.

**OFF — offense**, `WB` (weapon budget):

```
WB = damage_per_volley × attacks_per_second

# from BaseWeapon.gd:88-92 and BaseWeapon.gd:96
damage_per_hit  = (weapon.base_damage + stats.get_stat("flat_damage")) × stats.get_stat("damage")
attacks_per_sec = stats.get_stat("attack_speed") × weapon.base_attack_speed
```

`WB` is always evaluated **at baseline character stats** (`damage 1.0`, `flat_damage 0.0`, `attack_speed 1.0`, no items) unless stated otherwise. That is deliberate: the character's items then multiply every weapon equally, so weapons stay comparable to each other forever. A weapon's own two `.tres` numbers never change; the character around it does.

Section 5 splits this into `WB_raw` (the `.tres` numbers) and `WB_solo` (after the uptime discount). `WB` here means `WB_solo` — use whichever the surrounding section names.

**DEF — survivability**, `EHP` (effective hit points), over a 10-second exposure window:

```
mitigation   = 10.0 / (10.0 + armor)          # armor_modifier.gd:41-46
shield_pool  = energy_shield + heal_per_second × 10.0
EHP          = (max_health + shield_pool) / mitigation
```

The 10-second window is what makes regen and life leech scoreable: a +4 HP/0.5s regen (`regen_modifier.gd:36`) is +80 EHP, not a rounding error.

**Δ% = (after − before) / before**, per axis. Report both.

### 1.2 The two hard failures this rule exists to prevent

| Failure | What it looks like | Rule that stops it |
|---|---|---|
| **Item inflation** | One item is worth +200% or more. | §2 item budget table, §3 per-stat budgets. |
| **Snowball** | A weapon found at loop 3 doubles a build that already has 10 items. | §4.4 anti-snowball rule. |

---

## 2. Power budgets at a glance

### 2.1 Items — price **is** the budget

`ItemPriceAnalyzer` (`src/Systems/Items/item_price_analyzer.gd:7-10`) already prices offers in four bands. Make the bands mean something: **the price of an item is its power budget.** An offer is correct if a player would be happy to pay that many stat items' worth of a smaller gain for it.

| Price | Category | Share of generated offers **[CURRENT]** | Target Δ power | **Hard cap** | May do |
|---|---|---|---|---|---|
| 1 | Stat item | 40% (`item_factory.gd:178`) | +3 … +5% | **+5%** | Change exactly one stat, by a small amount |
| 2 | Buff / debuff | 30% (`:180`) | +5 … +8% | **+10%** | Temporarily change one stat |
| 3 | Effect / modifier | 25% (`:182`) | +8 … +12% | **+15%** | Add one mechanic |
| 5 | Weapon | 10% (`shop_menu.gd:22`) | ×1.10 … ×1.25 | **×1.25** | Replace the character's damage engine |

A **cursed** item (the 35% roll, `item_factory.gd:18`) keeps the same band but **must** carry a real downside of **1.0 … 1.2× the magnitude of its upside** (§3.2). A curse that is a no-op on the current character is a bug, not a free item.

### 2.2 Weapons

All figures are `WB_solo` (§4.1) — the effective DPS a weapon actually delivers, uptime included. Stated as multiples of the T0 reference so the table is archetype-independent: the Fist is `WB_raw 10.0` at melee uptime 0.70, so `WB_solo 7.0`. A ranged T1 with `WB_raw 8.0` at uptime 0.95 is `WB_solo 7.6` — the same tier.

| Tier | `WB_solo` | Multiple of T0 | Where it appears |
|---|---|---|---|
| **T0 starting** | 7.0 | 1.00× | Character's innate weapon. Not purchasable, not in `src/Resources/weapons`. |
| **T1 common** | 7.5 – 9.0 | 1.10 – 1.25× | Early shop, price 5 |
| **T2 uncommon** | 10.0 – 11.5 | 1.40 – 1.60× | Mid shop |
| **T3 rare** | 13.0 – 15.5 | 1.80 – 2.20× | Late shop |
| **T4 legendary** | 18.0 – 21.0 | 2.50 – 3.00× | ≤ 1 per run |

Full design rules and a worked example in Section 5.

### 2.3 The scaling budget across a whole run

**[PROPOSED]** Total player power at the end of each loop, measured in multiples of the T0 baseline:

| Point in run | Target power | How it should be reached |
|---|---|---|
| Loop 1 start | 1.0× | Starting weapon only |
| Loop 1 end | 1.8 – 2.2× | ~4-5 items |
| Loop 2 end | 3.0 – 3.5× | +1 weapon, ~8-10 items |
| Loop 3 end (win) | 4.5 – 6.0× | ~12-14 items |

Enemy HP grows ×5 across the run (`enemy_spawner.gd:14`, `10 → 30 → 50`). A build at 5× baseline damage clears loop 3 at the same time-to-kill it started with — that is the intended shape of the curve. If the player cannot reach 4.5×, the item budgets in §2.1 are too low; if they reach 20×, they are too high.

---

## 3. Item generation budgets

**[PROPOSED] throughout.** This section is the target state for the generator. What the generator does today — the single `5-10% of base` roll and the degenerate `drop_pool` — is described in `docs/systems/item_factory.md`, and the specific numbers it produces wrong are rows 6, 7, 8, 19 and 23 of `docs/systems/balance_audit.md`.

### 3.1 Per-stat budget table

Every stat gets an explicit **Δ% per price-1 item**, plus a **cap on the total** the character may hold. The generator rolls inside the band; the caps are the real balance mechanism, because they stop a build from stacking one stat into a runaway.

| Stat | Price-1 item gives | Cap | Why |
|---|---|---|---|
| `damage` | **+3%** (percent) | ×3.0 | Cleanest WB scaling; multiplies everything |
| `attack_speed` | **+3%** (percent) | ×3.0 | Multiplies on-hit riders too (§6.1) — capped harder than it looks |
| `flat_damage` | **+1.0** (flat) | **+3.0 total** | Flat on a 5-10 `base_damage` weapon is 10-20% WB. Cap is mandatory |
| `health` | **+3% of max HP** | +100% | Percentage, not absolute, so it is character-independent |
| `armor` | **+1.0** | +15 | +1 armor = +10% EHP at 0 armor, +4% at 15 |
| `energy_shield` | **+1.5** | +30 | Recharges at 10/s, so 1 point ≈ 0.5 HP sustained |
| `movement_speed` | **+2%** | ×2.0 (600 px/s) | Both an offensive (kiting) and defensive tool — costs ~3% |
| `critical_chance` | **+2 pp** | +60 pp | 0-100 scale (`crit_modifier.gd:27`); at 1.5× mult, 1 pp = +0.5% WB |
| `critical_multiplier` | **+0.02** | ×3.0 | Only worth anything alongside `critical_chance` |
| `lifeleach` | **+0.10** (flat) | +1.0 total (stat ≤ 2.0 = 10% lifesteal) | Double-dipping: it is simultaneously +1% OFF and +1% DEF. Scale is 0-1, so a "1.0" item is a 2× not a 1% |
| `projectile_pierce` | **+1** | +2 | Only meaningful for projectile weapons; +1 is a doubling on a piercing one |
| `projectile_speed_multiplier` | **+3%** | ×2.0 | Mostly uptime; low weight in the candidate pool |
| `area_size_multiplier` | **+2%** | ×2.0 | Area damage scales ~r², so +2% radius = +4% AoE damage |
| `base_damage` (stat) | **+3%** | ×2.0 | Rename to `secondary_damage`; only two modifiers read it (§6.3) |
| `attack_range`, `area_radius` | — | — | **Remove from the candidate pool.** No code reads them |

Buff and debuff items use the same table, scaled by the price-2 band: a price-2 buff gives **2× the price-1 amount** and lasts `duration` seconds (default 3.0), with `max_stacks 10` — both defaults on `src/Systems/Items/Buffs/buff.gd`. Budget the *time-averaged* value, not the peak: `amount × min(duration, expected_uptime)`. A buff applies its payload **once per stack**, so the peak it actually reaches is `amount × stacks` — that is why the HUD's buff tile reports the multiplied total (`docs/systems/items.md`), and it is the number to budget against, not `amount`.

### 3.2 The curse — its budget **[PROPOSED]**

Every generated item gets exactly one downside, 35% of the time a real `COST` modifier (`FlatLifeDrainModifier`, `PercentLifeDrainModifier`) and otherwise a negated stat at ×1.0 or ×2.0 scale. **[CURRENT]** — see `docs/systems/item_factory.md`, "Gift and curse", for the two shapes and the `_roll_negative_modifier` split. The rules:

- **Curse magnitude = 1.0 … 1.2× the gift.** Use the §3.1 table for the gift, then take 1.0-1.2× of *that* — never a second independent roll. Today the curse is re-rolled independently (`_roll_negative_stat` calls `_generate_stat_modifiers` again), so a 0.5-HP gift can carry a 1.0-HP curse and a 1.0-HP gift a 0.5-HP curse.
- **The curse must never be a no-op.** A `-0.5 health` line on a 120 HP Soldier is a free item. Rule: if the curse's Δ% of the relevant axis is under **-1%**, re-roll the stat.
- **The curse may not target a stat the gift already used** — `_roll_negative_stat`'s `exclude` argument handles this, and the reason is in the code comment: `Dictionary.merge()` does not overwrite, so picking the same key would erase the curse.
- **`COST` modifiers are per-second drains, not one-time costs.** A `-2 HP / 0.5s` flat life drain is -4 HP/s = **-80 EHP over the §1.1 window**. Price a `COST` item's curse at 1.2× and do not let a drain item also carry a negated-stat curse.

---

## 4. Weapons — design rules

There are five weapons today and there will be dozens. Every new one is designed against this section.

### 4.1 The two numbers

A weapon resource (`BaseWeapon.gd`) exposes `base_damage` (`:8`), `base_attack_speed` (`:7`), `weapon_range` (`:9`) and a `modifiers` dict (`:10`) of built-in riders. Two derived figures decide everything:

```
WB_raw  = base_damage × base_attack_speed            # at baseline character stats
WB_solo = WB_raw × uptime                              # uptime: §4.3
```

`WB_solo` is the number that goes in the tier table (§2.2). It is measured **against one basic enemy, in range, no crits, no on-hit riders** — riders are budgeted separately in §4.5 so a weapon's baseline stays readable.

### 4.2 Archetypes and their split

Pick an archetype first; it fixes how `WB_solo` splits into rate and per-hit damage.

| Archetype | `base_attack_speed` | Hits per volley | Σ per-hit damage | `WB` per extra hit |
|---|---|---|---|---|
| Snipe / burst | 0.25 – 0.60 | 1 | 100% | n/a |
| Single shot | 0.8 – 1.2 | 1 | 100% | n/a |
| Rapid fire | 1.5 – 3.0 | 1 | 100% | n/a |
| Pellet / cone | 0.4 – 0.8 | 3 – 8 | **≤ 100%** | ≤ 33% |
| Beam / sweep | 1.0 – 2.0 | 1 tick hits all in arc | 25 – 40% per tick | ≤ 33% |
| Contact | 2.0 – 3.0 | all bodies touching | 25% each | ≤ 25% |

**Hard rules on the split:**

- `base_attack_speed ∈ [0.25, 3.0]`. **3.0 is a wall, not advice**: every on-hit rider in `src/Systems/Items/modifiers/` fires per hit, and the ones with a fixed `duration` accumulate stacks at `hits_per_second × duration` (§4.5), so raising the rate raises rider bookkeeping and projectile counts faster than it raises weapon power.
- **Pellets must never increase single-target damage.** The rule is `Σ per_hit_fraction ≤ 1.0`: 5 pellets at 20% each total exactly `base_damage` into one target and up to 2× when they split across two. At 100% each there is no reason to ever pick the single-shot weapon.
- **[CURRENT]** `Shotgun.tres` violates this: `shotgun_weapon.gd:16` sets `p.damage = current_damage / pellet_count * 2`, so Σ = **200%**. A Shotgun (`base_damage 5.0`, rate 0.5) therefore deals `5.0` into one target while its `WB_raw` says `2.5` — double its own budget and still half the Fist's 10.0. **[PROPOSED]** drop the `× 2`.

### 4.3 Uptime — why range is part of the budget

A melee weapon with `WB_raw 12` at 70% uptime delivers 8.4 effective DPS. A ranged weapon with `WB_raw 10` at 95% uptime delivers 9.5. `WB_raw` alone does not rank weapons, so every budget figure has to be stated at a real uptime:

```
WB_solo = WB_raw × uptime          # effective DPS actually delivered
WB_raw  = WB_solo / uptime = WB_solo × (1 / uptime)
```

The `1 / uptime` factor is the inflation a designer applies to the `.tres` numbers to hit a target `WB_solo`:

| Effective range | Typical uptime | Inflate `WB_raw` by |
|---|---|---|
| > 600 px (ranged) | 0.95 | ×1.05 |
| 400 – 600 px | 0.85 | ×1.18 |
| ≤ 400 px (melee swing) | 0.70 | ×1.43 |
| ≤ 60 px (contact / orbiting) | 0.90 | ×1.11 |

Movement speed is `1.0 m/s × PIXELS_PER_METER 300.0` = 300 px/s (`stats.gd:9,24`), so closing 400 px takes ~1.3 s — that is where 0.70 comes from. Use 1.0 uptime for a melee weapon with enough knockback or a dash to close reliably.

**[CURRENT]** `Fist.tres` declares `range = 300.0`, but no weapon script exports a property named `range` — `BaseWeapon` exports `weapon_range`. The line is silently ignored and the Fist swings at the 400.0 default. That is why `melee_weapon_node.gd` stretch comes out 33% wider than the file intends.

### 4.4 Anti-snowball rule **[PROPOSED]**

Two constraints, checked at the moment of purchase:

1. `WB_solo(new weapon) ≤ 1.25 × max( WB_solo(best weapon owned), WB_solo(character right now) )`
2. `WB_solo(new weapon) ≤ 1.5 × WB_solo(character right now)`

Constraint 2 is the strict one: a player who already invested in a damage build cannot double their output off one lucky offer. Constraint 1 is relative to the character's *current* output, not to the weapon alone — so a fresh player holding only a T0 Fist is correctly locked out of the upper tiers, and those tiers unlock as items raise the character past them. That is what makes "keep your best weapon" a strategy rather than a trap.

### 4.5 Budgeting on-hit riders

A weapon may declare riders in its `modifiers` dict (`weapon_builtin_effects.gd:15-35` currently supports `knockback`, `poison`, `pierce`). Riders are the easiest way to accidentally triple a weapon's power, because they fire **per hit**:

```
rider_WB = hit_damage_per_hit × hits_per_second × rider_multiplier
```

**A rider may add at most 25% of `WB_solo`.** At 25% the rider is a flavourful bonus; at 100% it is a second weapon wearing the first weapon's clothes.

The failure mode to watch for is a rider whose power is set by a `duration` rather than by a multiplier:

```
stacks  ≈ hits_per_second × duration
rider_dps = hit_damage × stacks = duration × weapon_dps
```

Note that `attack_speed` **cancels out** here — the stack count and the weapon's own DPS both scale with hit rate. What makes this dangerous is that `duration` is a bare number with no budget attached.

`PoisonModifier` has `duration 3.0`, `tick_interval 1.0` and `max_stacks 500` (`poison_modifier.gd:11-12`), applies on every hit at 99.93% chance (`:9`), and each stack ticks for the **full hit damage** (`poison_modifier.gd:39` → `poison_effect.gd:63`). So:

```
poison_dps = 3.0 × weapon_dps
```

**Poison alone is +300% WB, at any attack speed.** **[PROPOSED]** `duration 0.6` puts it at +60%, still above the 25% rider budget; the honest fix is `duration × multiplier = 0.25`.

Three more things about this modifier, all **[CURRENT]**:

- **`max_stacks 500` never binds** in normal play (9 stacks at 3 attacks/s). It is not a safety limit, it is dead configuration that reads like one.
- **`damage_per_tick` is set once and never refreshed.** `poison_effect.gd:20` assigns it in `start_effect`, and later hits only call `add_poison()`. Swapping to a bigger weapon mid-fight does not raise an already-applied poison, and `poison_modifier.gd:39`'s per-stack bonus is likewise only read at application time.
- **All poison sources on a target share one `PoisonEffect`** (`poison_modifier.gd:34-44` looks it up by name on the target's `Health`). A poisoned Death Aura and a poisoned Pistol therefore **add their stack counts together but both tick at whichever weapon applied poison first.** That is a correctness bug, not just a balance one.

The same `hits_per_second × duration` shape applies to Bomb (`bomb_on_hit_modifier.gd:8`, 30% of hit damage but attached per hit and detonating after 3 s) and to any future stacking DoT.

### 4.6 Validating against the loop curve

**[CURRENT]** enemy HP and DPS, from `enemy_spawner.gd:14-16` and `boss_spawner.gd:13-14`:

| Loop | Basic enemy HP | Basic enemy contact DPS | Boss HP | Boss weapon DPS |
|---|---|---|---|---|
| 1 | 10 | 10 | 510 | 60 |
| 2 | 30 | 20 | 1010 | 150 |
| 3 | 50 | 30 | 1510 | 312 |

(Basic enemy contact DPS = `5.0 × damage_stat × 2.0`, from the `Thorns` weapon it spawns with — `Enemy.gd:30` — so it is *per touching enemy*. Boss weapon DPS is the summed `WB_raw` of its whole loadout from `boss_spawner.gd:62-69`: 2 Fists per loop iteration, plus 2 Pistols from loop 3, plus its own contact weapon, with `damage_stat = 1 + loop`. It assumes **every melee connects**, which is the boss at best-case uptime — treat it as a ceiling, not a typical value.)

A weapon is balanced when, at the loop it is *found* in, its time-to-kill on a basic enemy lands in a band:

| Loop found in | Target TTK on a basic enemy | `WB_solo` needed at baseline |
|---|---|---|
| 1 | 1.5 – 3.0 s | 3.5 – 7.0 |
| 2 | 1.5 – 3.0 s | 10 – 20 |
| 3 | 1.5 – 3.0 s | 17 – 33 |

A T1 weapon (`WB_solo` 7.5-9.0) found at loop 3 is a dead pickup — that is the intent, and the two tables are how you tell the difference between a weapon that is under-budgeted and one that has simply outstaged its tier.

### 4.7 Worked example — designing "a slow heavy rifle"

1. **Archetype**: snipe. `base_attack_speed = 0.5`, single hit, Σ = 100%.
2. **Target**: `WB_solo = 10.0`, which lands in the T2 band (10.0-11.5). Uptime 0.95 (§4.3) → inflate `WB_raw` by ×1.05 → `WB_raw = 10.5`.
3. **Split**: `base_damage = WB_raw / base_attack_speed = 10.5 / 0.5 = 21.0`. That is the whole weapon: `base_damage 21.0`, `base_attack_speed 0.5`.
4. **No riders.** A rifle that is slow *and* carries poison is the §4.5 trap: `duration 3.0` makes the poison +300% of whatever the rifle does, and at 0.5 hits/s the stacks arrive so slowly that the tooltip promises something the fight never delivers.
5. **Validate** (§4.6). Loop 2 enemy, HP 30 → TTK 3.0 s, top of the 1.5-3.0 s band. Loop 3 enemy, HP 50 → TTK 5.0 s, over the band. So the weapon wants to appear **early-to-mid loop 2**, once the character has enough damage to keep up — which is exactly what a T2 should do.
6. **Anti-snowball** (§4.4). A fresh character's `WB_solo` is 7.0, so `10.0 ≤ 1.25 × max(7.0, 7.0) = 8.75`? **No.** The rifle is correctly *unbuyable on turn 1*. It unlocks once roughly two damage items have pushed the character to ~8.0. The rule decided this weapon's availability window without anyone noticing it by feel.

For contrast, this is what the code produces by accident: leaving `base_damage` at the `BaseWeapon` default (5.0) and `base_attack_speed` at 1.0 gives `WB_raw 5.0` and `WB_solo 4.75` — **-32% against the starting Fist**, permanently unbuyable. That is why four of the five existing weapons never set `base_damage` at all.

### 4.8 New-weapon checklist **[PROPOSED]**

```
[ ] Archetype chosen (§4.2) and base_attack_speed within [0.25, 3.0]
[ ] Sum of per-hit damage fractions <= 100% (pellets / beam ticks)
[ ] WB_raw = base_damage x base_attack_speed, and WB_solo after the §4.3 uptime multiplier
[ ] WB_solo sits inside exactly one tier band (§2.2)
[ ] Tier step from the tier below is <= 1.6x
[ ] Every declared rider <= 25% of WB_solo (§4.5)
[ ] Any rider with a `duration` budgeted as duration x multiplier <= 0.25 (§4.5)
[ ] TTK against the §4.6 loop table is 1.5-3.0s
[ ] Anti-snowball (§4.4) holds against the T0 starting weapon
[ ] target_selector is the .tres you meant (aim/ is cross-wired today - balance_audit.md #16)
[ ] sprite is set - a missing sprite means no WeaponVisual node is created (weapon_holder.gd:71)
[ ] A gdUnit4 test asserts WB_solo from the .tres (see below)
```

The last one is not optional. WB is two multiplications plus an uptime constant, and it is exactly the kind of number that silently drifts when someone edits a `.tres`:

```gdscript
# TODO: test/Systems/weapon/test_weapon_power_budget.gd  - NOT WRITTEN YET
const UPTIME := { "MeleeWeapon": 0.70, "ContactWeapon": 0.90, "ProjectileWeapon": 0.95, "AreaWeapon": 0.85 }

func test_every_weapon_solo_dps_is_in_a_tier_band() -> void:
    for weapon in load_all_weapon_tres():
        var uptime: float = UPTIME.get(weapon.get_script().get_global_name(), 0.85)
        var wb := weapon.base_damage * weapon.base_attack_speed * uptime
        assert_between(wb, TIER_MIN[weapon.tier], TIER_MAX[weapon.tier])
```

The test needs `tier` on `BaseWeapon` (see `balance_audit.md`), and the range bands have to be derived from `weapon_range` rather than the script class, or a new archetype silently gets the wrong uptime.

---

## 5. Characters

**[CURRENT]** `CharacterData.base_stats` **overwrites** `DEFAULT_STATS` entries (it is assigned into `Stats.stats` directly), so a character's power is its `base_stats` plus its `modifiers`. `WB_raw` is the Fist's `10.0` scaled by the character's `damage` and `attack_speed`; `WB_solo` applies the §4.3 melee uptime of 0.70.

| Character | `base_stats` | `modifiers` | Starting weapon | `WB_raw` | `WB_solo` |
|---|---|---|---|---|---|
| Multitasker (default) | `health 40` | — | Fist | 10.0 | **7.0** |
| Brawler | `attack_speed 1.1`, `damage 1.15`, `health 95`, `movement_speed 0.9` | `armor +4`, `damage +10%`, `ArmorModifier` | Fist | **13.9** | **9.7** |
| Ranger | `attack_speed 1.25`, `damage 0.8`, `health 35`, `movement_speed 1.25` | `attack_speed +50%` | **none** | (15.0) | (10.5) |
| Soldier | `damage 0.9`, `health 120` | `armor +12`, `ArmorModifier` | **none** | (9.0) | — |
| Wildling | `damage 0.9`, `health 120` | `armor +14`, `ArmorModifier` | **none** | (9.0) | — |

Bracketed figures are what the character *would* have with a Fist equipped. The five characters live in `src/Assets/character/<id>/<Id>.tres`; `docs/systems/characters.md` is the format reference.

**Rules [PROPOSED]:**

- A character's starting `WB_solo` must be within **±15%** of the T0 baseline (7.0). Brawler at 9.7 is **+39%** — it starts the run already ahead of every other character. Ranger would be +50%, which is a large part of why it starts unarmed.
- A character's starting `EHP` must be within **±30%** of the reference character (Multitasker, 40). **[CURRENT]** EHP spread:

| Character | `health` | `armor` | Mitigation | `EHP` | vs reference |
|---|---|---|---|---|---|
| Ranger | 35 | 0 | 1.00 | **35** | 0.88× |
| Multitasker | 40 | 0 | 1.00 | **40** | 1.00× |
| Brawler | 95 | 4 | 0.714 | **133** | 3.3× |
| Soldier | 120 | 12 | 0.455 | **264** | 6.6× |
| Wildling | 120 | 14 | 0.417 | **288** | 7.2× |

  Soldier and Wildling are **6.6-7.2× the reference survivability at run start**. Note `ArmorModifier` contributes nothing here: it reads `provided_stat() + 5 × (stacks − 1)` and `stacks` is 1, so the character's own `armor` base value is the entire contribution.
- **A character that starts with no weapon is a design error until it has one.** Ranger, Soldier and Wildling all have empty `starting_weapons`.
- `Soldier.tres` and `Wildling.tres` have **identical** `base_stats` and differ only by `armor 12` vs `14`. `Wildling.tres:6` also carries a copy-pasted Soldier description.

---

## 6. Modifiers — design rules

An effect item (price 3) and a weapon's built-in `modifiers` dict both end up as `BaseModifier` nodes under the holder. Same rules.

### 6.1 The three scaling models, and their cost

Every modifier scales with `_active_stacks()`, which is `max(1, stacks.count(true))` (`base_modifier.gd:99-100`). Three models are in use:

| Model | Shape | Cost of the Nth copy |
|---|---|---|
| **Linear in stacks** | `X × stacks` | full `X` — compounds forever, no natural stop |
| **Diminishing** | `X + S × (stacks - 1)` | constant `S`, first copy at full power — **the default, and the correct one** |
| **Multiplier on other items** | `other_item.flat × M × stacks` | exponential across every item bought after it — **banned**, see below |

The `_active_stacks()` floor at 1 means a modifier whose condition is currently false still runs at one stack of power. Conditions are therefore free damage when inactive, and any modifier with a condition must be budgeted at the condition *satisfied*.

**The banned model.** `StatMultiplierModifier` (`stat_multiplier_modifier.gd:8,28`) is `multiplier 2.0` per stack, applied to `item.modifiers[target]["flat"]` on every `on_item_added`. Two copies make every subsequently-bought damage item **+4×**. There is no cap, no ordering rule that is visible to the player, and it compounds with itself. It also has **no `.tscn`**, so it is currently unreachable in normal play — which is the only reason the game is playable at all. Keep it script-only or delete it; do not give it a scene.

### 6.2 Effect-item budget by class

Price 3, hard cap **+15% WB / +15% EHP**. Measured against the §1.1 reference frame:

| Class | Budget per item | Cap on total | Notes |
|---|---|---|---|
| Extra hit / projectile at full damage | **+25%** | 1 such item | 4 at full damage is a new weapon |
| Extra hit at reduced damage | ≤ +10% each | ≤ +30% | Pellets, orb ticks, beam segments |
| Extra **target** (pierce, chain, bounce) | **+25%** per extra target | ≤ 2 extra targets | +100% at 4 targets — a weapon, not an item |
| On-hit rider (poison, bomb, explosion) | **+20%** | ≤ 2 riders | Budget as `duration × multiplier` (§4.5) |
| Reactive rider (reflect, rocket) | **+10%** | 1 | Triggers on *taking* damage — scales with enemy DPS, not yours |
| Defensive (armor, shield, heal-on-event) | **+10% EHP** | see §3.1 caps | `EmergencyHeal` alone is +75% max HP |
| Crit | **+5% expected** | +30 pp mult | Expected value = `chance × (mult − 1)`; 0% chance = 0% |

Two notes from the current catalog:

- **`Spread` is the clearest violation**: `spread_modifier.gd:24-33` loops `range(active_count)` and spawns **two** extra projectiles per iteration, so one stack makes the weapon fire **3× as many projectiles — +200% WB** for a price-3 item. One stack should be one extra projectile (+50% at most, and that is already the whole budget).
- **`Chain` is the same problem in target space**: `chain_modifier.gd:90` sets `max_bounces * active`, and each chain projectile deals `max(base_amount, final_amount)` — full damage. Three bounces = **+300% WB** against a pack.

### 6.3 Modifiers that read the wrong stat

`base_damage` is a **standalone stat** defaulting to 5.0 (`stats.gd:19`). It is not the weapon's `base_damage`. Two modifiers derive their damage from it:

- `spinning_orbs_modifier.gd:67` — 2 orbs × 50% of 5.0 = 5.0 damage, independent of your weapon
- `reflect_projectiles_modifier.gd:31` — `base_damage` stat × multiplier, per incoming hit

On a Pistol (`WB_raw 4.0`), Spinning Orbs is **+125% WB_raw**. On a rifle with `base_damage 28.0` it is +18%. **Any modifier that derives damage from a stat instead of the weapon's damage context is a balance hazard**, because its value is inversely proportional to your build — it gets *stronger* as your weapon gets worse. Either read the weapon's `current_damage` (as `Chain` does at `chain_modifier.gd:38`, which carries the already-multiplied hit through in `damage_ctx`) or flag the modifier as build-dependent and budget it against the T0 baseline only.

### 6.4 New-modifier checklist **[PROPOSED]**

```
[ ] Scales via X + S*(stacks-1), not X*stacks, unless X is tiny
[ ] Measured delta measured on BOTH axes at the reference frame, both under +15%
[ ] If it derives damage from a stat, checked against both a 4.0 WB_raw and a 28.0 WB_raw weapon
[ ] If it fires per hit, its duration-based power is budgeted as duration x multiplier <= 0.25 (§4.5)
[ ] effect_kind = COST only if it is a genuine continuous downside
[ ] get_tooltip_stats() states the real number, not the base
[ ] gdUnit4 test for the power delta at 1 stack and at 3 stacks
```

---

## 7. Where the current game breaks these rules

Not here. See **`docs/systems/balance_audit.md`** — 23 measured violations, a fix order, and the assumptions these numbers rest on.

That separation is the point of the split. This file answers "what may a new weapon give?" and changes only when a design decision changes. The audit answers "what does the game give today?" and changes every time someone edits a `.tres`. Keeping them in one file meant every balance edit had to touch the rulebook, which is exactly the pressure that stops anyone writing the rulebook down.
