# Stats

Purpose
- Central stat storage, modifier application and condition tracking for entities.

Key scripts / scenes
- `Systems/stats/stats.gd` (`Stats` class)

Data flow
- Inputs: base stat values (exported), `add_modifier` / `remove_modifier` calls from Items/Weapons, condition updates from managers.
- Processing: `get_stat()` computes final stat by applying all modifiers (flat then percent multipliers) and honoring conditional modifiers via `_check_condition()`.
- Outputs: emits `on_stat_changes` and `on_condition_change` events via `event_manager` when stats or conditions change.

Dependencies
- Expects `event_manager` reference (exported or found on parent). Condition managers are added via `add_condition_manager`.

Known limitations / TODOs
- Modifiers are simple dictionaries; no ids or references to track duplicates beyond exact Dictionary matches.
- Condition manager lifecycle (removal) is TODO.
