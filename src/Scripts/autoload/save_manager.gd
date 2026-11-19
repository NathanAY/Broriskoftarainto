extends Node

## The one save file. Everything that has to outlive a run (options now;
## progression, achievements and statistics later) is a named *section* of it.
##
## The file is JSON, kept inside the project - see `default_save_path()` - and
## looks like:
##
##     { "version": 1, "options": { ... }, "progress": { ... } }
##
## Each system owns one section and reads/writes it through `get_section()` /
## `set_section()`, so adding a feature never touches another feature's keys.
## JSON has no integer type: an `int` comes back from disk as a `float`, so the
## reader casts (`int(...)`) rather than trusting the type.

const SAVE_VERSION := 1
const VERSION_KEY := "version"

## Overridable so a test can point the store at a scratch file instead of the
## real save. See `test/Systems/test_save_manager.gd`.
var save_path: String = default_save_path()

## Section name -> Dictionary. Never contains `VERSION_KEY`; that is added on
## save and stripped on load.
var data: Dictionary = {}


func _ready() -> void:
    load_from_disk()


## `<project>/saves/save.json` when run from the editor or `godot --path .`,
## `<folder of the exe>/saves/save.json` in an export. `res://` is read-only
## once exported, and `user://` is outside the project (AppData), so neither
## can hold it.
static func default_save_path() -> String:
    var base_dir := (
        ProjectSettings.globalize_path("res://")
        if OS.has_feature("editor")
        else OS.get_executable_path().get_base_dir()
    )
    return base_dir.path_join("saves").path_join("save.json")


## A copy, so a caller cannot change the store without `set_section()`.
func get_section(section: String) -> Dictionary:
    var stored: Variant = data.get(section, {})
    return (stored as Dictionary).duplicate(true) if stored is Dictionary else {}


## Replaces one section and writes the file.
func set_section(section: String, values: Dictionary) -> void:
    data[section] = values.duplicate(true)
    save()


## Writes to a temp file and renames it over the save, so a crash or a full
## disk mid-write leaves the previous save intact instead of a truncated one.
func save() -> void:
    var error := DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
    if error != OK:
        push_warning("SaveManager: could not create %s (error %d)" % [save_path.get_base_dir(), error])
        return
    var contents := data.duplicate(true)
    contents[VERSION_KEY] = SAVE_VERSION
    var temp_path := save_path + ".tmp"
    var file := FileAccess.open(temp_path, FileAccess.WRITE)
    if file == null:
        push_warning("SaveManager: could not write %s (error %d)" % [temp_path, FileAccess.get_open_error()])
        return
    file.store_string(JSON.stringify(contents, "\t"))
    file.close()
    error = DirAccess.rename_absolute(temp_path, save_path)
    if error != OK:
        push_warning("SaveManager: could not replace %s (error %d)" % [save_path, error])


## Replaces `data` with the file's contents. A missing file is the first-run
## case and silent. An unreadable one is moved aside to `<file>.bak` and the
## game starts empty, so the next save cannot silently destroy a file that a
## human may still be able to repair.
func load_from_disk() -> void:
    data = {}
    if not FileAccess.file_exists(save_path):
        return
    # JSON.new().parse() rather than JSON.parse_string(): the latter prints an
    # engine error for bad input, and a damaged save is handled here, not a bug.
    var json := JSON.new()
    if json.parse(FileAccess.get_file_as_string(save_path)) != OK or not json.data is Dictionary:
        push_warning("SaveManager: %s is not a valid save, keeping it as .bak" % save_path)
        DirAccess.rename_absolute(save_path, save_path + ".bak")
        return
    var contents: Dictionary = json.data
    contents.erase(VERSION_KEY)
    data = contents
