# Context / Glossary

Lazy glossary of terms used across the project docs and code. Add terms as they come up.

## Actors & characters

**Player**:
The runtime combat entity the human controls this run. In code today this is the
`Character` class (`Scripts/character.gd`) and `Systems/Character.tscn`.
_Avoid_: Character (when you mean the archetype), hero

**Character**:
The playable archetype chosen before a run (Rogue, Warrior, Tank), defined by
`CharacterData` resources.
_Avoid_: Player, class, hero

**Enemy**:
A hostile actor controlled by AI. A boss is an enemy variant.
_Avoid_: mob, monster

## Items & what they do

**Stat modifier**:
Data applied to an actor's stats: a Dictionary in `Stats.add_modifier` format, e.g.
`{"damage": {"flat": 5, "percent": 0.1}}`, optionally gated by a condition.
_Avoid_: effect, buff, debuff

**Effect**:
A Node behavior produced from an item's `effect_scene` that reacts to events (spread,
chain, crit, poison). Lives today in `Systems/Items/Modifiers/`.
_Avoid_: modifier (when you mean stat data), buff, debuff

**Buff**:
A stacked, timed stat modifier applied through a trigger event (e.g. `on_hit`).
_Avoid_: effect, pickup

**Debuff**:
A harmful buff, usually applied to the target of a hit.
_Avoid_: effect, status effect

**Condition**:
A context an actor is in (e.g. `standing_still`) that gates stat modifiers and effects.
_Avoid_: status effect

**Death reward**:
What a dying actor grants: money, item drops, altars, death marks. Implemented today by
the misnamed `spawner_modifier.gd`.
_Avoid_: spawner modifier

## Infrastructure

**event contract**: the checker seam (`src/Scripts/event_contract.gd`) that validates every
`EventManager` emit/subscribe against a central schema registry. Violations (unknown event,
non-Dictionary payload, missing required key, listener arity != 1) are rejected by the bus and
reported with `push_error` in debug builds. All event payloads are a single Dictionary.

**GDUnit4**: the canonical unit test framework for this project (see AGENTS.md); GUT is also
installed side-by-side.