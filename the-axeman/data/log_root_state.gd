class_name LogRootState
extends RefCounted
## Shared serializable state for one delivered root and all physical descendants.

enum CompletionState { ACTIVE, COMPLETING, COMPLETED }

var descriptor: LogDescriptor
var descendants: Array[LogDescendantState] = []
var cut_journal: Array[Dictionary] = []
var boundary_exposure := 0.0
var arena_sliced := false
var completion_state: CompletionState = CompletionState.ACTIVE
var completion_receipt: RootCompletionReceipt
var _decoded_types_valid := true


func to_dict() -> Dictionary:
	var saved_descendants: Array[Dictionary] = []
	for descendant: LogDescendantState in descendants:
		if descendant != null:
			saved_descendants.append(descendant.to_dict())
	return {
		"descriptor": {} if descriptor == null else descriptor.to_dict(),
		"descendants": saved_descendants,
		"cut_journal": cut_journal.duplicate(true),
		"boundary_exposure": boundary_exposure,
		"arena_sliced": arena_sliced,
		"completion_state": completion_state,
		"completion_receipt": {} if completion_receipt == null \
			else completion_receipt.to_dict(),
	}


static func from_dict(data: Dictionary) -> LogRootState:
	var state := LogRootState.new()
	var descriptor_data: Variant = data.get("descriptor", {})
	if descriptor_data is Dictionary and not (descriptor_data as Dictionary).is_empty():
		state.descriptor = LogDescriptor.from_save_dict(descriptor_data)
	elif not (descriptor_data is Dictionary):
		state._decoded_types_valid = false
	var raw_descendants: Variant = data.get("descendants", [])
	if raw_descendants is Array:
		for raw: Variant in raw_descendants:
			if raw is Dictionary:
				state.descendants.append(LogDescendantState.from_dict(raw))
			else:
				state._decoded_types_valid = false
	else:
		state._decoded_types_valid = false
	var raw_journal: Variant = data.get("cut_journal", [])
	if raw_journal is Array:
		for raw: Variant in raw_journal:
			if raw is Dictionary:
				state.cut_journal.append((raw as Dictionary).duplicate(true))
			else:
				state._decoded_types_valid = false
	else:
		state._decoded_types_valid = false
	var exposure_value: Variant = data.get("boundary_exposure", 0.0)
	if exposure_value is int or exposure_value is float:
		state.boundary_exposure = float(exposure_value)
	else:
		state._decoded_types_valid = false
		state.boundary_exposure = NAN
	var sliced_value: Variant = data.get("arena_sliced", false)
	if sliced_value is bool:
		state.arena_sliced = sliced_value
	else:
		state._decoded_types_valid = false
	var completion_value: Variant = data.get("completion_state",
		CompletionState.ACTIVE)
	if completion_value is int and int(completion_value) >= CompletionState.ACTIVE \
			and int(completion_value) <= CompletionState.COMPLETED:
		state.completion_state = int(completion_value)
	else:
		state._decoded_types_valid = false
	var receipt_data: Variant = data.get("completion_receipt", {})
	if receipt_data is Dictionary and not (receipt_data as Dictionary).is_empty():
		state.completion_receipt = RootCompletionReceipt.from_dict(receipt_data)
	elif not (receipt_data is Dictionary):
		state._decoded_types_valid = false
	return state


func is_valid() -> bool:
	if not _decoded_types_valid or descriptor == null \
			or not descriptor.is_valid_run_snapshot() \
			or boundary_exposure < 0.0 or not is_finite(boundary_exposure):
		return false
	var ids: Dictionary = {}
	for descendant: LogDescendantState in descendants:
		if descendant == null or not descendant.is_valid() \
				or not _descendant_belongs_to_root(descendant) \
				or ids.has(descendant.id):
			return false
		ids[descendant.id] = true
	if completion_state == CompletionState.COMPLETED:
		return completion_receipt != null and completion_receipt.is_valid() \
			and completion_receipt.run_id == descriptor.run_id \
			and completion_receipt.root_id == descriptor.id \
			and completion_receipt.boss_id == descriptor.boss_id \
			and completion_receipt.cash_total == descriptor.cash_reward_snapshot \
			and completion_receipt.xp_total == descriptor.xp_reward_snapshot
	return completion_receipt == null


func _descendant_belongs_to_root(descendant: LogDescendantState) -> bool:
	var root_path := String(descriptor.id)
	var piece_path := String(descendant.id)
	if piece_path == root_path:
		return descendant.parent_id == &""
	if not piece_path.begins_with(root_path + "/") or piece_path.ends_with("/") \
			or piece_path.contains("//"):
		return false
	var slash := piece_path.rfind("/")
	return slash > 0 and descendant.parent_id == StringName(piece_path.left(slash))
