# GdUnit TestSuite for ItemPriceAnalyzer shop/sell pricing.
class_name ItemPriceAnalyzerTest
extends GdUnitTestSuite

const STAT_ITEM := "res://src/Resources/items/PlusDamageItem.tres"
const MODIFIER_ITEM := "res://src/Resources/items/CritGlass.tres"
const WEAPON := "res://src/Resources/weapons/Pistol.tres"
const BUFF_SCENE := "res://src/Systems/Items/Buffs/buff.tscn"
const DEBUFF_SCENE := "res://src/Systems/Items/Buffs/DebuffSource.tscn"

var _analyzer: ItemPriceAnalyzer = null


func before_test() -> void:
    _analyzer = ItemPriceAnalyzer.new()


func after_test() -> void:
    _analyzer.free()


func test_shop_price_stat_item_is_1() -> void:
    var item: Item = load(STAT_ITEM)
    assert_int(_analyzer.get_price(item)).is_equal(1)


func test_shop_price_modifier_is_3() -> void:
    var item: Item = load(MODIFIER_ITEM)
    assert_int(_analyzer.get_price(item)).is_equal(3)


func test_shop_price_buff_or_debuff_is_2() -> void:
    var buff: Item = ItemBuilder.make_buff_item("Buff", "Grants buff", "attack_speed", {"flat": 0.5}, load(BUFF_SCENE))
    var debuff: Item = ItemBuilder.make_debuff_item("Debuff", "Grants debuff", "armor", {"flat": -10}, load(DEBUFF_SCENE))
    assert_int(_analyzer.get_price(buff)).is_equal(2)
    assert_int(_analyzer.get_price(debuff)).is_equal(2)


func test_shop_price_weapon_is_5() -> void:
    var weapon: BaseWeapon = load(WEAPON)
    assert_int(_analyzer.get_price(weapon)).is_equal(5)


func test_sell_price_is_half_shop_price() -> void:
    assert_int(_analyzer.get_sell_price(load(STAT_ITEM))).is_equal(1)
    assert_int(_analyzer.get_sell_price(load(MODIFIER_ITEM))).is_equal(2)
    assert_int(_analyzer.get_sell_price(load(WEAPON))).is_equal(3)

    var buff: Item = ItemBuilder.make_buff_item("Buff", "Grants buff", "attack_speed", {"flat": 0.5}, load(BUFF_SCENE))
    assert_int(_analyzer.get_sell_price(buff)).is_equal(1)


func test_sell_price_supports_custom_ratio() -> void:
    var item: Item = load(STAT_ITEM)
    assert_int(_analyzer.get_sell_price(item, 1.0)).is_equal(1)
    var modifier: Item = load(MODIFIER_ITEM)
    assert_int(_analyzer.get_sell_price(modifier, 1.0)).is_equal(3)