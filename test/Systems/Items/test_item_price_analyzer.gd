# GdUnit TestSuite for ItemPriceAnalyzer shop/sell pricing.
class_name ItemPriceAnalyzerTest
extends GdUnitTestSuite

const STAT_ITEM := "res://src/Resources/items/PlusDamageItem.tres"
const MODIFIER_ITEM := "res://src/Resources/items/Knockback.tres"
const WEAPON := "res://src/Resources/weapons/Pistol.tres"
const BUFF_SCENE := "res://src/Systems/Items/Buffs/buff.tscn"
const DEBUFF_SCENE := "res://src/Systems/Items/Buffs/DebuffSource.tscn"

var _analyzer: ItemPriceAnalyzer = null


## Type prices live in the `economy` block of game_config.json; the suite reads
## them rather than pinning them, so a price rebalance keeps it green.
func _type_price(type: String) -> int:
    return int(GameConfig.section("economy").get("type_prices", {}).get(type, 0))


func _half(price: int) -> int:
    return maxi(1, roundi(price * float(GameConfig.section("economy").get("sell_ratio", 0.5))))


func before_test() -> void:
    _analyzer = ItemPriceAnalyzer.new()


func after_test() -> void:
    _analyzer.free()


func test_shop_price_stat_item_is_the_stat_price() -> void:
    var item: Item = load(STAT_ITEM)
    assert_int(_analyzer.get_price(item)).is_equal(_type_price("stat"))


func test_shop_price_modifier_is_the_effect_price() -> void:
    var item: Item = load(MODIFIER_ITEM)
    assert_int(_analyzer.get_price(item)).is_equal(_type_price("effect"))


func test_shop_price_buff_or_debuff_is_the_buff_price() -> void:
    var buff: Item = ItemBuilder.make_buff_item("Buff", "Grants buff", "attack_speed", {"flat": 0.5}, load(BUFF_SCENE))
    var debuff: Item = ItemBuilder.make_debuff_item("Debuff", "Grants debuff", "armor", {"flat": -10}, load(DEBUFF_SCENE))
    assert_int(_analyzer.get_price(buff)).is_equal(_type_price("buff"))
    assert_int(_analyzer.get_price(debuff)).is_equal(_type_price("buff"))


func test_shop_price_weapon_is_the_weapon_price() -> void:
    var weapon: BaseWeapon = load(WEAPON)
    assert_int(_analyzer.get_price(weapon)).is_equal(_type_price("weapon"))


func test_sell_price_is_the_sell_ratio_of_shop_price() -> void:
    assert_int(_analyzer.get_sell_price(load(STAT_ITEM))).is_equal(_half(_type_price("stat")))
    assert_int(_analyzer.get_sell_price(load(MODIFIER_ITEM))).is_equal(_half(_type_price("effect")))
    assert_int(_analyzer.get_sell_price(load(WEAPON))).is_equal(_half(_type_price("weapon")))

    var buff: Item = ItemBuilder.make_buff_item("Buff", "Grants buff", "attack_speed", {"flat": 0.5}, load(BUFF_SCENE))
    assert_int(_analyzer.get_sell_price(buff)).is_equal(_half(_type_price("buff")))


func test_sell_price_supports_custom_ratio() -> void:
    var item: Item = load(STAT_ITEM)
    assert_int(_analyzer.get_sell_price(item, 1.0)).is_equal(_type_price("stat"))
    var modifier: Item = load(MODIFIER_ITEM)
    assert_int(_analyzer.get_sell_price(modifier, 1.0)).is_equal(_type_price("effect"))