# EventContracts.gd
# Central registry of every event the EventManager bus can carry.
# A single Dictionary is the only allowed payload shape. Listening is arity-exactly-1.
extends RefCounted
class_name EventContracts

enum Reason {
	OK,
	UNKNOWN_EVENT,
	NOT_A_PAYLOAD,
	MISSING_REQUIRED,
	BAD_ARITY,
	NULL_LISTENER,
}

const REASON_NAMES := {
	Reason.OK: "OK",
	Reason.UNKNOWN_EVENT: "UNKNOWN_EVENT",
	Reason.NOT_A_PAYLOAD: "NOT_A_PAYLOAD",
	Reason.MISSING_REQUIRED: "MISSING_REQUIRED",
	Reason.BAD_ARITY: "BAD_ARITY",
	Reason.NULL_LISTENER: "NULL_LISTENER",
}

class CheckResult:
	var ok: bool = true
	var event_name: String = ""
	var reason: int = Reason.OK
	var detail: String = ""

	func _init(p_event_name: String = "") -> void:
		event_name = p_event_name

# Schema per event: "required" keys must be present, everything else is tolerated.
const SCHEMAS := {
	# --- damage pipeline (emitted on source bus, or target bus where noted) ---
	"before_deal_damage": {
		"required": ["damage_context"],
	},
	"before_take_damage": {
		"required": ["damage_context"],
	},
	"after_take_damage": {
		"required": ["damage_context"],
	},
	"after_deal_damage": {
		"required": ["damage_context"],
	},
	"on_hit": {
		"required": ["damage_context"],
	},
	"on_kill": {
		"required": ["damage_context"],
	},
	# --- combat / attack ---
	"on_attack": {
		"required": ["weapon"],
	},
	# --- stats / conditions ---
	"on_stat_changes": {
		"required": ["stat_name", "final_value"],
	},
	"on_condition_change": {
		"required": ["condition_name", "value"],
	},
	# --- equipment / inventory ---
	"on_weapon_changes": {
		"required": ["weapon_inst"],
	},
	"on_item_added": {
		"required": ["hold_owner", "item", "items"],
	},
	"on_item_removed": {
		"required": ["hold_owner", "item", "items"],
	},
	# --- health ---
	"on_heal": {
		"required": ["self", "amount", "current_health", "max_health"],
	},
	"on_health_changed": {
		"required": ["self", "amount", "current_health", "max_health"],
	},
	"on_death": {
		"required": ["self", "damage_context"],
	},
	# --- buffs / debuffs ---
	"on_buff_added": {
		"required": ["buff", "holder", "id"],
	},
	"on_buff_removed": {
		"required": ["buff", "holder", "id"],
	},
	"on_debuff_added": {
		"required": ["debuff", "holder", "target"],
	},
	"on_debuff_removed": {
		"required": ["debuff", "holder", "target"],
	},
	# --- misc ---
	"on_crit": {
		"required": ["damage_context"],
	},
	"on_shield_changed": {
		"required": ["self", "amount", "current_shield", "max_shield"],
	},
}

static func check_emit(event_name: String, payload: Variant) -> CheckResult:
	var result := CheckResult.new(event_name)
	if not SCHEMAS.has(event_name):
		return _fail(result, Reason.UNKNOWN_EVENT, "No schema registered for event '%s'" % event_name)
	if typeof(payload) != TYPE_DICTIONARY:
		return _fail(result, Reason.NOT_A_PAYLOAD,
			"Event '%s' expects a single Dictionary payload, not %s" % [event_name, type_string(typeof(payload))])
	var schema: Dictionary = SCHEMAS[event_name]
	var required: Array = schema.get("required", [])
	for key in required:
		if not payload.has(key):
			return _fail(result, Reason.MISSING_REQUIRED,
				"Event '%s' is missing required key '%s'" % [event_name, key])
	return result

static func check_subscribe(event_name: String, listener: Callable) -> CheckResult:
	var result := CheckResult.new(event_name)
	if not SCHEMAS.has(event_name):
		return _fail(result, Reason.UNKNOWN_EVENT, "No schema registered for event '%s'" % event_name)
	if listener.is_null():
		return _fail(result, Reason.NULL_LISTENER, "Listener for event '%s' is null" % event_name)
	if listener.get_argument_count() != 1:
		return _fail(result, Reason.BAD_ARITY,
			"Listener for event '%s' must take exactly one argument (the payload dict), got %d"
			% [event_name, listener.get_argument_count()])
	return result

static func report(result: CheckResult) -> void:
	if OS.is_debug_build():
		push_error("[EventContracts] %s" % _describe(result))

static func _describe(result: CheckResult) -> String:
	var reason_name: String = REASON_NAMES.get(result.reason, "?")
	return "%s (%s)" % [result.detail, reason_name]

static func _fail(result: CheckResult, p_reason: int, p_detail: String) -> CheckResult:
	result.ok = false
	result.reason = p_reason
	result.detail = p_detail
	return result