# Options

## Purpose

The settings the player changes from the options panel: the window mode, the master/music/sfx volumes, and whether the character stats panel is shown.

**[CURRENT]** The values live in the `GameSettings` autoload and are mirrored to a `ConfigFile` under `user://` on every change, so they survive a scene change *and* a restart.

They used to live on `OptionsMenu` itself, which is instanced once per menu scene (`Main.tscn`, `PauseMenu.tscn`, and any future host). Every scene change re-ran `OptionsMenu._ready()`, which reset each control to its defaults — so the window size and the volumes snapped back on the way to the main menu and on the way into a run.

## Key scripts / scenes

| Path | Role |
|---|---|
| `src/Scripts/autoload/game_settings.gd` | The store. Owns the values, persists them, applies them to the window and the audio buses. |
| `src/Scenes/menu/OptionsMenu.tscn` | The panel. Six controls and no state. |
| `src/Scenes/menu/options_menu.gd` | Reads the store into the controls on `_ready`, writes back on every user interaction. |
| `src/default_bus_layout.tres` | Where the `Music` and `SFX` buses come from. |
| `test/Systems/menu/test_game_settings.gd` | Persistence across a rebuilt menu, the file round-trip, and the clamping. |
| `test/Systems/menu/test_options_menu_window_placement.gd` | The window-centering arithmetic, which `GameSettings` inherited from `OptionsMenu`. |

## Data flow

1. `GameSettings._ready()` reads the stored file over the defaults and applies the three volumes. It does **not** touch the window mode — an autoload would fight the window the engine has just set up.
2. `OptionsMenu._ready()` fills its controls from the store, *then* connects the signals. The order matters: assigning an `HSlider.value` emits `value_changed`, so wiring first would make opening the menu write the default straight back over the stored value.
3. A user interaction calls a `GameSettings` setter, which clamps, saves and applies. The store is the only thing that writes to `DisplayServer` or `AudioServer`.
4. `OptionsMenu._ready()` then re-asserts the window mode and the volumes. A scene change can rebuild the window between two visits to the menu, and this is where it gets put back.

Values are `0`–`100` percent in the store and converted to decibels on the way to the bus. A slider at `0` gives `linear_to_db(0)`, i.e. `-inf`, which is the correct reading of silence — do not special-case it to `0` dB.

## Dependencies

- `DisplayServer` for the window mode and `AudioServer` for the buses. Both are reached only from `GameSettings`.
- `ConfigFile`, section `options`, keys `window_mode_index`, `sound_volume`, `music_volume`, `sfx_volume`, `show_stats`.
- `WindowFocus` is a separate autoload and knows nothing about this one; raising the window and sizing it are different jobs.

## Known limitations / TODOs

- **The window mode is a list, not a free choice.** `GameSettings.WINDOW_MODES` is the ordered list the window button cycles: 1280x720, 1920x1080, fullscreen. It is an index into that array, which is why the value read off disk is clamped on load — a hand-edited index past the end would otherwise leave the menu one past the last mode.
- **Settings are not applied at startup before any menu opens.** Volumes are (in the autoload); the window mode waits for the first `OptionsMenu`. The visible effect is that the game opens at the project viewport size until the first menu is built.
- **`show_stats` is applied per host and silently does nothing without a stats panel.** `_apply_show_stats()` walks to `CanvasLayer/CharacterUi/PanelContainer` and returns if it is not there, which is every menu except the in-game pause one. The setting is stored regardless.
- **Setters, not property setters, on purpose.** A property setter would fire while `load_settings()` was still reading the file, so every line of a load would write the file back.
- **No tests write the player's real settings file.** `settings_path` is a public var for exactly that; the suites point it at a scratch file and remove it afterwards.
- **`PauseMenu` had its own dead copy of the window-mode list.** The unused `window_modes` / `current_index` vars were removed when the real list moved to `GameSettings`.
