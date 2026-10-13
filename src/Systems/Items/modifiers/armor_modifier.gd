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
    _publish_armor()

## Republish whenever the stack count moves, so the stat tracks pickups and sales.
## The same effect scene is deduplicated into one node per holder, so this one
## published value covers every copy of every armor item.
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

## Push the held-item armor into the `armor` stat. Armor used to be summed here in
## the damage handler instead, which kept it out of `Stats` - and since the stat
## panels list the stat, an armor item that was working showed no armor at all.
func _publish_armor() -> void:
    _publish_stat_value(provided_stat, _stack_bonus())

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