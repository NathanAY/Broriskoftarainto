# GdUnit4 tests for the event contract seam (src/Scripts/event_contract.gd + LocalEventManager.gd)
class_name EventContractTest
extends GdUnitTestSuite

var em: EventManager
var _received: Dictionary = {}
var _called: bool = false

func before_test() -> void:
    em = EventManager.new()
    add_child(em)
    _received = {}
    _called = false

func after_test() -> void:
    if is_instance_valid(em):
        em.queue_free()
    collect_orphan_node_details()

func test_valid_emit_passes_check() -> void:
    var res := em.emit_event("on_heal", {"self": self, "amount": 5.0, "current_health": 10.0, "max_health": 50.0})
    assert_that(res.ok).is_true()
    assert_that(res.reason).is_equal(EventContracts.Reason.OK)

func test_unknown_event_rejected_on_emit() -> void:
    var res := em.emit_event("no_such_event", {})
    assert_that(res.ok).is_false()
    assert_that(res.reason).is_equal(EventContracts.Reason.UNKNOWN_EVENT)

func test_unknown_event_rejected_on_subscribe() -> void:
    var res := em.subscribe("no_such_event", Callable(self, "_one_arg_handler"))
    assert_that(res.ok).is_false()
    assert_that(res.reason).is_equal(EventContracts.Reason.UNKNOWN_EVENT)

func test_non_dictionary_payload_rejected() -> void:
    var res := em.emit_event("on_heal", ["self", 5.0])
    assert_that(res.ok).is_false()
    assert_that(res.reason).is_equal(EventContracts.Reason.NOT_A_PAYLOAD)

func test_missing_required_key_rejected() -> void:
    var res := em.emit_event("on_stat_changes", {"stat_name": "damage"})
    assert_that(res.ok).is_false()
    assert_that(res.reason).is_equal(EventContracts.Reason.MISSING_REQUIRED)

func test_emit_with_missing_required_key_is_dropped() -> void:
    em.subscribe("on_stat_changes", func(_ev): _called = true)
    var res := em.emit_event("on_stat_changes", {"stat_name": "damage"})
    assert_that(res.ok).is_false()
    assert_that(_called).is_false()

func test_subscribe_arity_two_rejected() -> void:
    var res := em.subscribe("on_stat_changes", Callable(self, "_two_arg_handler"))
    assert_that(res.ok).is_false()
    assert_that(res.reason).is_equal(EventContracts.Reason.BAD_ARITY)

func test_subscribe_null_listener_rejected() -> void:
    var res := em.subscribe("on_stat_changes", Callable())
    assert_that(res.ok).is_false()
    assert_that(res.reason).is_equal(EventContracts.Reason.NULL_LISTENER)

func test_valid_subscribe_and_dispatch() -> void:
    var sub_res := em.subscribe("on_heal", func(ev): _received = ev)
    assert_that(sub_res.ok).is_true()

    var payload := {"self": self, "amount": 3.0, "current_health": 8.0, "max_health": 50.0}
    var emit_res := em.emit_event("on_heal", payload)
    assert_that(emit_res.ok).is_true()
    assert_that(_received).is_equal(payload)
    assert_that(_received.size()).is_equal(4)

func test_extras_in_payload_are_tolerated() -> void:
    em.subscribe("on_hit", func(ev): _received = ev)
    var res := em.emit_event("on_hit", {"damage_context": {}, "body": self, "weapon": self, "extra_future_key": 42})
    assert_that(res.ok).is_true()
    assert_that(_received.has("extra_future_key")).is_true()

func test_unsubscribe_stops_dispatch() -> void:
    var listener := func(_ev): _called = true
    em.subscribe("on_heal", listener)
    em.emit_event("on_heal", {"self": self, "amount": 1.0, "current_health": 1.0, "max_health": 1.0})
    assert_that(_called).is_true()

    _called = false
    em.unsubscribe("on_heal", listener)
    em.emit_event("on_heal", {"self": self, "amount": 1.0, "current_health": 1.0, "max_health": 1.0})
    assert_that(_called).is_false()

func test_damage_events_require_damage_context() -> void:
    for ev_name in ["before_deal_damage", "before_take_damage", "after_take_damage", "after_deal_damage", "on_hit", "on_kill", "on_crit"]:
        var res := em.emit_event(ev_name, {})
        assert_that(res.ok).is_false()
        assert_that(res.reason).is_equal(EventContracts.Reason.MISSING_REQUIRED)

func test_on_condition_change_requires_condition_name() -> void:
    var res := em.emit_event("on_condition_change", {"value": 1.0})
    assert_that(res.ok).is_false()
    assert_that(res.reason).is_equal(EventContracts.Reason.MISSING_REQUIRED)

func _one_arg_handler(_event: Dictionary) -> void:
    pass

func _two_arg_handler(_a, _b) -> void:
    pass
