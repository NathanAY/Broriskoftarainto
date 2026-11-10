class_name GamepediaTest
extends GdUnitTestSuite

## The Gamepedia reads the shipped data, so these tests check that it finds it
## and that both menus can open and close it. No stat is pinned as a literal:
## expectations are derived from the same sources the Gamepedia reads.

const MAIN_MENU := "res://src/Scenes/menu/Main.tscn"
const PAUSE_MENU := "res://src/Scenes/menu/PauseMenu.tscn"
const GUNNER := "res://src/Systems/enemies/EnemyGunner.tscn"


func _names(entries: Array[Dictionary]) -> Array:
    return entries.map(func(entry): return entry["name"])


func test_weapons_list_every_weapon_resource_with_stats() -> void:
    var entries := GamepediaData.weapon_entries()
    assert_array(_names(entries)).contains(["Pistol", "Shotgun", "Fist"])
    for entry in entries:
        var labels: Array = entry["rows"].map(func(row): return row[0])
        assert_array(labels).contains(["Damage", "Attack Speed"])


func test_enemy_health_comes_from_the_scene() -> void:
    var scene := load(GUNNER) as PackedScene
    var enemy := auto_free(scene.instantiate()) as Enemy
    var expected := ItemTooltip.format_value(float(enemy.get_node("Stats").stats["health"]))
    var gunner: Dictionary = GamepediaData.enemy_entries().filter(func(e): return e["name"] == "Gunner")[0]
    assert_array(gunner["rows"]).contains([["Health", expected]])
    # The gunner shoots, so its weapon must be listed under it.
    assert_array(_names(gunner["weapons"])).contains(["Pistol"])


func test_enemy_roster_includes_the_basic_enemy_and_every_scene() -> void:
    var scene_count := DirAccess.get_files_at(GamepediaData.ENEMY_DIR).size()
    var tscn_count := 0
    for file_name in DirAccess.get_files_at(GamepediaData.ENEMY_DIR):
        # `SplitOnDeath.tscn` is a component, not an enemy: it is skipped on purpose.
        if file_name.ends_with(".tscn") and file_name.begins_with("Enemy"):
            tscn_count += 1
    assert_int(scene_count).is_greater(0)
    var entries := GamepediaData.enemy_entries()
    assert_int(entries.size()).is_equal(tscn_count)
    assert_array(_names(entries)).contains([GamepediaData.BASE_ENEMY_NAME])


func test_modifiers_list_every_modifier_scene() -> void:
    var scene_count := 0
    for file_name in DirAccess.get_files_at(GamepediaData.MODIFIER_DIR):
        if file_name.ends_with(".tscn"):
            scene_count += 1
    var entries := GamepediaData.modifier_entries()
    assert_int(entries.size()).is_equal(scene_count)
    for entry in entries:
        assert_str(entry["name"]).is_not_empty()


func test_characters_list_every_character_resource() -> void:
    var tres_count := 0
    for path in GamepediaData._tres_files_recursive(GamepediaData.CHARACTER_DIR):
        if load(path) is CharacterData:
            tres_count += 1
    var entries := GamepediaData.character_entries()
    assert_int(tres_count).is_greater(0)
    assert_int(entries.size()).is_equal(tres_count)
    for entry in entries:
        assert_object(entry["resource"]).is_instanceof(CharacterData)


func test_every_entry_in_every_tab_shows_an_image() -> void:
    var gamepedia := auto_free(Gamepedia.new()) as Gamepedia
    add_child(gamepedia)
    assert_array(_tab_names(gamepedia)).is_equal(["Characters", "Weapons", "Enemies", "Modifiers"])
    for tab in gamepedia.tabs.get_children():
        var cards := tab.find_children("*", "IconCard", true, false)
        assert_int(cards.size()).override_failure_message("tab %s has no entries" % tab.name).is_greater(0)
        for card in cards:
            var holder := (card as IconCard).icon_holder
            assert_int(holder.get_child_count()).override_failure_message(
                "%s in %s has no image" % [(card as IconCard).name_label.text, tab.name]).is_equal(1)


func _tab_names(gamepedia: Gamepedia) -> Array:
    return gamepedia.tabs.get_children().map(func(tab): return tab.name)


func test_main_menu_opens_and_closes_gamepedia() -> void:
    var menu := auto_free((load(MAIN_MENU) as PackedScene).instantiate()) as CanvasLayer
    add_child(menu)
    menu.get_node("Control/VBoxContainer/GamepediaButton").pressed.emit()
    var gamepedia := menu.get_children().filter(func(c): return c is Gamepedia)[0] as Gamepedia
    assert_bool(menu.get_node("Control").visible).is_false()
    assert_int(gamepedia.tabs.get_tab_count()).is_equal(4)
    gamepedia._on_back_pressed()
    assert_bool(menu.get_node("Control").visible).is_true()


func test_pause_menu_has_a_gamepedia_button_that_opens_it() -> void:
    var menu := auto_free((load(PAUSE_MENU) as PackedScene).instantiate()) as CanvasLayer
    add_child(menu)
    menu.get_node("Control/VBoxContainer/GamepediaButton").pressed.emit()
    assert_bool(menu.get_node("Control").visible).is_false()
    assert_array(menu.get_children().filter(func(c): return c is Gamepedia)).has_size(1)
