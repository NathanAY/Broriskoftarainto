# Characters — Data & Integration

This document explains the new character system (data, UI, and integration points) and how to add new characters.

## Overview
- Characters are data-driven Resources (`CharacterData`) stored as `.tres` files in `Resources/characters/`.
- Selection UI: `Scenes/menu/CharacterSelect.tscn` lets the player pick a character at the start of a run.
- The chosen character is stored in the autoload `GlobalGameState.starting_character` and applied when the player `Character` instance is created.

## Files of interest
- `Systems/characters/CharacterData.gd` — Resource class for characters.
- `Resources/characters/*.tres` — character definitions (examples: `Warrior.tres`, `Rogue.tres`, `Tank.tres`).
- `Scenes/menu/CharacterSelect.tscn` + `Scenes/menu/character_select.gd` — character selection UI.
- `Scripts/autoload/global_game_state.gd` — holds `starting_character` (path or Resource).
- `Systems/characters/CharacterInitializer.gd` — applies character data to the `Stats` node on character spawn.
- `Systems/Character.tscn` — now contains a `CharacterInitializer` Node (instance) so application is automatic.

## CharacterData format
- `display_name` (String): shown in UI.
- `description` (String): short description.
- `base_stats` (Dictionary): explicit base stat values to set when the character is chosen. These call `Stats.set_base_stat(stat_name, value)` for each key. Examples: `"health"`, `"movement_speed"`, `"damage"`, `"armor"`.
- `modifiers` (Array): list of modifier dictionaries matching the `Stats.add_modifier` format. Example modifier: `{ "damage": {"percent": -0.25}, "condition": {...} }` or `{ "attack_speed": {"percent": 0.2} }`.

Example (pseudo):
```
display_name = "Rogue"
base_stats = {"health": 35.0, "movement_speed": 70.0, "damage": 0.8}
modifiers = [{"attack_speed": {"percent": 0.2}}]
```

## How selection and application works
1. Player chooses a character in `CharacterSelect`; on confirm the script sets `GlobalGameState.starting_character = "res://Resources/characters/Rogue.tres"` (string path).
2. The flow continues to `StarterMenu` to choose weapons/items; those values are also saved in `GlobalGameState`.
3. When the game scene creates the player `Character` (instancing `Systems/Character.tscn`), the `CharacterInitializer` node reads `GlobalGameState.starting_character`, loads the resource, and:
   - Calls `Stats.set_base_stat` for each entry in `base_stats` (overwrites base values).
   - Calls `Stats.add_modifier` for each modifier in `modifiers` (adds modifier dicts to the stack).

This keeps character data separate from player logic and allows easy addition of new characters.

## Adding a new character
1. Create a new resource file in `Resources/characters/` using the `CharacterData` script as the resource type (or copy an existing `.tres`).
2. Set `display_name`, `description`, `base_stats`, and `modifiers` as needed.
3. No code changes needed — `CharacterSelect` scans the folder and will display the new entry.

## Extensibility ideas
- Add an exported `Texture2D icon` to `CharacterData` for richer UI (thumbnails in selection). Update `Scenes/menu/CharacterSelect.tscn` accordingly.
- Add per-character starting items/weapons by including `starting_items`/`starting_weapons` fields on the resource and updating `CharacterInitializer` or a small linker to apply them to `GlobalGameState` when confirming.

If you'd like, I can add icons for the three existing characters and show them in the UI next.
