class_name RootCompletionReceipt
extends RefCounted
## Immutable-in-practice authoritative fact for one exact-once root completion.

enum Source {
	INVALID,
	BLOCK,
	OFF_BLOCK,
	AUTOMATIC,
	CHAIN,
	SPLITTER,
	BLASTER,
}

var receipt_id: StringName
var run_id: StringName
var root_id: StringName
var source: Source
var cash_total: int
var xp_total: int
var boss_id: StringName
var pending_blueprints: int
var settled_item_id: StringName
var settled_piece_count: int
var _decoded_types_valid := true


func _init(p_run_id: StringName, p_root_id: StringName, p_source: Source,
		p_cash_total: int, p_xp_total: int, p_boss_id: StringName = &"",
		p_pending_blueprints := 0, p_settled_item_id: StringName = &"",
		p_settled_piece_count := 0) -> void:
	run_id = p_run_id
	root_id = p_root_id
	receipt_id = make_identity(run_id, root_id)
	source = p_source
	cash_total = p_cash_total
	xp_total = p_xp_total
	boss_id = p_boss_id
	pending_blueprints = p_pending_blueprints
	settled_item_id = p_settled_item_id
	settled_piece_count = p_settled_piece_count


static func make_identity(p_run_id: StringName, p_root_id: StringName) -> StringName:
	return StringName("%s::root::%s" % [p_run_id, p_root_id]) \
		if p_run_id != &"" and p_root_id != &"" else &""


func is_valid() -> bool:
	return _decoded_types_valid and receipt_id != &"" \
		and receipt_id == make_identity(run_id, root_id) \
		and source >= Source.BLOCK and source <= Source.BLASTER \
		and cash_total >= 0 and xp_total >= 0 \
		and pending_blueprints in [0, 1] and settled_piece_count >= 0 \
		and ((boss_id == &"" and pending_blueprints == 0) \
			or (boss_id != &"" and pending_blueprints == 1))


func to_dict() -> Dictionary:
	return {
		"receipt_id": String(receipt_id),
		"run_id": String(run_id),
		"root_id": String(root_id),
		"source": source,
		"cash_total": cash_total,
		"xp_total": xp_total,
		"boss_id": String(boss_id),
		"pending_blueprints": pending_blueprints,
		"settled_item_id": String(settled_item_id),
		"settled_piece_count": settled_piece_count,
	}


static func from_dict(data: Dictionary) -> RootCompletionReceipt:
	var valid_types := true
	var strings: Dictionary = {}
	for key: String in ["run_id", "root_id", "boss_id", "settled_item_id"]:
		var value: Variant = data.get(key, "")
		if not (value is String or value is StringName):
			valid_types = false
			value = ""
		strings[key] = StringName(value)
	var integers: Dictionary = {}
	for key: String in ["source", "cash_total", "xp_total", "pending_blueprints",
			"settled_piece_count"]:
		var value: Variant = data.get(key, 0)
		if not (value is int):
			valid_types = false
			value = -1
		integers[key] = int(value)
	var receipt := RootCompletionReceipt.new(
		strings.run_id, strings.root_id, integers.source, integers.cash_total,
		integers.xp_total, strings.boss_id, integers.pending_blueprints,
		strings.settled_item_id, integers.settled_piece_count)
	receipt._decoded_types_valid = valid_types
	return receipt
