extends BaseModifier
## A lethal hit instead leaves the holder at `survive_health` and costs a
## premium of `premium_base + premium_per_stage × (stage - 1)` coins. One claim per
## stack per stage (reset when the shop opens); no claim when the premium cannot
## be paid. Numbers come from the `economy_modifiers` config.

## After the energy shield has soaked its share, so the shield is spent first.
const PHASE := Damage.PHASE_ABSORB + 1

@export var display_name: String = "Insurance Policy"
@export var trigger_event: String = "before_take_damage"

var _claims_used: int = 0


func get_tooltip_stats() -> String:
    var config := _economy_config()
    return "Survive a lethal hit for %d coins (+%d per stage), once per stage" % [
        int(config.get("premium_base", 0)), int(config.get("premium_per_stage", 0))]


func attachEventManager(em: Node):
    _cache_holder(em)
    _subscribe("before_take_damage", _on_before_take_damage, PHASE)
    _subscribe("on_shop_enter", func(_event: Dictionary) -> void: _claims_used = 0)


func premium() -> float:
    var config := _economy_config()
    return float(config.get("premium_base", 0)) + float(config.get("premium_per_stage", 0)) * (StageManager.stage_of(self) - 1)


func _on_before_take_damage(event: Dictionary) -> void:
    var ctx := event.get("damage_context") as DamageContext
    var health := get_health()
    var character := holder as Character
    if ctx == null or health == null or character == null:
        return
    if ctx.final_amount < health.current_health or _claims_used >= _active_stacks():
        return
    if not Wallet.spend(character, premium(), "insurance"):
        return
    _claims_used += 1
    RunHistory.record(character, display_name, "coins", -premium())
    ctx.final_amount = maxf(0.0, health.current_health - float(_economy_config().get("survive_health", 1)))
