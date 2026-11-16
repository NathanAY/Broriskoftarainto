class_name GameConfig
## Reads `res://game_config.json`, the one file for hand-tuned game numbers.
## Parsed once per run; what each key means is in `docs/systems/game_config.md`.

const PATH: String = "res://game_config.json"

static var _data: Dictionary = {}
static var _loaded: bool = false


## One top-level block of the file, e.g. `section("item_generation")`. Empty when
## the file or the block is missing, so callers keep their own defaults.
static func section(section_name: String) -> Dictionary:
    if not _loaded:
        _loaded = true
        var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
        if parsed is Dictionary:
            _data = parsed
        else:
            push_warning("GameConfig: %s is missing or is not valid JSON, using defaults" % PATH)
    var block = _data.get(section_name, {})
    if block is Dictionary:
        return block
    return {}
