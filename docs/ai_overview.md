# Overview

## What this is
- Genre: Top-down arena roguelite (wave-based shooter with boss and shop loops).
- Core loop: Clear enemy waves → defeat boss → enter shop/upgrade phase → repeat with increased difficulty.
- Inspiration: Brotato-style item/weapon stacking and fast-paced wave combat.
- Engine: Godot 4.6. Stage: early prototype — the loop is playable, balance is not (see `docs/systems/balance_audit.md`).

## Key gameplay pillars
- Rapid arena combat with multiple orbiting/attached weapons.
- Item-driven character progression: persistent modifiers, temporary buffs, and effect scenes.
- Wave → boss → shop loop with scaling difficulty.
- Modular systems using resource-based weapons/items to enable fast iteration.

## Reading order

Start here, then follow one system at a time. Every path below is repo-root-relative and checked by `test/test_doc_links.gd`, so it resolves as written.

**Orientation**
| Doc | What it answers |
|---|---|
| `docs/architecture.md` | Which scene is which, which script owns what, how systems talk to each other |
| `CONTEXT.md` | What a word means. *Character* vs *Player*, *effect* vs *stat modifier*, *wave* vs *stage* |
| `docs/visual_style.md` | Icon naming, sizes, the Borderlands art direction, the two style blocks and two palettes (UI vs art), menu background layers, sprite sheets, the character rig |
| `docs/systems/balance.md` | How much power a new weapon, item, modifier or character may give — **read before designing one** |
| `docs/systems/balance_audit.md` | The 23 places the game currently breaks those balance rules |

**Systems** — `docs/systems/`
| Doc | What it covers |
|---|---|
| `characters.md` | `CharacterData` resources, character select UI, how a character is applied at spawn |
| `debug_scenarios.md` | The main menu's "Debug scenarios" button: four dev-only mid/endgame runs and how a scenario is configured |
| `enemies.md` | `Enemy` behaviour, health, boss variant |
| `event_manager.md` | The `LocalEventManager` event bus and the `event_contract.gd` schema checker |
| `items.md` | The `Item` resource, `ItemHolder`, `ItemBuilder`, pricing |
| `item_factory.md` | Procedural item generation, the gift/curse roll, `drop_pool` |
| `modifiers.md` | Effects (the Node behaviours items attach), the `BaseModifier` contract, the full catalog |
| `options.md` | The options panel: window mode, volumes, show-stats, and why the values live in an autoload rather than on the menu |
| `player.md` | The runtime player entity and its scene |
| `spawners.md` | `enemy_spawner.gd`, `boss_spawner.gd`, spawn pacing |
| `stage_manager.md` | Wave → boss → shop orchestration and loop progression |
| `stats.md` | Stat storage, modifiers, conditions, modifier-owned (provided) stats |
| `ui_shop_portal.md` | Shop, item cards, tooltips, the tone/colour system, the HUD's buff/debuff tiles |
| `weapons.md` | `BaseWeapon`, weapon scripts, built-in weapon effects, weapon resources |

**Decisions** — `docs/adr/`
| Doc | What it decided |
|---|---|
| `docs/adr/0001-character-means-archetype.md` | *Character* is the archetype, *Player* is the runtime entity; the code class `Character` is the Player and was deliberately left unrenamed |

**Archive** — `docs/archive/`
Implementation logs for shipped work. Kept for provenance, not current truth, and deliberately not link-checked. See `docs/archive/README.md`.

## Major systems and where they live

| System | Entry point |
|---|---|
| Event bus | `src/Scripts/LocalEventManager.gd` (`EventManager`) |
| Player | `src/Scripts/character.gd` (`Character`) — the runtime entity, see ADR-0001 |
| Character data & select | `src/Systems/characters/CharacterData.gd`, `src/Scenes/menu/CharacterSelect.tscn` |
| Enemies | `src/Scripts/Enemy.gd`, `src/Systems/Enemy.tscn` |
| Stats | `src/Systems/stats/stats.gd` (`Stats`) |
| Weapons | `src/Systems/weapon/*`, `WeaponHolder` |
| Items | `src/Systems/Items/*` (`Item`, `ItemHolder`, `item_holder.gd`) |
| Effects (legacy folder `modifiers/`) | `src/Systems/Items/modifiers/*` — Node behaviours items attach to an actor |
| Spawners | `src/Systems/enemy_spawner.gd`, `src/Systems/boss_spawner.gd` |
| Stage flow | `src/Scripts/stage_manager.gd` |
| UI & shop | `src/Scenes/menu/`, `src/ui/`, `src/Systems/ShopPortal.tscn` |
| Autoloads | `src/Scripts/autoload/` — `GlobalGameState`, `SoundManager`, `MusicManager`, `GameSettings` |

## Vocabulary that trips people up

The one thing worth reading before the code: this project uses **effect** and **modifier** in the opposite way to what the names suggest.

- An **effect** is a `Node` behaviour — a scene from `src/Systems/Items/modifiers/` that an item attaches to an actor. It subscribes to `EventManager` events and reacts (spawn a projectile, heal, apply poison).
- A **stat modifier** is a plain `Dictionary` in `Stats.add_modifier` format. No behaviour.

`CONTEXT.md` is the glossary; `docs/systems/modifiers.md` is the full contract.

## Working on this project
Rules for agents and contributors live in `AGENTS.md`: test-first, how to run the suites, how to render a scene to a PNG for a visual check, and which doc to read before which kind of change.

## Conventions used across these docs
- **[CURRENT]** — a statement about the code as it is written today. **[PROPOSED]** — the intended target state, not implemented. The distinction matters most in `docs/systems/balance.md`, where the two are different documents' worth of information, but any doc that describes an aspiration rather than an observation should tag it.
- Each `docs/systems/*.md` follows the same shape: **Purpose**, **Key scripts / scenes**, **Data flow**, **Dependencies**, **Known limitations / TODOs**. The last section is not padding — it is where the traps are, so read it before you trust the rest.
- Paths are **repo-root-relative** and carry the `src/` prefix. See below.

The docs are checked, not trusted: `test/test_doc_links.gd` asserts every project path any doc backticks resolves, every bare filename still exists somewhere, and this index lists every doc that exists. A path here is **repo-root-relative**, so it carries the `src/` prefix — the file at Systems/stats/stats.gd is cited as `src/Systems/stats/stats.gd`.
