extends BaseModifier

@export var display_name: String = "Armor"
@export_multiline var tooltip_text: String = "Armor reduces incoming damage."
@export var trigger_event: String = "before_take_damage"
@export var armor_per_stack: float = 5.0

func get_tooltip_stats() -> String:
    return "+%d armor per stack" % int(armor_per_stack)

func _init():
    provided_stat = "armor"
    provided_stat_default = 0.0
    provided_stat_owned = false

func attachEventManager(em: Node):
    _cache_holder(em)
    if not stats:
        return
    _subscribe(trigger_event, Callable(self, "_on_before_take_damage"))
    _subscribe("on_stat_changes", Callable(self, "_on_stat_changes"))

func _on_before_take_damage(event):
    var ctx: DamageContext = event["damage_context"]
    if not ctx or not stats:
        return

    # Several ArmorModifier instances can be live at once: a character baseline
    # (attached by CharacterInitializer when base armor > 0) plus one effect
    # node per held armor item type. Applying each would stack reductions, so
    # only the strongest armor source wins: if a previous instance already
    # reduced this hit, undo its multiplier and re-apply with the higher armor
    # (preserves the item's per-stack bonus over the 0-stack baseline).
    var armor: float = get_provided_stat() + armor_per_stack * (_active_stacks() - 1)
    if ctx.armor_applied != 0:
        if int(armor) <= ctx.armor_applied:
            return
        ctx.final_amount /= ctx.armor_damage_multiplier
    var multiplier: float = 1.0

    if armor >= 0:
        multiplier = 10.0 / (10.0 + armor)
    else:
        multiplier = 1.0 + (-armor / 10.0)  # handles negatives correctly

    ctx.final_amount *= multiplier
    ctx.armor_applied = int(armor)   # optional, for debugging/logging
    ctx.armor_damage_multiplier = multiplier

func _on_stat_changes(_data):
    # ensure we keep stats up to date
    if holder:
        stats = holder.get_node_or_null("Stats")