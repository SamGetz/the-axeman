class_name MechanicalSplitterRuntime
extends Node
## M8 Slice 4's bounded, watched-only Mechanical Splitter runtime. It owns only
## ephemeral work: the persisted Tree Catalog assignment remains in GameState,
## and completed stock is written only through InventoryManager before the
## automation-specific Market receipt pays cash through GameState.

signal state_changed(state: State)
signal progress_changed(progress: float)
signal cycle_completed(species_id: StringName, item_id: StringName, amount: int,
	receipt_id: StringName)
## Presentation-only settlement boundary. The started signal fires before cash
## becomes authoritative so a pooled coin can hold the HUD counter; cancellation
## removes that unpaid receipt when inventory/buyer settlement blocks.
signal cycle_settlement_started(receipt_id: StringName, species_id: StringName)
signal cycle_settlement_cancelled(receipt_id: StringName)

enum State {
	LOCKED,
	UNASSIGNED,
	MISSING_PROFILE,
	READY,
	PROCESSING,
	OUTPUT_BLOCKED,
}

const _CONFIG_PATH := "res://data/mechanical_splitter_runtime.tres"

@export var config: MechanicalSplitterRuntimeDef

var _yard_active := false
var _queued_species: StringName = &""
var _processing_left := 0.0
var _processing_duration := 0.0
var _pending_output: Dictionary = {}
var _completed_receipt_id: StringName = &""
var _cycle_serial := 0
var _last_state := -1
var _last_cash_earned := 0
var _last_xp_earned := 0
var _last_logs_processed := 0


func _ready() -> void:
	if config == null:
		config = load(_CONFIG_PATH) as MechanicalSplitterRuntimeDef
	GameState.splitter_assignment_changed.connect(_on_routing_changed)
	GameState.building_tiers_changed.connect(_on_routing_changed)
	_publish_state(true)
	set_process(true)


func set_yard_active(active: bool) -> void:
	_yard_active = active
	_publish_state()


func is_yard_active() -> bool:
	return _yard_active


func current_state() -> State:
	if not MechanicalSplitter.is_installed():
		return State.LOCKED
	var assigned := GameState.get_splitter_assigned_species()
	if assigned == &"":
		return State.UNASSIGNED
	if not MechanicalSplitter.can_accept_species(assigned):
		return State.MISSING_PROFILE
	if not _pending_output.is_empty():
		return State.OUTPUT_BLOCKED
	if _queued_species != &"":
		return State.PROCESSING
	return State.READY


static func state_title(state: State) -> String:
	match state:
		State.LOCKED:
			return "LOCKED"
		State.UNASSIGNED:
			return "UNASSIGNED"
		State.MISSING_PROFILE:
			return "MISSING PROFILE"
		State.READY:
			return "READY"
		State.PROCESSING:
			return "PROCESSING"
		State.OUTPUT_BLOCKED:
			return "OUTPUT BLOCKED"
	return "UNKNOWN"


func state_detail() -> String:
	var assigned := GameState.get_splitter_assigned_species()
	var species := SpeciesTable.by_id(assigned)
	var species_name := String(assigned) if species == null else species.display_name
	match current_state():
		State.LOCKED:
			return "Purchase the machine in Shop."
		State.UNASSIGNED:
			return "Choose one installed profile in Tree Catalog."
		State.MISSING_PROFILE:
			return "%s needs its certified installed profile." % species_name
		State.READY:
			return "%s · %d log batch · %.1fs watched cycle." % [
				species_name, effective_logs_per_split(), effective_duration_seconds()]
		State.PROCESSING:
			return "%s · %d represented log(s) · watched yard time only." % [
				species_name, effective_logs_per_split()]
		State.OUTPUT_BLOCKED:
			return "%s output is waiting for inventory/buyer settlement." % species_name
	return ""


func progress() -> float:
	if _queued_species == &"" or _processing_duration <= 0.0:
		return 0.0
	return clampf(1.0 - _processing_left / _processing_duration,
		0.0, 1.0)


func queued_count() -> int:
	return 0 if _queued_species == &"" else 1


func queued_species() -> StringName:
	return _queued_species


func effective_duration_seconds() -> float:
	if config == null:
		return 0.0
	var speed := Shop.total_effect(UpgradeDef.Effect.AUTOMATION_SPEED)
	var multiplier := maxf(config.minimum_duration_multiplier, 1.0 - speed)
	return config.processing_duration_seconds * multiplier


func auto_loading_enabled() -> bool:
	return Shop.total_effect(UpgradeDef.Effect.AUTOMATION_AUTO_LOAD) > 0.0


func effective_logs_per_split() -> int:
	if config == null:
		return 0
	var ranked_logs := config.base_logs_per_split + maxi(0, int(round(
		Shop.total_effect(UpgradeDef.Effect.AUTOMATION_LOGS_PER_SPLIT))))
	return mini(config.maximum_logs_per_split, ranked_logs)


func effective_output_amount() -> int:
	return 0 if config == null else config.output_amount * effective_logs_per_split()


func automation_xp_rate() -> float:
	if config == null:
		return 0.0
	return clampf(config.base_xp_rate
		+ Shop.total_effect(UpgradeDef.Effect.AUTOMATION_XP_GAIN), 0.0, 1.0)


func automation_cash_bonus() -> float:
	return maxf(0.0, Shop.total_effect(UpgradeDef.Effect.AUTOMATION_CASH_GAIN))


func last_cash_earned() -> int:
	return _last_cash_earned


func last_xp_earned() -> int:
	return _last_xp_earned


func last_logs_processed() -> int:
	return _last_logs_processed


func has_completed_receipt() -> bool:
	return _completed_receipt_id != &""


## Fills the one physical input slot from the sole GameState-owned routing
## choice. Logs are transient work inputs in this project, not inventory items;
## supplier/delivery simulation remains deliberately out of scope.
func try_queue_assigned_input() -> bool:
	if current_state() != State.READY or config == null \
			or not config.validate().is_empty() or config.queue_capacity != 1:
		return false
	var assigned := GameState.get_splitter_assigned_species()
	if not MechanicalSplitter.can_accept_species(assigned):
		_publish_state(true)
		return false
	_queued_species = assigned
	_processing_duration = effective_duration_seconds()
	_processing_left = _processing_duration
	_cycle_serial += 1
	progress_changed.emit(0.0)
	_publish_state(true)
	return true


## A failed InventoryManager handoff leaves one immutable pending receipt. Retry
## never rebuilds or increments it, so a successful retry cannot double-award.
func retry_blocked_output() -> bool:
	if current_state() != State.OUTPUT_BLOCKED:
		return false
	return _deliver_pending_output()


func _process(delta: float) -> void:
	if not _yard_active or delta <= 0.0:
		return
	if current_state() == State.READY and auto_loading_enabled():
		try_queue_assigned_input()
	if current_state() != State.PROCESSING:
		return
	_processing_left = maxf(0.0, _processing_left - delta)
	progress_changed.emit(progress())
	if _processing_left <= 0.0:
		_finish_cycle()


func _finish_cycle() -> void:
	if _queued_species == &"" or not _pending_output.is_empty() or config == null:
		return
	var species := SpeciesTable.by_id(_queued_species)
	if species == null or species.yield_item == &"":
		_pending_output = {
			"receipt_id": _receipt_id(),
			"species_id": _queued_species,
			"item_id": &"",
			"amount": effective_output_amount(),
			"logs": effective_logs_per_split(),
			"inventory_deposited": false,
		}
		_publish_state(true)
		return
	_pending_output = {
		"receipt_id": _receipt_id(),
		"species_id": species.id,
		"item_id": species.yield_item,
		"amount": effective_output_amount(),
		"logs": effective_logs_per_split(),
		"inventory_deposited": false,
	}
	_deliver_pending_output()


func _deliver_pending_output() -> bool:
	if _pending_output.is_empty():
		return false
	var receipt_id := StringName(_pending_output.get("receipt_id", &""))
	var species_id := StringName(_pending_output.get("species_id", &""))
	var item_id := StringName(_pending_output.get("item_id", &""))
	var amount := int(_pending_output.get("amount", 0))
	var logs := int(_pending_output.get("logs", 0))
	var inventory_deposited := bool(_pending_output.get("inventory_deposited", false))
	if receipt_id == &"" or _completed_receipt_id == receipt_id:
		return false
	# Reserve before calling the writer so a synchronous inventory listener cannot
	# re-enter this handoff and receive the same completion twice.
	_completed_receipt_id = receipt_id
	cycle_settlement_started.emit(receipt_id, species_id)
	if not inventory_deposited:
		if not Market.is_sellable(item_id):
			_completed_receipt_id = &""
			cycle_settlement_cancelled.emit(receipt_id)
			_publish_state(true)
			return false
		if not InventoryManager.add_item(item_id, amount):
			_completed_receipt_id = &""
			cycle_settlement_cancelled.emit(receipt_id)
			_publish_state(true)
			return false
		_pending_output["inventory_deposited"] = true
	var cash_earned := Market.sell_automation(item_id, amount, automation_cash_bonus())
	if cash_earned <= 0:
		_completed_receipt_id = &""
		cycle_settlement_cancelled.emit(receipt_id)
		_publish_state(true)
		return false
	var species := SpeciesTable.by_id(species_id)
	var xp_earned := 0
	if species != null and logs > 0:
		xp_earned = maxi(0, int(round(
			float(species.xp_reward * logs) * automation_xp_rate())))
		if xp_earned > 0:
			GameState.add_xp(xp_earned)
	_last_cash_earned = cash_earned
	_last_xp_earned = xp_earned
	_last_logs_processed = logs
	_pending_output = {}
	_queued_species = &""
	_processing_left = 0.0
	_processing_duration = 0.0
	progress_changed.emit(0.0)
	_publish_state(true)
	cycle_completed.emit(species_id, item_id, amount, receipt_id)
	return true


func _receipt_id() -> StringName:
	return StringName("splitter_%d_%d" % [get_instance_id(), _cycle_serial])


## Loading/resetting or choosing a different Tree Catalog route cancels only
## ephemeral watched work. No queued progress or pending output is persisted or
## converted into stock, which is the no-free-output restore rule.
func _on_routing_changed(_ignored: Variant = null) -> void:
	_reset_ephemeral_work()
	_publish_state(true)


func _reset_ephemeral_work() -> void:
	_queued_species = &""
	_processing_left = 0.0
	_processing_duration = 0.0
	_pending_output = {}
	_completed_receipt_id = &""
	_last_cash_earned = 0
	_last_xp_earned = 0
	_last_logs_processed = 0
	progress_changed.emit(0.0)


func _publish_state(force := false) -> void:
	var state := int(current_state())
	if not force and state == _last_state:
		return
	_last_state = state
	state_changed.emit(state as State)
