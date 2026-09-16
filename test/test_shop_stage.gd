extends Node2D
## Test-only "shop stage" root script.
## Opens the ShopMenu automatically on start so the shop can be
## tested without playing through enemy/boss stages first.

@export var starting_money: float = 10.0
@export var auto_open_shop: bool = true

@onready var character: Character = $Character
@onready var shop_menu: ShopMenu = $UI/ShopMenu
@onready var item_factory: ItemFactory = $ItemFactory


func _ready() -> void:
    if auto_open_shop:
        call_deferred("_open_shop")


func _open_shop() -> void:
    if not is_instance_valid(character):
        push_warning("ShopStage: Character missing, cannot open shop.")
        return
    if not is_instance_valid(shop_menu):
        push_warning("ShopStage: ShopMenu missing, cannot open shop.")
        return
    # Character._ready() already sets GlobalGameState.current_character,
    # but ensure it here in case ready order changes.
    GlobalGameState.current_character = character
    # Give test money so buy/reroll buttons are usable right away.
    if character.has_node("Stats"):
        character.get_node("Stats").set_base_stat("money", starting_money)
    # Ensure the shop can generate items (wired in .tscn, fallback here).
    if shop_menu.item_factory == null and is_instance_valid(item_factory):
        shop_menu.item_factory = item_factory
    shop_menu.character = character
    shop_menu.show_menu()
    # Simulate portal cleanup with no leftover pickups: this moves the
    # menu from phase 1 (collected pickups) to phase 2 (generated shop).
    shop_menu.load_items([])
