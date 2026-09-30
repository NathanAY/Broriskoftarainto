# Balance

Purpose
- The single source of truth for how much power a weapon, item or modifier is allowed to give, and how to check a new one before it ships.
- **Read this before adding a weapon, an item, a modifier or a character.** Section 5 (weapons) and Section 7 (modifiers) end in copy-paste checklists.
- This document is **prescriptive**. The game does not currently obey it — Section 8 is the audit of where it does not. Rules marked **[PROPOSED]** are not implemented yet and are the intended target state; rules marked **[CURRENT]** describe what the code does today.

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
| **Snowball** | A weapon found at loop 3 doubles a build that already has 10 items. | §5.4 anti-snowball rule. |

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

A **cursed** item (the 35% roll, `item_factory.gd:18`) keeps the same band but **must** carry a real downside of **1.0 … 1.2× the magnitude of its upside** (§3.4). A curse that is a no-op on the current character is a bug, not a free item.

### 2.2 Weapons

All figures are `WB_solo` (§5.1) — the effective DPS a weapon actually delivers, uptime included. Stated as multiples of the T0 reference so the table is archetype-independent: the Fist is `WB_raw 10.0` at melee uptime 0.70, so `WB_solo 7.0`. A ranged T1 with `WB_raw 8.0` at uptime 0.95 is `WB_solo 7.6` — the same tier.

| Tier | `WB_solo` | Multiple of T0 | Where it appears |
|---|---|---|---|
| **T0 starting** | 7.0 | 1.00× | Character's innate weapon. Not purchasable, not in `res://src/Resources/weapons`. |
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

## 3. Item generation strategies

### 3.1 What the factory does **[CURRENT]**

`src/Systems/Items/item_factory.gd`. Two entry points:

- `get_item_from_pool_or_generate()` (`:117`) — the shop and enemy drops call this. Pulls from `drop_pool`, generating with probability `1 / (pool_size + 2)`.
- `get_item_by_type(type, index)` (`:154`) — deterministic, used by the debug/configure panel.

`generate_random_item()` (`:165`) picks a category, then the category generator picks a stat and a value:

| Category | Generator | What it rolls | Curse scale (`:330`) |
|---|---|---|---|
| Stat item (40%) | `_generate_stat_item` `:188` | 1 random stat, 1 flat value | ×1.0 |
| Effect item (30%) | `_generate_effect_item` `:214` | 1 random BENEFIT modifier scene | ×2.0 negated stat |
| Buff item (15%) | `_generate_buff_item` `:263` | 1 stat, injected into `buff.tscn` | ×1.0 |
| Debuff item (15%) | `_generate_debuff_item` `:288` | 1 stat, **negated**, into `DebuffSource.tscn` | ×2.0 |

The candidate stat pool (`:104-115`) is every key in `Stats.DEFAULT_STATS` plus every `provided_stat` a modifier advertises (`lifeleach`, `armor`). **Uniform pick, no weighting** — the factory has no idea that `attack_range` is worth 0% and `lifeleach` is worth double.

Modifiers may randomize themselves at generation time via `randomize_for_generation(context)` (`:432`). Two do: `HealOnEventModifier` picks one of five trigger/heal pairs, `StatOnKillModifier` picks a target stat and a 5-10%-of-base amount. Treat any new modifier that implements this hook as a **weapon-grade** design (§7.2) — it is choosing its own power.

### 3.2 The value roll, and why it is the core balance bug **[CURRENT]**

```gdscript
# item_factory.gd:456-464
func _generate_stat_modifiers(_chosen_stat, base_value) -> Dictionary:
    if base_value == 0:
        modifier_value["flat"] = 1
    else:
        modifier_value["flat"] = base_value * rng.randf_range(0.05, 0.1)
```

**One formula for all 14 stats.** "5-10% of base" reads like a percentage budget and is not one:

**The `base_value == 0` branch is the worst of them.** Six stats in the pool have a base of 0 (`energy_shield`, `critical_chance`, `flat_damage`, `projectile_pierce` are 0.0 in `DEFAULT_STATS`; `armor` and `lifeleach` are not in the table at all, so `.get` returns 0.0). All six roll a **hard constant `1.0`, with no RNG call and no scaling by the stat's actual scale** — a `1.0` means +1 percentage point on a 0-100 stat, +10% EHP on armor, and a doubling on a 0-1 multiplier stat.

| Stat | Base | Roll | What 5-10% actually buys |
|---|---|---|---|
| `health` | 10.0 | 0.5 – 1.0 | +0.4% on a Soldier (120 HP) … +2.5% on a Multitasker (40 HP). Same item, 6× spread. |
| `attack_speed` | 1.0 | 0.05 – 0.10 | +5-10% WB. Also multiplies every on-hit rider (§7.1). |
| `critical_chance` | 0.0 | **1.0 (constant)** | +1 pp of a 0-100 scale → **+0.5% WB**, and always exactly the same number. |
| `armor` | not in `DEFAULT_STATS` | **1.0 (constant)** | **+10% EHP**, and it compounds with `ArmorModifier`'s +5/stack (§8 #4). |
| `lifeleach` | not in `DEFAULT_STATS` | **1.0 (constant)** | Stat goes `1.0 → 2.0`, so `LifeLeachModifier`'s 5% lifesteal (`life_leach_modifier.gd:6,26`) **doubles to 10%**. One price-1 item doubles the build's only stat. |
| `flat_damage` | 0.0 | **1.0 (constant)** | +10% WB on a Fist, +20% on a Shotgun. Unbounded vs weapon tier. |
| `projectile_pierce` | 0.0 | **1.0 (constant)** | +1 target on a Pistol that already pierces 1 → **+100% WB**. |
| `attack_range`, `area_radius` | 500.0 / 1.0 | 25-50 / 0.05-0.10 | **Nothing. No code reads either stat.** |
| `base_damage` (stat) | 5.0 | 0.25 – 0.5 | Nothing, until you also hold Spinning Orbs or Reflect, then +5-10% (§7.3). |

Three structural problems, all fixable without new systems:

1. **`base_value` is read from the wrong character.** `:192` reads `stats.stats` off the factory's own `$Stats` child (`ItemFactory.tscn` → `Stats.tscn` → `DEFAULT_STATS`), not from `GlobalGameState.current_character`. Generation is blind to the character that will wear the item, so a flat roll cannot be a fair percentage. **[PROPOSED]** Pass the holder's `Stats` into the generator and roll a **percentage of the holder's current value**, so `+3% max_health` means the same thing on every character.
2. **The `base_value == 1` branch (`:460`) is dead code** — identical body to the `else`.
3. **Dead stats are in the pool.** `attack_range` and `area_radius` appear in `DEFAULT_STATS` (`stats.gd:22-23`) and have tooltip text (`item_tooltip.gd:24-25`) but nothing reads them. A generated "Attack Range Plus" costs a full price-1 slot and does literally nothing. Remove them from `_candidate_stat_names()`.

### 3.3 **[PROPOSED]** Replace the single roll with a per-stat budget table

Every stat gets an explicit **Δ% per price-1 item**, plus a **cap on the total** the character may hold. The generator rolls inside the band; the caps are the real balance mechanism, because they stop a build from stacking one stat into a runaway.

| Stat | Price-1 item gives | Cap | Why |
|---|---|---|---|
| `damage` | **+3%** (percent) | ×3.0 | Cleanest WB scaling; multiplies everything |
| `attack_speed` | **+3%** (percent) | ×3.0 | Multiplies on-hit riders too (§7.1) — capped harder than it looks |
| `flat_damage` | **+1.0** (flat) | **+3.0 total** | Flat on a 5-10 `base_damage` weapon is 10-20% WB. Cap is mandatory |
| `health` | **+3% of max HP** | +100% | Percentage, not absolute, so it is character-independent |
| `armor` | **+1.0** | +15 | +1 armor = +10% EHP at 0 armor, +4% at 15. See §8 |
| `energy_shield` | **+1.5** | +30 | Recharges at 10/s, so 1 point ≈ 0.5 HP sustained |
| `movement_speed` | **+2%** | ×2.0 (600 px/s) | Both an offensive (kiting) and defensive tool — costs ~3% |
| `critical_chance` | **+2 pp** | +60 pp | 0-100 scale (`crit_modifier.gd:27`); at 1.5× mult, 1 pp = +0.5% WB |
| `critical_multiplier` | **+0.02** | ×3.0 | Only worth anything alongside `critical_chance` |
| `lifeleach` | **+0.10** (flat) | +1.0 total (stat ≤ 2.0 = 10% lifesteal) | Double-dipping: it is simultaneously +1% OFF and +1% DEF. Scale is 0-1, so a "1.0" item is a 2× not a 1% |
| `projectile_pierce` | **+1** | +2 | Only meaningful for projectile weapons; +1 is a doubling on a piercing one |
| `projectile_speed_multiplier` | **+3%** | ×2.0 | Mostly uptime; low weight in the candidate pool |
| `area_size_multiplier` | **+2%** | ×2.0 | Area damage scales ~r², so +2% radius = +4% AoE damage |
| `base_damage` (stat) | **+3%** | ×2.0 | Rename to `secondary_damage`; only two modifiers read it (§7.3) |
| `attack_range`, `area_radius` | — | — | **Remove from the candidate pool.** No code reads them |

Buff and debuff items use the same table, scaled by the price-2 band: a price-2 buff gives **2× the price-1 amount** and lasts `duration` seconds (default 3.0, `buff.gd:5`), with `max_stacks 10` (`buff.gd:6`). Budget the *time-averaged* value, not the peak: `amount × min(duration, expected_uptime)`.

### 3.4 The curse **[CURRENT]** and its budget **[PROPOSED]**

Every generated item gets exactly one downside (`:88-91`), 35% of the time a real `COST` modifier (`FlatLifeDrainModifier`, `PercentLifeDrainModifier`) and otherwise a negated stat at ×1.0 or ×2.0 scale. Rules:

- **Curse magnitude = 1.0 … 1.2× the gift.** Use the §3.3 table for the gift, then take 1.0-1.2× of *that* — never a second independent roll. Today the curse is re-rolled independently (`_roll_negative_stat` calls `_generate_stat_modifiers` again), so a 0.5-HP gift can carry a 1.0-HP curse and a 1.0-HP gift a 0.5-HP curse.
- **The curse must never be a no-op.** A `-0.5 health` line on a 120 HP Soldier is a free item. Rule: if the curse's Δ% of the relevant axis is under **-1%**, re-roll the stat.
- **The curse may not target a stat the gift already used** — `_roll_negative_stat`'s `exclude` argument (`:330`) handles this, and the reason is in the code comment: `Dictionary.merge()` does not overwrite, so picking the same key would erase the curse.
- **`COST` modifiers are per-second drains, not one-time costs.** A `-2 HP / 0.5s` flat life drain is -4 HP/s = **-80 EHP over the §1.1 window**. Price a `COST` item's curse at 1.2× and do not let a drain item also carry a negated-stat curse.

---

## 4. `drop_pool` **[CURRENT, known degenerate]**

```gdscript
# item_factory.gd:117-130
if rng.randi_range(0, pool_size) < pool_size:   # inclusive on both ends
    return drop_pool.pick_random()
```

`randi_range` is inclusive, so the pool branch fires with probability `(N+1)/(N+2)` — **at least 50%, asymptotically 100%**. Every generated item is appended, nothing is ever evicted, and the pool is never reset per loop. A run converges to re-offering the same handful of items.

**[PROPOSED]** Cap generation probability at a constant (say 30%) instead of deriving it from pool size, cap `drop_pool` at ~20 entries with LRU eviction, and clear it on loop change. Note the shop fixture in `test/tools/shop_ui_preview.gd:104` pins `rng.seed` for exactly this reason — any change here needs that fixture re-tuned.

---

## 5. Weapons — design rules

There are five weapons today and there will be dozens. Every new one is designed against this section.

### 5.1 The two numbers

A weapon resource (`BaseWeapon.gd`) exposes `base_damage` (`:8`), `base_attack_speed` (`:7`), `weapon_range` (`:9`) and a `modifiers` dict (`:10`) of built-in riders. Two derived figures decide everything:

```
WB_raw  = base_damage × base_attack_speed            # at baseline character stats
WB_solo = WB_raw × uptime                              # uptime: §5.3
```

`WB_solo` is the number that goes in the tier table (§2.2). It is measured **against one basic enemy, in range, no crits, no on-hit riders** — riders are budgeted separately in §5.5 so a weapon's baseline stays readable.

### 5.2 Archetypes and their split

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

- `base_attack_speed ∈ [0.25, 3.0]`. **3.0 is a wall, not advice**: every on-hit rider in `src/Systems/Items/modifiers/` fires per hit, and the ones with a fixed `duration` accumulate stacks at `hits_per_second × duration` (§5.5), so raising the rate raises rider bookkeeping and projectile counts faster than it raises weapon power.
- **Pellets must never increase single-target damage.** The rule is `Σ per_hit_fraction ≤ 1.0`: 5 pellets at 20% each total exactly `base_damage` into one target and up to 2× when they split across two. At 100% each there is no reason to ever pick the single-shot weapon.
- `Shotgun.tres` violates this: `shotgun_weapon.gd:16` sets `p.damage = _current_damage / pellet_count * 2`, so Σ = **200%**. A Shotgun (`base_damage 5.0`, rate 0.5) therefore deals `5.0` into one target while its `WB_raw` says `2.5` — double its own budget and still half the Fist's 10.0. **[PROPOSED]** drop the `× 2`.

### 5.3 Uptime — why range is part of the budget

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

**`Fist.tres` has a data bug worth knowing about**: it declares `range = 300.0`, but no weapon script exports a property named `range` — `BaseWeapon` exports `weapon_range`. The line is silently ignored and the Fist swings at the 400.0 default. That is why `melee_weapon_node.gd` stretch comes out 33% wider than the file intends.

### 5.4 Anti-snowball rule **[PROPOSED]**

Two constraints, checked at the moment of purchase:

1. `WB_solo(new weapon) ≤ 1.25 × max( WB_solo(best weapon owned), WB_solo(character right now) )`
2. `WB_solo(new weapon) ≤ 1.5 × WB_solo(character right now)`

Constraint 2 is the strict one: a player who already invested in a damage build cannot double their output off one lucky offer. Constraint 1 is relative to the character's *current* output, not to the weapon alone — so a fresh player holding only a T0 Fist is correctly locked out of the upper tiers, and those tiers unlock as items raise the character past them. That is what makes "keep your best weapon" a strategy rather than a trap.

### 5.5 Budgeting on-hit riders

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

**Poison alone is +300% WB, at any attack speed.** `[PROPOSED]` `duration 0.6` puts it at +60%, still above the 25% rider budget; the honest fix is `duration × multiplier = 0.25`.

Three more things about this modifier:

- **`max_stacks 500` never binds** in normal play (9 stacks at 3 attacks/s). It is not a safety limit, it is dead configuration that reads like one.
- **`damage_per_tick` is set once and never refreshed.** `poison_effect.gd:20` assigns it in `start_effect`, and later hits only call `add_poison()`. Swapping to a bigger weapon mid-fight does not raise an already-applied poison, and `poison_modifier.gd:39`'s per-stack bonus is likewise only read at application time.
- **All poison sources on a target share one `PoisonEffect`** (`poison_modifier.gd:34-44` looks it up by name on the target's `Health`). A poisoned Knife and a poisoned Pistol therefore **add their stack counts together but both tick at whichever weapon applied poison first.** That is a correctness bug, not just a balance one.

The same `hits_per_second × duration` shape applies to Bomb (`bomb_on_hit_modifier.gd:8`, 30% of hit damage but attached per hit and detonating after 3 s) and to any future stacking DoT.

### 5.6 Validating against the loop curve

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

### 5.7 Worked example — designing "a slow heavy rifle"

1. **Archetype**: snipe. `base_attack_speed = 0.5`, single hit, Σ = 100%.
2. **Target**: `WB_solo = 10.0`, which lands in the T2 band (10.0-11.5). Uptime 0.95 (§5.3) → inflate `WB_raw` by ×1.05 → `WB_raw = 10.5`.
3. **Split**: `base_damage = WB_raw / base_attack_speed = 10.5 / 0.5 = 21.0`. That is the whole weapon: `base_damage 21.0`, `base_attack_speed 0.5`.
4. **No riders.** A rifle that is slow *and* carries poison is the §5.5 trap: `duration 3.0` makes the poison +300% of whatever the rifle does, and at 0.5 hits/s the stacks arrive so slowly that the tooltip promises something the fight never delivers.
5. **Validate** (§5.6). Loop 2 enemy, HP 30 → TTK 3.0 s, top of the 1.5-3.0 s band. Loop 3 enemy, HP 50 → TTK 5.0 s, over the band. So the weapon wants to appear **early-to-mid loop 2**, once the character has enough damage to keep up — which is exactly what a T2 should do.
6. **Anti-snowball** (§5.4). A fresh character's `WB_solo` is 7.0, so `10.0 ≤ 1.25 × max(7.0, 7.0) = 8.75`? **No.** The rifle is correctly *unbuyable on turn 1*. It unlocks once roughly two damage items have pushed the character to ~8.0. The rule decided this weapon's availability window without anyone noticing it by feel.

For contrast, this is what the code produces by accident: leaving `base_damage` at the `BaseWeapon` default (5.0) and `base_attack_speed` at 1.0 gives `WB_raw 5.0` and `WB_solo 4.75` — **-32% against the starting Fist**, permanently unbuyable. That is why four of the five existing weapons never set `base_damage` at all.

### 5.8 New-weapon checklist **[PROPOSED]**

```
[ ] Archetype chosen (§5.2) and base_attack_speed within [0.25, 3.0]
[ ] Sum of per-hit damage fractions <= 100% (pellets / beam ticks)
[ ] WB_raw = base_damage x base_attack_speed, and WB_solo after the §5.3 uptime multiplier
[ ] WB_solo sits inside exactly one tier band (§2.2)
[ ] Tier step from the tier below is <= 1.6x
[ ] Every declared rider <= 25% of WB_solo (§5.5)
[ ] Any rider with a `duration` budgeted as duration x multiplier <= 0.25 (§5.5)
[ ] TTK against the §5.6 loop table is 1.5-3.0s
[ ] Anti-snowball (§5.4) holds against the T0 starting weapon
[ ] target_selector is the .tres you meant (aim/ is cross-wired today, see §8)
[ ] sprite is set — a missing sprite means no WeaponVisual node is created (weapon_holder.gd:71)
[ ] A gdUnit4 test asserts WB_solo from the .tres (see below)
```

The last one is not optional. WB is two multiplications plus an uptime constant, and it is exactly the kind of number that silently drifts when someone edits a `.tres`:

```gdscript
# test/Systems/weapons/test_weapon_power_budget.gd
const UPTIME := { "MeleeWeapon": 0.70, "ContactWeapon": 0.90, "ProjectileWeapon": 0.95, "AreaWeapon": 0.85 }

func test_every_weapon_solo_dps_is_in_a_tier_band() -> void:
    for weapon in load_all_weapon_tres():
        var uptime: float = UPTIME.get(weapon.get_script().get_global_name(), 0.85)
        var wb := weapon.base_damage * weapon.base_attack_speed * uptime
        assert_between(wb, TIER_MIN[weapon.tier], TIER_MAX[weapon.tier])
```

The test needs `tier` on `BaseWeapon` (§9), and the range bands have to be derived from `weapon_range` rather than the script class, or a new archetype silently gets the wrong uptime.

---

## 6. Characters

**[CURRENT]** `CharacterData.base_stats` **overwrites** `DEFAULT_STATS` entries (it is assigned into `Stats.stats` directly), so a character's power is its `base_stats` plus its `modifiers`. `WB_raw` is the Fist's `10.0` scaled by the character's `damage` and `attack_speed`; `WB_solo` applies the §5.3 melee uptime of 0.70.

| Character | `base_stats` | `modifiers` | Starting weapon | `WB_raw` | `WB_solo` |
|---|---|---|---|---|---|
| Multitasker (default) | `health 40` | — | Fist | 10.0 | **7.0** |
| Brawler | `attack_speed 1.1`, `damage 1.15`, `health 95`, `movement_speed 0.9` | `armor +4`, `damage +10%`, `ArmorModifier` | Fist | **13.9** | **9.7** |
| Ranger | `attack_speed 1.25`, `damage 0.8`, `health 35`, `movement_speed 1.25` | `attack_speed +50%` | **none** | (15.0) | (10.5) |
| Soldier | `damage 0.9`, `health 120` | `armor +12`, `ArmorModifier` | **none** | (9.0) | — |
| Wildling | `damage 0.9`, `health 120` | `armor +14`, `ArmorModifier` | **none** | (9.0) | — |

Bracketed figures are what the character *would* have with a Fist equipped.

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

## 7. Modifiers — design rules

An effect item (price 3) and a weapon's built-in `modifiers` dict both end up as `BaseModifier` nodes under the holder. Same rules.

### 7.1 The three scaling models, and their cost

Every modifier scales with `_active_stacks()`, which is `max(1, stacks.count(true))` (`base_modifier.gd:99-100`). Three models are in use:

| Model | Shape | Cost of the Nth copy |
|---|---|---|
| **Linear in stacks** | `X × stacks` | full `X` — compounds forever, no natural stop |
| **Diminishing** | `X + S × (stacks - 1)` | constant `S`, first copy at full power — **the default, and the correct one** |
| **Multiplier on other items** | `other_item.flat × M × stacks` | exponential across every item bought after it — **banned**, see below |

The `_active_stacks()` floor at 1 means a modifier whose condition is currently false still runs at one stack of power. Conditions are therefore free damage when inactive, and any modifier with a condition must be budgeted at the condition *satisfied*.

**The banned model.** `StatMultiplierModifier` (`stat_multiplier_modifier.gd:8,28`) is `multiplier 2.0` per stack, applied to `item.modifiers[target]["flat"]` on every `on_item_added`. Two copies make every subsequently-bought damage item **+4×**. There is no cap, no ordering rule that is visible to the player, and it compounds with itself. It also has **no `.tscn`**, so it is currently unreachable in normal play — which is the only reason the game is playable at all. Keep it script-only or delete it; do not give it a scene.

### 7.2 Effect-item budget by class

Price 3, hard cap **+15% WB / +15% EHP**. Measured against the §1.1 reference frame:

| Class | Budget per item | Cap on total | Notes |
|---|---|---|---|
| Extra hit / projectile at full damage | **+25%** | 1 such item | 4 at full damage is a new weapon |
| Extra hit at reduced damage | ≤ +10% each | ≤ +30% | Pellets, orb ticks, beam segments |
| Extra **target** (pierce, chain, bounce) | **+25%** per extra target | ≤ 2 extra targets | +100% at 4 targets — a weapon, not an item |
| On-hit rider (poison, bomb, explosion) | **+20%** | ≤ 2 riders | Budget as `duration × multiplier` (§5.5) |
| Reactive rider (reflect, rocket) | **+10%** | 1 | Triggers on *taking* damage — scales with enemy DPS, not yours |
| Defensive (armor, shield, heal-on-event) | **+10% EHP** | see §3.3 caps | `EmergencyHeal` alone is +75% max HP |
| Crit | **+5% expected** | +30 pp mult | Expected value = `chance × (mult − 1)`; 0% chance = 0% |

Two notes from the current catalog:

- **`Spread` is the clearest violation**: `spread_modifier.gd:24-33` loops `range(active_count)` and spawns **two** extra projectiles per iteration, so one stack makes the weapon fire **3× as many projectiles — +200% WB** for a price-3 item. One stack should be one extra projectile (+50% at most, and that is already the whole budget).
- **`Chain` is the same problem in target space**: `chain_modifier.gd:90` sets `max_bounces * active`, and each chain projectile deals `max(base_amount, final_amount)` — full damage. Three bounces = **+300% WB** against a pack.

### 7.3 Modifiers that read the wrong stat

`base_damage` is a **standalone stat** defaulting to 5.0 (`stats.gd:19`). It is not the weapon's `base_damage`. Two modifiers derive their damage from it:

- `spinning_orbs_modifier.gd:67` — 2 orbs × 50% of 5.0 = 5.0 damage, independent of your weapon
- `reflect_projectiles_modifier.gd:31` — `base_damage` stat × multiplier, per incoming hit

On a Pistol (`WB_raw 4.0`), Spinning Orbs is **+125% WB_raw**. On a rifle with `base_damage 28.0` it is +18%. **Any modifier that derives damage from a stat instead of the weapon's damage context is a balance hazard**, because its value is inversely proportional to your build — it gets *stronger* as your weapon gets worse. Either read the weapon's `_current_damage` (as `Chain` does at `chain_modifier.gd:39-43`) or flag the modifier as build-dependent and budget it against the T0 baseline only.

### 7.4 New-modifier checklist **[PROPOSED]**

```
[ ] Scales via X + S*(stacks-1), not X*stacks, unless X is tiny
[ ] Measured delta measured on BOTH axes at the reference frame, both under +15%
[ ] If it derives damage from a stat, checked against both a 4.0 WB_raw and a 28.0 WB_raw weapon
[ ] If it fires per hit, its duration-based power is budgeted as duration x multiplier <= 0.25 (§5.5)
[ ] effect_kind = COST only if it is a genuine continuous downside
[ ] get_tooltip_stats() states the real number, not the base
[ ] gdUnit4 test for the power delta at 1 stack and at 3 stacks
```

---

## 8. Audit — where the game violates these rules today

Ordered by how much they break the game.

| # | Problem | Where | Measured | Rule violated |
|---|---|---|---|---|
| 1 | **Spread triples weapon output.** 2 extra projectiles per stack × `active_count` | `spread_modifier.gd:24-33` | **+200% WB**, price 3 | §2.1 cap +15% |
| 2 | **Chain triples weapon output.** Full-damage projectile per bounce, `max_bounces * active` | `chain_modifier.gd:39-43, 90` | **+300% WB** vs a pack of 4, price 3 | §2.1 cap +15% |
| 3 | **`StatMultiplierModifier` doubles every future item, per stack** | `stat_multiplier_modifier.gd:8,28` | **×4 at 2 stacks**, uncapped | §7.1 banned model |
| 4 | **One armor item is +10% EHP; an armor *stack* is +50% EHP** | `armor_modifier.gd:41-46`; armor rolls a constant `1.0` (`item_factory.gd:459`) | 4 copies → EHP **×5.06 (+406%)** | §1, §3.3 caps |
| 5 | **Poison is +300% WB on its own.** `duration 3.0`, full hit damage per stack, `attack_speed` cancels | `poison_modifier.gd:11-12, 39`; `poison_effect.gd:63` | `poison_dps = 3.0 × weapon_dps`, at any attack speed | §5.5 |
| 5a | **All poison sources on a target share one `PoisonEffect`**, found by name on the target's `Health`. A poisoned Knife and a poisoned Pistol add stack counts together but both tick at whichever weapon applied first | `poison_modifier.gd:34-44`, `poison_effect.gd:20` | correctness bug, not just balance | — |
| 5b | **`max_stacks 500` never binds** (9 stacks at 3 attacks/s) — dead config that reads like a safety limit | `poison_modifier.gd:12` | — | — |
| 5c | **`damage_per_tick` is set once and never refreshed**, so swapping weapons mid-fight does not raise an applied poison | `poison_effect.gd:20`, `poison_modifier.gd:39` | — | — |
| 6 | **`flat_damage` and `critical_chance` roll a constant**, because `base_value == 0` short-circuits the RNG | `item_factory.gd:458-459` | no variance; `flat_damage +1.0` = +10-20% WB | §3.3 |
| 7 | **Dead stats are in the generation pool** — nothing reads them | `stats.gd:22-23`; only `item_tooltip.gd:24-25` mentions them | **0% power**, full price | §3.3 |
| 8 | **Generation reads the wrong character.** `base_value` comes from the factory's own `Stats` child, not the holder | `item_factory.gd:192` | a `+1.0 health` item is +0.8% on a Soldier, +2.5% on a Multitasker | §3.2 |
| 9 | **`base_damage` stat is weapon-independent damage** | `spinning_orbs_modifier.gd:67`, `reflect_projectiles_modifier.gd:31` | +125% `WB_raw` on a Pistol, +18% on a rifle | §7.3 |
| 10 | **`ExplosiveShot` deals a flat 3.0**, not a fraction of hit damage | `explosive_shot_modifier.gd:10` | +60% on a 5-damage Pistol, +11% on a 28-damage rifle | §5.5 |
| 11 | **Pistol (4.0) and Shotgun (5.0) are strictly worse than Fist (10.0)** with no compensating upside | `Pistol.tres`, `Shotgun.tres` — 4 of 5 weapons never set `base_damage`, so all sit at the 5.0 default | -60% / -50% | §2.2 T1 floor |
| 12 | **`Crit` is dead at 1 stack** — `critical_chance` defaults to 0.0, so `randf() * 100 < 0` never fires | `crit_modifier.gd:27`, `stats.gd:26` | **0% WB** until a crit item is bought | §7.2 |
| 13 | **Weapons cost 5 and money starts at 0**, income is +1 per kill | `item_price_analyzer.gd:10`; `spawner_modifier.gd:22-24` | a weapon costs 5 kills, earned *after* the shop opened | §2.1 |
| 14 | **Character power spread is huge.** Wildling starts at 288 EHP against the 40 reference, while Brawler starts at +39% `WB_solo` | §6 table | Wildling **7.2×** the reference EHP, Brawler **1.39×** the reference `WB_solo` | §6 |
| 15 | **Three of five characters start with no weapon** | `Ranger.tres`, `Soldier.tres`, `Wildling.tres` | 0 `WB_solo` at run start | §6 |
| 16 | **`aim/highest_hp.tres` and `aim/lowest_hp.tres` are cross-wired** to the wrong scripts | `highest_hp.tres` runs `LowestHealthTargetSelector`; `lowest_hp.tres` runs `RandomTargetSelector` | Shotgun aims at the *lowest*-HP target | §5.8 checklist |
| 17 | **`Fist.tres` declares `range = 300.0`**, which no script exports | `Fist.tres` vs `BaseWeapon.gd:9` (`weapon_range`) | silently ignored; swings at 400.0 | §5.3 |
| 18 | **Shotgun pellets sum to 200%**, so it deals double its own `WB_raw` into one target | `shotgun_weapon.gd:16` | 5.0 actual vs 2.5 budgeted | §5.2 |
| 19 | **`~35%` of stat items triple in price** (1 → 3) purely from the curse roll, with identical positive power | `item_price_analyzer.gd:14-24`; `item_factory.gd:206-208` | the price-band-as-budget mapping (§2.1) breaks for 35% of offers | §2.1 |
| 20 | **`RegenModifier.tscn`** — the abstract, behaviourless base — is loaded as an offerable scene | `src/Systems/Items/modifiers/` | a price-3 item that does nothing | §2.1 |
| 21 | **`drop_pool` converges to ~100% reuse** and never resets | `item_factory.gd:117-130` | `(N+1)/(N+2)` pool hit rate | §4 |
| 22 | **No player-side scaling at all.** Enemy HP ×5, player power unconstrained | `enemy_spawner.gd:14` | nothing on the item side moves | §2.3 |
| 23 | **A price-1 `lifeleach` item doubles life leech** — `lifeleach` is not in `DEFAULT_STATS`, so it rolls the constant `1.0` on a stat whose base is 1.0 | `item_factory.gd:459`; `life_leach_modifier.gd:6,26` | 5% → 10% lifesteal | §3.3 |

---

**Fix order, if you want the shortest path to a playable game:** 1, 2, 4, 5 (the four items that break the ×15 rule outright), then 11 (give every weapon a real `base_damage`), then 7 and 20 (delete the dead stats and the dead scene). Everything else is polish.

Two smaller ones, not balance but worth a line each: `PercentRegenModifier.tscn:5` references `Systems/Items/Modifiers/` with a capital `M` against a lowercase folder (works on NTFS, breaks on export), and `test/Systems/test_enemy_health_gut.gd:11` asserts `"Enemy health should be 40"` against a `res://test/TestScene.tscn` that no longer exists.

---

## 9. Known gaps / TODOs

- **Nothing in this document is enforced by code.** Section 8 is a backlog, not a test suite. The cheapest first step is the §5.8 weapon-budget test, because `WB` is two multiplications and it will catch every `.tres` edit.
- **No rarity or tier field exists.** `ItemPriceAnalyzer`'s four price bands are the only stratification, and §2.1 proposes treating them as the budget tiers. A real `tier` field on `Item` / `BaseWeapon` would let the generator widen its ranges per tier — **[PROPOSED]**, not designed further here.
- **`money` is not a `DEFAULT_STATS` key**, so it is excluded from the candidate pool but also from every other stat assumption. It is set directly via `set_base_stat`.
- **Item stacking has no cap and no unique ID.** §3.3's per-stat caps assume something enforces them; today nothing does (`items.md`, "Known limitations").
- **Stale units in two docs**: `docs/systems/stats.md:22` and `docs/systems/characters.md:26` still say `movement_speed 0.25 m/s` and `200 px per metre`. The code says `1.0` and `300.0` (`stats.gd:9,24`). The §5.3 uptime numbers above use the code values.
- **`_generate_stat_modifiers`' `elif base_value == 1` branch** (`:460`) is dead code — identical to the `else`. Fold it in when §3.3 replaces the function.

## Assumptions

- `Stats.DEFAULT_STATS` (`stats.gd:15-30`) is the reference frame for every WB and EHP number here. If a base stat changes, the §2.3 targets and §5.6 TTK bands move with it.
- Enemy and boss scaling numbers come from the `@export` defaults on `enemy_spawner.gd` and `boss_spawner.gd` as currently set in the scene files. Those are exports, so a scene override changes the curve and invalidates §5.6.
- `current_loop` on the boss spawner scales from `1` while the enemy spawner scales from `0` (`boss_spawner.gd:58` vs `enemy_spawner.gd:184`). Boss HP is `10 + 500 × loop`, enemy HP is `10 + 20 × (loop − 1)`. That off-by-one is intentional-looking but is worth confirming before anyone tunes against §5.6.