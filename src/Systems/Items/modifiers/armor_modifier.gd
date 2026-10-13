extends BaseModifier

@export var display_name: String = "Armor"
@export_multiline var tooltip_text: String = "Armor reduces incoming damage."
@export var trigger_event: String = "before_take_damage"
@export var armor_per_stack: float = 5.0

## This modifier's own armor contribution, published into the holder's `armor`
## stat as an ordinary modifier.
##
## Armor used to be `stat armor + per-stack bonus`, summed inside the damage
## handler below. That kept the bonus out of `Stats`, and since the stat panels
## list the stat, an armor item that was working showed no armor at all. The stat
## is now the single number: the formula reads it, the panels show it, and they
## cannot disagree.
var _published_armor: Dictionary = {}

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
    _publish_armor()

func detach() -> void:
    _unpublish_armor()
    super.detach()

## Publish the bonus again whenever the stack count moves, so the stat tracks
## pickups and sales. The same effect scene is deduplicated into one node per
## holder, so one `_published_armor` covers every copy of every armor item.
func _on_stacks_changed() -> void:
    _publish_armor()

## The armor held items are worth: `armor_per_stack` per stack above the first.
##
## The first stack is skipped only when this node is a character's declared
## baseline (see `BaseModifier.is_declared_baseline`): that stack stands for the
## armor the character declares beside the scene in its own `modifiers`, which is
## already in the stat. A modifier that exists purely because an armor item was
## picked up - a shop buy, a drop, the Configure panel - declares nothing, so its
## very first stack counts and one armor item is worth its full `armor_per_stack`.
func _stack_bonus() -> float:
    var held_stacks := stacks.count(true)
    if is_declared_baseline:
        held_stacks -= 1
    return armor_per_stack * max(0, held_stacks)

func _publish_armor() -> void:
    if not stats:
        return
    var bonus := _stack_bonus()
    if is_equal_approx(bonus, _published_bonus()):
        return
    _unpublish_armor()
    if bonus > 0.0:
        _published_armor = {"armor": {"flat": bonus}}
        stats.add_modifier(_published_armor)

## Called twice on the way out (BaseModifier.remove_stack already detaches when
## the last stack goes, then ItemHolder detaches again before freeing), so an
## empty `_published_armor` is what makes the second call a no-op.
func _unpublish_armor() -> void:
    if _published_armor.is_empty() or not is_instance_valid(stats):
        return
    stats.remove_modifier(_published_armor)
    _published_armor = {}

func _published_bonus() -> float:
    return float(_published_armor.get("armor", {}).get("flat", 0.0))

func _on_before_take_damage(event):
    var ctx: DamageContext = event["damage_context"]
    if not ctx or not stats:
        return

    # The holder's armor stat, which already includes this modifier's per-stack
    # bonus (published into it above). Several ArmorModifier instances can be live
    # at once - a character baseline attached by CharacterInitializer plus the one
    # effect node every held armor item stacks into - and applying each would stack
    # reductions, so only the strongest armor source wins: if a previous instance
    # already reduced this hit, undo its multiplier and re-apply with the higher
    # armor.
    var armor: float = get_provided_stat()
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