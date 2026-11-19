# Save system

## Purpose

One JSON save file for everything that must outlive a run. **[CURRENT]** only the options are stored (`options` section). Progression, achievements and statistics are meant to become further sections of the same file.

## Key scripts / scenes

| Path | Role |
|---|---|
| `src/Scripts/autoload/save_manager.gd` | The `SaveManager` autoload. Loads the file at startup, hands out and replaces sections, writes atomically. |
| `src/Scripts/autoload/game_settings.gd` | First client: owns the `options` section. |
| `saves/` | Where the file lives. Git-ignored; `saves/.gdignore` keeps the editor from importing it. |
| `test/Systems/test_save_manager.gd` | Round-trip, section isolation, atomic write, corrupt-file handling. |

## File format

`<project>/saves/save.json`, pretty-printed (tab-indented) so a human can read and diff it:

```json
{
	"version": 1,
	"options": { "window_mode_index": 0, "music_volume": 100.0 }
}
```

- **Why JSON:** human-readable, nested data and arrays (a stats history or achievement list fits), and tooling everywhere. `ConfigFile` (the old format) is flat `section/key` and awkward for lists of records. Binary `var_to_bytes` is unreadable and breaks silently when a class changes. SQLite is overkill at this size.
- **Costs of JSON:** no `int` (a `3` comes back as `3.0` — cast with `int()` when reading), no `Vector2`/`Color`/resources (store plain numbers or arrays and rebuild), and it is trivially hand-editable, so every reader must clamp and default (see `GameSettings.load_settings()`). It is not tamper-proof; that only matters if achievements ever become competitive.
- **Location:** `<project>/saves/` when run from the editor or `godot --path .`, `<folder of the exe>/saves/` in an export. `res://` is read-only once exported and `user://` is outside the project, so `SaveManager.default_save_path()` picks between the two by `OS.has_feature("editor")`.

## Data flow

1. `SaveManager._ready()` loads the file into `data` (section name → Dictionary). It is listed before `GameSettings` in `project.godot`, so the store exists when `GameSettings._ready()` reads it.
2. A system reads its section with `get_section(name)` (a copy; empty if absent) and writes it with `set_section(name, dict)`, which saves immediately.
3. `save()` writes `<save>.tmp` and renames it over the save, so a crash mid-write leaves the previous file intact.
4. An unparsable file is renamed to `<save>.bak` and the game starts empty, so the next save cannot destroy something a human could still repair.

### Adding a section

Pick a section name, read it with `SaveManager.get_section("progress")`, write it with `SaveManager.set_section("progress", {...})`. Do not touch another system's section.

## Dependencies

`FileAccess`, `DirAccess`, `JSON`. Tests redirect `SaveManager.save_path` to `res://saves/test_*.json` and call `load_from_disk()` afterwards to restore the real data.

## Known limitations / TODOs

- **`version` is written but not yet used.** When the layout of a section changes incompatibly, bump `SAVE_VERSION` and migrate in `load_from_disk()`.
- **The old `user://` options file is not migrated.** Options saved there before this system existed are ignored once; the defaults apply.
- **Every setter saves the whole file**, including a slider drag. Fine at this size; batch writes if sections grow large.
- **A Windows install under `Program Files` is not writable**, so an export must live in a user-writable folder.
