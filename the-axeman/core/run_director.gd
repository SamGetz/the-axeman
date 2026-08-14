class_name RunDirector
extends Node
## Sole authority for disposable attempt state. Permanent writes are explicit
## transactions into GameState; inventory writes remain in InventoryManager.

enum Phase { PREP, ACTIVE, EARTH_CLEAR, OVERFLOW, FAILED, SUSPENDED, COMPLETE }
enum Powerup { SLOW_TIME, LOG_BLASTER }

signal phase_changed(phase: Phase)
signal pause_changed(paused: bool)
signal run_identity_changed(run_id: StringName)
signal cash_changed(amount: int)
signal xp_changed(total: int)
signal level_gained(level: int)
signal level_choice_changed(offer: Dictionary)
signal power_slots_changed(slots: Array, ranks: Dictionary)
signal utility_charges_changed(rerolls: int, banishes: int)
signal earth_changed(remaining: int, cleared: int)
signal run_clock_changed(elapsed_ms: int)
signal stage_time_changed(remaining_ms: int)
signal delivery_changed(seconds_left: float, tier: int)
signal loose_logs_changed(count: int)
signal boundary_warning_changed(log_id: StringName, seconds_left: float)
signal powerups_changed(slow_charges: int, blaster_ammo: int, slow_seconds: float)
signal powerup_dropped(kind: Powerup)
signal splitter_changed(installed: bool, reliability_rank: int, seconds_left: float)
signal splitter_rescued(log_id: StringName)
signal earth_cleared(clear_ms: int)
signal stage_cleared(clear_ms: int)
signal attempt_finished(results: Dictionary)
signal settlement_failed(message: String)
signal attempt_snapshot_dirty
signal active_log_requested(descriptor: LogDescriptor)

@export var tuning: SurvivalRunTuning

const MAX_RUN_POWER_SLOTS := 6
const BASE_OFFER_CARD_COUNT := 3
const LUCK_OFFER_CARD_COUNT := 4
const PAYDAY_POWER_ID := &"payday"

var phase: Phase = Phase.PREP
var _paused := true
var _cash := 0
var _xp := 0
var _run_id: StringName = &""
var _xp_awarded_root_ids: Dictionary = {}
var _power_slot_order: Array[StringName] = []
var _power_ranks: Dictionary = {}
var _banned_power_ids: Dictionary = {}
var _rerolls_remaining := 0
var _banishes_remaining := 0
var _earned_unpresented_levels: Array[int] = []
var _ready_level_choices: Array[int] = []
var _completed_level_choices: Dictionary = {}
var _current_offer: Dictionary = {}
var _offer_paused_run := false
var _offer_serial := 0
var _payday_picks := 0
var _bank_receipt: Dictionary = {}
var _earth_remaining: int = GameState.TOTAL_EARTH_TREES
var _elapsed_seconds := 0.0
var _earth_clear_seconds := -1.0
var _delivery_seconds_left := 0.0
var _delivery_tier := 0
var _slow_charges := 0
var _blaster_ammo := 0
var _slow_seconds_left := 0.0
var _splitter_installed := false
var _splitter_reliability_rank := 0
var _splitter_seconds_left := 0.0
var _spawn_serial := 0
var _waiting_for_active_log := false
var _active_log_id: StringName = &""
var _boundary_timers_paused := false
var _manual_clears := 0
var _splitter_rescues := 0
var _peak_loose_logs := 0
var _cash_earned := 0
var _cash_spent := 0
var _permanent_purchases := 0
var _pending_piece_cash: Array[int] = []
var _rng := RandomNumberGenerator.new()
var _arena: Node
var _chopping: Node


func _ready() -> void:
	if tuning == null:
		tuning = load("res://data/survival_run_tuning_placeholder.tres") as SurvivalRunTuning
	if tuning == null:
		push_error("RunDirector: survival tuning is missing.")
		set_process(false)
		return
	for error: String in tuning.validate():
		push_error("RunDirector tuning: " + error)


func bind_runtime(chopping: Node, arena: Node) -> void:
	_chopping = chopping
	_arena = arena
	if _arena != null:
		_arena.call("bind_run", self, _chopping, tuning)
		if _arena.has_signal("loose_count_changed"):
			_arena.loose_count_changed.connect(_on_loose_count_changed)
		if _arena.has_signal("boundary_warning"):
			_arena.boundary_warning.connect(_on_boundary_warning)
		if _arena.has_signal("breach_expired"):
			_arena.breach_expired.connect(_on_breach_expired)
		if _arena.has_signal("log_landed"):
			_arena.log_landed.connect(_on_loose_log_landed)
	if _chopping != null:
		_chopping.call("bind_run_director", self)
		if _chopping.has_signal("block_ready_for_log"):
			_chopping.block_ready_for_log.connect(_claim_next_active_log)
		if _chopping.has_signal("run_log_ready"):
			_chopping.run_log_ready.connect(_on_run_log_ready)


func _process(delta: float) -> void:
	if _paused or phase not in [Phase.ACTIVE, Phase.OVERFLOW]:
		return
	_elapsed_seconds += delta
	if phase == Phase.ACTIVE and _elapsed_seconds >= stage_duration_seconds():
		_elapsed_seconds = stage_duration_seconds()
		run_clock_changed.emit(elapsed_ms())
		stage_time_changed.emit(0)
		_enter_stage_clear()
		return
	if _slow_seconds_left > 0.0:
		_slow_seconds_left = maxf(0.0, _slow_seconds_left - delta)
		if is_zero_approx(_slow_seconds_left):
			powerups_changed.emit(_slow_charges, _blaster_ammo, 0.0)
	var hazard_delta := delta * hazard_speed_multiplier()
	_delivery_seconds_left -= hazard_delta
	while _delivery_seconds_left <= 0.0:
		_delivery_seconds_left += delivery_interval()
		if tuning.loose_log_soft_cap > 0 and loose_log_count() >= tuning.loose_log_soft_cap:
			break
		_spawn_timed_log()
	if _splitter_installed:
		_splitter_seconds_left -= hazard_delta
		if _splitter_seconds_left <= 0.0:
			_splitter_seconds_left += tuning.splitter_cycle_seconds
			_resolve_splitter_cycle()
	if _arena != null:
		_arena.call("advance_hazards", hazard_delta, hazard_speed_multiplier())
	run_clock_changed.emit(elapsed_ms())
	stage_time_changed.emit(stage_remaining_ms())
	delivery_changed.emit(_delivery_seconds_left, _delivery_tier)
	if _splitter_installed:
		splitter_changed.emit(true, _splitter_reliability_rank, _splitter_seconds_left)


# ---------------------------------------------------------------- lifecycle
func start_attempt(seed: int = 0) -> void:
	_cancel_xp_presentations()
	_reset_attempt_state()
	_run_id = _make_run_id(seed)
	if _run_id == &"":
		push_error("RunDirector: could not allocate a unique run identity.")
		return
	_rng.seed = seed if seed != 0 else int(Time.get_unix_time_from_system() * 1000000.0)
	_rerolls_remaining = maxi(0, int(round(GameState.get_meta_effect(
		ProgressionEffectDef.Kind.REROLL_CHARGES))))
	_banishes_remaining = maxi(0, int(round(GameState.get_meta_effect(
		ProgressionEffectDef.Kind.BANISH_CHARGES))))
	phase = Phase.ACTIVE
	_paused = false
	_delivery_tier = GameState.get_selected_frequency_tier()
	_delivery_seconds_left = delivery_interval()
	GameState.set_permanent_controls_locked(true)
	if _arena != null:
		_arena.call("clear_all")
	_set_boundary_timers_paused(false)
	_set_runtime_paused(false)
	var initial := _make_descriptor()
	_active_log_id = initial.id
	active_log_requested.emit(initial)
	if _chopping != null:
		_chopping.call("stage_run_log", initial, false)
	run_identity_changed.emit(_run_id)
	_emit_full_attempt_refresh()
	attempt_snapshot_dirty.emit()


func pause_attempt() -> void:
	if phase not in [Phase.ACTIVE, Phase.OVERFLOW] or _paused:
		return
	_paused = true
	_set_runtime_paused(true)
	pause_changed.emit(true)


func resume_attempt() -> void:
	if phase not in [Phase.ACTIVE, Phase.OVERFLOW, Phase.EARTH_CLEAR]:
		return
	if not _current_offer.is_empty():
		_paused = true
		_set_runtime_paused(true)
		pause_changed.emit(true)
		return
	# A generic resume must not silently choose Endless for a restored stage-clear
	# decision. Only the explicit Continue Endless action may cross this boundary.
	if phase == Phase.EARTH_CLEAR:
		_paused = true
		_set_runtime_paused(true)
		pause_changed.emit(true)
		stage_cleared.emit(earth_clear_ms())
		return
	_paused = false
	_set_runtime_paused(false)
	pause_changed.emit(false)


func continue_endless() -> bool:
	if phase != Phase.EARTH_CLEAR or not _current_offer.is_empty():
		return false
	phase = Phase.OVERFLOW
	_paused = false
	_set_runtime_paused(false)
	phase_changed.emit(phase)
	pause_changed.emit(false)
	stage_time_changed.emit(0)
	attempt_snapshot_dirty.emit()
	return true


func suspend_attempt() -> Dictionary:
	if not has_live_attempt():
		return {}
	pause_attempt()
	if _chopping != null and _chopping.has_method("prepare_for_suspend"):
		_chopping.call("prepare_for_suspend")
	_present_all_earned_level_choices()
	var previous := phase
	phase = Phase.SUSPENDED
	phase_changed.emit(phase)
	var snapshot := to_save_dict()
	snapshot["phase"] = previous
	phase = previous
	GameState.set_permanent_controls_locked(true)
	return snapshot


func abandon_attempt() -> void:
	if _arena != null:
		_arena.call("clear_all")
	if _chopping != null:
		_cancel_xp_presentations()
		_chopping.call("clear_run_log")
	_reset_attempt_state()
	run_identity_changed.emit(&"")
	GameState.set_permanent_controls_locked(false)
	_set_boundary_timers_paused(false)
	_set_runtime_paused(true)
	phase_changed.emit(phase)
	pause_changed.emit(true)
	attempt_snapshot_dirty.emit()


func has_live_attempt() -> bool:
	return phase in [Phase.ACTIVE, Phase.EARTH_CLEAR, Phase.OVERFLOW, Phase.SUSPENDED]


func is_paused() -> bool:
	return _paused


func is_gameplay_active() -> bool:
	return not _paused and phase in [Phase.ACTIVE, Phase.OVERFLOW]


# ---------------------------------------------------------------- deliveries
func max_delivery_tier() -> int:
	var yard := _yard_definition()
	var tier_count := yard.starting_delivery_intervals.size() \
		if yard != null else tuning.delivery_intervals.size()
	return clampi(GameState.get_max_frequency_tier(), 0,
		maxi(0, tier_count - 1))


func set_delivery_tier(tier: int) -> bool:
	# Starting frequency is selected at Home. A live attempt cannot alter it.
	return false


func delivery_interval() -> float:
	return _delivery_interval_for_level(get_level())


func _delivery_interval_for_level(level: int) -> float:
	var yard := _yard_definition()
	if yard != null and not yard.starting_delivery_intervals.is_empty():
		var tier := clampi(_delivery_tier, 0,
			yard.starting_delivery_intervals.size() - 1)
		return maxf(yard.delivery_interval_floor,
			float(yard.starting_delivery_intervals[tier])
			* yard.delivery_multiplier(level))
	var tier := clampi(_delivery_tier, 0, tuning.delivery_intervals.size() - 1)
	return float(tuning.delivery_intervals[tier])


func _spawn_timed_log() -> void:
	if _arena == null:
		return
	_arena.call("spawn_loose_log", _make_descriptor(), _rng.randi())
	attempt_snapshot_dirty.emit()


func _make_descriptor() -> LogDescriptor:
	_spawn_serial += 1
	var species_id := _pick_timeline_species()
	var species := SpeciesTable.by_id(species_id)
	var mesh_count := 1 if species == null else maxi(1, species.meshes.size())
	var descriptor := LogDescriptor.create(
		StringName("run_log_%d" % _spawn_serial), species_id,
		_rng.randi_range(0, mesh_count - 1), _spawn_serial, _rng.randi())
	var yard_id := GameState.get_selected_yard()
	var yards := SurvivorsContent.yards()
	var yard := yards.by_id(yard_id) if yards != null else null
	var reward := yard.reward_for_species(species_id) if yard != null else null
	descriptor.run_id = _run_id
	descriptor.yard_id = yard_id
	descriptor.hardness_snapshot = 1.0 if yard == null \
		else yard.hardness_multiplier(get_level())
	if reward != null:
		descriptor.cash_reward_snapshot = _scaled_reward_snapshot(
			reward.cash_reward, ProgressionEffectDef.Kind.SESSION_CASH_MULTIPLIER)
		descriptor.xp_reward_snapshot = _scaled_reward_snapshot(
			reward.xp_reward, ProgressionEffectDef.Kind.RUN_XP_MULTIPLIER)
	return descriptor


func _scaled_reward_snapshot(base_amount: int,
		kind: ProgressionEffectDef.Kind) -> int:
	if base_amount <= 0:
		return 0
	var multiplier := maxf(1.0, get_effect(kind))
	var scaled := float(base_amount) * multiplier
	if not is_finite(scaled) or scaled >= float(GameState.MAX_SAFE_ECONOMY_VALUE):
		return GameState.MAX_SAFE_ECONOMY_VALUE
	return clampi(maxi(base_amount, int(round(scaled))), 1,
		GameState.MAX_SAFE_ECONOMY_VALUE)


func _pick_timeline_species() -> StringName:
	var yard := _yard_definition()
	if yard == null or yard.species_timeline.is_empty():
		return GameState.get_selected_species()
	var active: Array[YardTimelineEntryDef] = []
	var total_weight := 0.0
	for entry: YardTimelineEntryDef in yard.species_timeline:
		if entry == null or _elapsed_seconds < entry.start_seconds \
				or _elapsed_seconds >= entry.end_seconds:
			continue
		active.append(entry)
		total_weight += entry.weight
	if active.is_empty() or total_weight <= 0.0:
		return yard.species_timeline[0].species_id
	var roll := _rng.randf() * total_weight
	for entry: YardTimelineEntryDef in active:
		roll -= entry.weight
		if roll <= 0.0:
			return entry.species_id
	return active[-1].species_id


func _claim_next_active_log() -> void:
	_active_log_id = &""
	if _arena == null:
		_waiting_for_active_log = true
		return
	var selected_id: StringName = &""
	if _arena.has_method("highest_risk_outside_log_id"):
		selected_id = _arena.call("highest_risk_outside_log_id")
	if selected_id == &"":
		var ids: Array = _arena.call("eligible_log_ids")
		if ids.is_empty():
			_waiting_for_active_log = true
			return
		selected_id = ids[_rng.randi_range(0, ids.size() - 1)]
	var descriptor: LogDescriptor = _arena.call("claim_for_block", selected_id)
	if descriptor == null:
		_waiting_for_active_log = true
		return
	_waiting_for_active_log = false
	_active_log_id = descriptor.id
	active_log_requested.emit(descriptor)
	if _chopping != null:
		_chopping.call("stage_run_log", descriptor, true)
	attempt_snapshot_dirty.emit()


func _on_loose_log_landed(_id: StringName) -> void:
	if _waiting_for_active_log:
		_claim_next_active_log()


func _on_run_log_ready() -> void:
	_set_boundary_timers_paused(false)


# ---------------------------------------------------------------- completion / economy
func complete_manual_log(descriptor: LogDescriptor, piece_count: int) -> Dictionary:
	if descriptor == null or descriptor.id != _active_log_id \
			or descriptor.run_id != _run_id \
			or descriptor.yard_id != GameState.get_selected_yard() \
			or descriptor.cash_reward_snapshot <= 0 \
			or phase not in [Phase.ACTIVE, Phase.OVERFLOW]:
		return {}
	_active_log_id = &""
	_set_boundary_timers_paused(true)
	_manual_clears += 1
	GameState.record_manual_completion()
	var cash_total := _prepare_root_cash_shares(descriptor, piece_count)
	attempt_snapshot_dirty.emit()
	return {
		"earth_cleared": 0,
		"piece_count": maxi(0, piece_count),
		"batch_size": current_batch_size(),
		"cash_total": cash_total,
	}


func settle_firewood(item_id: StringName, amount: int = 1) -> int:
	var unit := Market.get_price(item_id)
	if amount <= 0 or unit <= 0 or not InventoryManager.remove_items([{
		"item_id": item_id, "amount": amount,
	}]):
		return 0
	var multiplier := maxf(1.0, GameState.get_meta_effect(
		ProgressionEffectDef.Kind.SESSION_CASH_MULTIPLIER))
	return award_cash(maxi(unit * amount,
		int(round(float(unit * amount) * multiplier))))


func settle_completed_piece(item_id: StringName) -> int:
	if item_id == &"" or not InventoryManager.add_item(item_id, 1) \
			or not InventoryManager.remove_items([{
				"item_id": item_id,
				"amount": 1,
			}]):
		return 0
	if _pending_piece_cash.is_empty():
		return 0
	# Currency was committed atomically when the root completed. Landing pieces
	# only validate the inventory receipt and attach display shares to coins.
	return _pending_piece_cash.pop_front()


func _prepare_root_cash_shares(descriptor: LogDescriptor, piece_count: int) -> int:
	_pending_piece_cash.clear()
	if descriptor == null or descriptor.cash_reward_snapshot <= 0:
		return 0
	var total := descriptor.cash_reward_snapshot
	var accepted := award_cash(total)
	if piece_count <= 0:
		return accepted
	var quotient := int(accepted / piece_count)
	var remainder := accepted % piece_count
	for index: int in range(piece_count):
		_pending_piece_cash.append(quotient + (1 if index < remainder else 0))
	return accepted


func _pending_piece_cash_total() -> int:
	var total := 0
	for share: int in _pending_piece_cash:
		total += share
	return total


func award_cash(amount: int) -> int:
	if amount <= 0 or not has_live_attempt():
		return 0
	var room := GameState.MAX_SAFE_ECONOMY_VALUE - _cash
	var accepted := mini(room, amount)
	_cash += accepted
	_cash_earned += accepted
	cash_changed.emit(_cash)
	attempt_snapshot_dirty.emit()
	return accepted


## Disposable run XP is authoritative immediately. The HUD deliberately trails
## this total until its presentation receipts arrive at the bar.
func award_xp(base_amount: int) -> int:
	if base_amount <= 0 or phase not in [Phase.ACTIVE, Phase.OVERFLOW]:
		return 0
	var multiplier := maxf(1.0, get_effect(
		ProgressionEffectDef.Kind.RUN_XP_MULTIPLIER))
	var scaled := maxi(base_amount, int(round(float(base_amount) * multiplier)))
	return _commit_xp(scaled)


func _commit_xp(amount: int) -> int:
	if amount <= 0 or phase not in [Phase.ACTIVE, Phase.OVERFLOW]:
		return 0
	var room := GameState.MAX_SAFE_ECONOMY_VALUE - _xp
	var accepted := mini(room, amount)
	if accepted <= 0:
		return 0
	var previous_level := get_level()
	var previous_interval := _delivery_interval_for_level(previous_level)
	_xp += accepted
	var next_level := get_level()
	if next_level > previous_level and previous_interval > 0.0:
		var remaining_progress := clampf(
			_delivery_seconds_left / previous_interval, 0.0, 1.0)
		_delivery_seconds_left = remaining_progress \
			* _delivery_interval_for_level(next_level)
	xp_changed.emit(_xp)
	for level: int in range(previous_level + 1, next_level + 1):
		if not _level_choice_is_tracked(level):
			_earned_unpresented_levels.append(level)
		level_gained.emit(level)
	if next_level > previous_level:
		delivery_changed.emit(_delivery_seconds_left, _delivery_tier)
	attempt_snapshot_dirty.emit()
	return accepted


## Exact-once XP transaction for the root currently staged on the block. The
## descriptor must belong to this run and carry its delivery-time reward
## snapshot; presentation orbs remain a separate receipt emitted by chopping.
func award_root_xp(descriptor: LogDescriptor, base_amount: int) -> int:
	if descriptor == null or base_amount <= 0 \
			or phase not in [Phase.ACTIVE, Phase.OVERFLOW] \
			or descriptor.id == &"" or descriptor.id != _active_log_id \
			or descriptor.run_id != _run_id \
			or descriptor.yard_id != GameState.get_selected_yard() \
			or descriptor.xp_reward_snapshot <= 0 \
			or base_amount != descriptor.xp_reward_snapshot:
		return 0
	var receipt_id := _root_xp_receipt_id(descriptor.id)
	if _xp_awarded_root_ids.has(receipt_id):
		return 0
	# Mark before award_xp emits dirty/signal callbacks, so a synchronous save can
	# never capture the XP without its duplicate guard.
	_xp_awarded_root_ids[receipt_id] = true
	var awarded := _commit_xp(descriptor.xp_reward_snapshot)
	if awarded <= 0:
		_xp_awarded_root_ids.erase(receipt_id)
	return awarded


func xp_reward_for(descriptor: LogDescriptor) -> int:
	if descriptor == null:
		return 0
	if descriptor.xp_reward_snapshot > 0:
		return descriptor.xp_reward_snapshot
	# A v19 run descriptor without a snapshot is malformed. Only legacy local
	# harness descriptors may consult the mutable catalogue fallback.
	if descriptor.run_id != &"":
		return 0
	var yard_id := descriptor.yard_id if descriptor.yard_id != &"" \
		else GameState.get_selected_yard()
	var yards := SurvivorsContent.yards()
	var yard := yards.by_id(yard_id) if yards != null else null
	var reward := yard.reward_for_species(descriptor.species_id) \
		if yard != null else null
	return 0 if reward == null else reward.xp_reward


# -------------------------------------------------------------- run choices
## Called only after the corresponding orb fills the bar and the HUD presents
## the level. Authoritative level gain records the entitlement earlier without
## pausing, avoiding an orb/offer deadlock across multi-level awards.
func present_level_choice(level: int) -> bool:
	var index := _earned_unpresented_levels.find(level)
	if index < 0 or level <= 1 or level > get_level():
		return false
	_earned_unpresented_levels.remove_at(index)
	_ready_level_choices.append(level)
	_open_next_level_offer()
	attempt_snapshot_dirty.emit()
	return true


func choose_run_offer(power_id: StringName) -> bool:
	if _current_offer.is_empty() or not _offer_contains(power_id):
		return false
	var level := int(_current_offer.get("level", 1))
	if power_id == PAYDAY_POWER_ID:
		var payday_amount := 0
		for card: Dictionary in _offer_cards():
			if StringName(card.get("id", "")) == PAYDAY_POWER_ID:
				payday_amount = maxi(0, int(card.get("cash", 0)))
				break
		if payday_amount <= 0:
			return false
		_payday_picks += 1
		award_cash(payday_amount)
	else:
		var definition := _run_power_definition(power_id)
		if definition == null:
			return false
		var current_rank := get_run_power_rank(power_id)
		if current_rank >= definition.rank_cap:
			return false
		if current_rank <= 0:
			if _power_slot_order.size() >= MAX_RUN_POWER_SLOTS:
				return false
			_power_slot_order.append(power_id)
		_power_ranks[power_id] = current_rank + 1
		power_slots_changed.emit(get_power_slots(), get_run_power_ranks())
	_completed_level_choices[level] = true
	_current_offer.clear()
	level_choice_changed.emit({})
	if not _ready_level_choices.is_empty():
		_open_next_level_offer()
	else:
		_finish_level_offer_pause()
	attempt_snapshot_dirty.emit()
	return true


func reroll_run_offer() -> bool:
	if _current_offer.is_empty() or _rerolls_remaining <= 0:
		return false
	var level := int(_current_offer.get("level", 1))
	var slot_count := clampi(int(_current_offer.get("slot_count",
		BASE_OFFER_CARD_COUNT)), BASE_OFFER_CARD_COUNT, LUCK_OFFER_CARD_COUNT)
	var previous_ids: Array[StringName] = []
	for card: Dictionary in _offer_cards():
		var previous_id := StringName(card.get("id", ""))
		if previous_id != PAYDAY_POWER_ID:
			previous_ids.append(previous_id)
	_rerolls_remaining -= 1
	_current_offer = _build_level_offer(level, slot_count, previous_ids)
	utility_charges_changed.emit(_rerolls_remaining, _banishes_remaining)
	level_choice_changed.emit(get_current_offer())
	attempt_snapshot_dirty.emit()
	return true


func banish_run_offer(power_id: StringName) -> bool:
	if _current_offer.is_empty() or _banishes_remaining <= 0 \
			or power_id == PAYDAY_POWER_ID:
		return false
	var cards := _offer_cards()
	if cards.size() <= 1:
		return false
	var found_index := -1
	for index: int in range(cards.size()):
		if StringName(cards[index].get("id", "")) == power_id:
			found_index = index
			break
	if found_index < 0:
		return false
	cards.remove_at(found_index)
	_banned_power_ids[power_id] = true
	_banishes_remaining -= 1
	_current_offer["cards"] = cards
	utility_charges_changed.emit(_rerolls_remaining, _banishes_remaining)
	level_choice_changed.emit(get_current_offer())
	attempt_snapshot_dirty.emit()
	return true


func get_current_offer() -> Dictionary:
	return _current_offer.duplicate(true)


func get_power_slots() -> Array[StringName]:
	return _power_slot_order.duplicate()


func get_run_power_ranks() -> Dictionary:
	var out: Dictionary = {}
	for raw_id: Variant in _power_ranks:
		out[String(raw_id)] = get_run_power_rank(StringName(raw_id))
	return out


func get_run_power_rank(power_id: StringName) -> int:
	var definition := _run_power_definition(power_id)
	return 0 if definition == null else clampi(
		int(_power_ranks.get(power_id, 0)), 0, definition.rank_cap)


## Effective modifiers are composed once here so gameplay never needs to know
## whether a value came from the permanent grid or this attempt's six powers.
func get_effect(kind: ProgressionEffectDef.Kind) -> float:
	var additive := 0.0
	var multiplicative := 1.0
	var enabled := 0.0
	var set_value := 0.0
	var found_add := false
	var found_multiply := false
	var found_enable := false
	var found_set := false
	var meta_table := SurvivorsContent.meta_upgrades()
	if meta_table != null:
		for definition: MetaUpgradeDef in meta_table.upgrades:
			if definition == null:
				continue
			var rank := GameState.get_meta_upgrade_rank(definition.id)
			if rank <= 0:
				continue
			for effect: ProgressionEffectDef in definition.effects:
				if effect == null or effect.kind != kind:
					continue
				var authored := effect.value_at_rank(rank)
				match effect.operation:
					ProgressionEffectDef.Operation.ADD:
						additive += authored
						found_add = true
					ProgressionEffectDef.Operation.MULTIPLY:
						multiplicative *= authored
						found_multiply = true
					ProgressionEffectDef.Operation.ENABLE:
						enabled = maxf(enabled, authored)
						found_enable = true
					ProgressionEffectDef.Operation.SET:
						set_value = authored
						found_set = true
	var power_table := SurvivorsContent.run_powers()
	if power_table != null:
		for power_id: StringName in _power_slot_order:
			var definition := power_table.by_id(power_id)
			var rank := get_run_power_rank(power_id)
			if definition == null or rank <= 0:
				continue
			for effect: ProgressionEffectDef in definition.effects:
				if effect == null or effect.kind != kind:
					continue
				var authored := effect.value_at_rank(rank)
				match effect.operation:
					ProgressionEffectDef.Operation.ADD:
						additive += authored
						found_add = true
					ProgressionEffectDef.Operation.MULTIPLY:
						multiplicative *= authored
						found_multiply = true
					ProgressionEffectDef.Operation.ENABLE:
						enabled = maxf(enabled, authored)
						found_enable = true
					ProgressionEffectDef.Operation.SET:
						set_value = authored
						found_set = true
	if found_set:
		return set_value
	if found_multiply:
		return multiplicative
	if found_enable:
		return enabled
	return additive if found_add else 0.0


func get_utility_charges() -> Dictionary:
	return {
		"rerolls": _rerolls_remaining,
		"banishes": _banishes_remaining,
	}


func _present_all_earned_level_choices() -> void:
	while not _earned_unpresented_levels.is_empty():
		var level: int = _earned_unpresented_levels.pop_front()
		_ready_level_choices.append(level)
	_open_next_level_offer()


func _open_next_level_offer() -> void:
	if not _current_offer.is_empty() or _ready_level_choices.is_empty():
		return
	var level: int = _ready_level_choices.pop_front()
	var slot_count := BASE_OFFER_CARD_COUNT
	var fourth_chance := clampf(GameState.get_meta_effect(
		ProgressionEffectDef.Kind.FOURTH_CARD_CHANCE), 0.0, 1.0)
	if fourth_chance > 0.0 and _rng.randf() < fourth_chance:
		slot_count = LUCK_OFFER_CARD_COUNT
	_current_offer = _build_level_offer(level, slot_count)
	if not _paused:
		_offer_paused_run = true
		pause_attempt()
	elif phase in [Phase.ACTIVE, Phase.OVERFLOW]:
		_offer_paused_run = true
	level_choice_changed.emit(get_current_offer())
	utility_charges_changed.emit(_rerolls_remaining, _banishes_remaining)
	attempt_snapshot_dirty.emit()


func _build_level_offer(level: int, requested_slots: int,
		excluded_ids: Array[StringName] = []) -> Dictionary:
	var eligible := _eligible_run_power_ids()
	if not excluded_ids.is_empty():
		var fresh: Array[StringName] = []
		for power_id: StringName in eligible:
			if power_id not in excluded_ids:
				fresh.append(power_id)
		if fresh.size() >= mini(requested_slots, eligible.size()):
			eligible = fresh
	var count := mini(requested_slots, eligible.size())
	var selected := _weighted_power_sample(eligible, count)
	var cards: Array[Dictionary] = []
	for power_id: StringName in selected:
		var definition := _run_power_definition(power_id)
		if definition == null:
			continue
		var current_rank := get_run_power_rank(power_id)
		cards.append({
			"id": String(power_id),
			"display_name": definition.display_name,
			"description": definition.description,
			"rarity": definition.rarity,
			"current_rank": current_rank,
			"next_rank": current_rank + 1,
			"rank_cap": definition.rank_cap,
			"icon_path": definition.icon_path,
		})
	if cards.is_empty():
		var offer_tuning := SurvivorsContent.run_offer_tuning()
		var cash := 1 if offer_tuning == null else offer_tuning.payday_amount(
			level, _payday_picks)
		cards.append({
			"id": String(PAYDAY_POWER_ID),
			"display_name": "Payday",
			"description": "Take an escalating session-cash payout.",
			"rarity": RunPowerDef.Rarity.COMMON,
			"current_rank": _payday_picks,
			"next_rank": _payday_picks + 1,
			"rank_cap": -1,
			"icon_path": "res://assets/ui/coin.png",
			"cash": cash,
		})
	_offer_serial += 1
	return {
		"offer_id": _offer_serial,
		"level": level,
		"slot_count": requested_slots,
		"cards": cards,
	}


func _eligible_run_power_ids() -> Array[StringName]:
	var eligible: Array[StringName] = []
	var slots_full := _power_slot_order.size() >= MAX_RUN_POWER_SLOTS
	for power_id: StringName in GameState.get_unlocked_run_powers():
		if _banned_power_ids.has(power_id):
			continue
		var definition := _run_power_definition(power_id)
		if definition == null or get_run_power_rank(power_id) >= definition.rank_cap:
			continue
		if slots_full and power_id not in _power_slot_order:
			continue
		eligible.append(power_id)
	eligible.sort()
	return eligible


func _weighted_power_sample(source: Array[StringName], count: int) -> Array[StringName]:
	var pool := source.duplicate()
	var out: Array[StringName] = []
	var offer_tuning := SurvivorsContent.run_offer_tuning()
	var rare_luck := maxf(1.0, GameState.get_meta_effect(
		ProgressionEffectDef.Kind.RARE_OFFER_WEIGHT))
	var epic_luck := maxf(1.0, GameState.get_meta_effect(
		ProgressionEffectDef.Kind.EPIC_OFFER_WEIGHT))
	while out.size() < count and not pool.is_empty():
		var weights := PackedFloat64Array()
		var total := 0.0
		for power_id: StringName in pool:
			var definition := _run_power_definition(power_id)
			var weight := 1.0 if offer_tuning == null \
				else offer_tuning.weight_for(definition.rarity)
			if definition.rarity == RunPowerDef.Rarity.RARE:
				weight *= rare_luck
			elif definition.rarity == RunPowerDef.Rarity.EPIC:
				weight *= epic_luck
			weight = maxf(0.0001, weight)
			weights.append(weight)
			total += weight
		var roll := _rng.randf() * total
		var picked := pool.size() - 1
		for index: int in range(pool.size()):
			roll -= weights[index]
			if roll <= 0.0:
				picked = index
				break
		out.append(pool[picked])
		pool.remove_at(picked)
	return out


func _offer_contains(power_id: StringName) -> bool:
	for card: Dictionary in _offer_cards():
		if StringName(card.get("id", "")) == power_id:
			return true
	return false


func _offer_cards() -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	var raw_cards: Variant = _current_offer.get("cards", [])
	if raw_cards is Array:
		for raw_card: Variant in raw_cards:
			if raw_card is Dictionary:
				cards.append((raw_card as Dictionary).duplicate(true))
	return cards


func _finish_level_offer_pause() -> void:
	level_choice_changed.emit({})
	if _offer_paused_run:
		_offer_paused_run = false
		resume_attempt()


func _run_power_definition(power_id: StringName) -> RunPowerDef:
	var table := SurvivorsContent.run_powers()
	return null if table == null else table.by_id(power_id)


func _level_choice_is_tracked(level: int) -> bool:
	if bool(_completed_level_choices.get(level, false)) \
			or level in _earned_unpresented_levels \
			or level in _ready_level_choices:
		return true
	return not _current_offer.is_empty() \
		and int(_current_offer.get("level", -1)) == level


func try_spend_cash(amount: int) -> bool:
	# Session cash is a settlement purse, never an in-run spending currency.
	return false


func purchase_permanent_upgrade(id: StringName) -> bool:
	return false


func permanent_upgrade_cost(id: StringName) -> int:
	return 0


func purchase_species(species_id: StringName) -> bool:
	return false


func current_batch_size() -> int:
	return int(tuning.earth_batch_sizes[0])


# ---------------------------------------------------------------- splitter
func purchase_splitter() -> bool:
	return false


func purchase_splitter_reliability() -> bool:
	return false


func splitter_chance() -> float:
	return clampf(tuning.splitter_base_chance
		+ float(_splitter_reliability_rank) * tuning.splitter_chance_per_rank, 0.0, 1.0)


func _resolve_splitter_cycle() -> void:
	if _arena == null or loose_log_count() <= 0 or _rng.randf() >= splitter_chance():
		return
	var descriptor: LogDescriptor = _arena.call("claim_highest_risk_for_splitter")
	if descriptor == null:
		return
	_splitter_rescues += 1
	if phase == Phase.ACTIVE:
		var cleared := mini(_earth_remaining, current_batch_size())
		_earth_remaining -= cleared
		earth_changed.emit(_earth_remaining, cleared)
	splitter_rescued.emit(descriptor.id)
	attempt_snapshot_dirty.emit()
	if _earth_remaining <= 0 and phase == Phase.ACTIVE:
		_enter_earth_clear()


# ---------------------------------------------------------------- powerups
func _roll_powerup_drop() -> void:
	if _rng.randf() >= tuning.powerup_drop_chance:
		return
	if _rng.randf() < tuning.slow_time_weight:
		if _slow_charges >= tuning.slow_time_charge_cap:
			return
		_slow_charges += 1
		powerup_dropped.emit(Powerup.SLOW_TIME)
	else:
		if _blaster_ammo >= tuning.blaster_ammo_cap:
			return
		_blaster_ammo = mini(tuning.blaster_ammo_cap,
			_blaster_ammo + tuning.blaster_ammo_per_drop)
		powerup_dropped.emit(Powerup.LOG_BLASTER)
	powerups_changed.emit(_slow_charges, _blaster_ammo, _slow_seconds_left)


func activate_slow_time() -> bool:
	if not is_gameplay_active() or _slow_charges <= 0 or _slow_seconds_left > 0.0:
		return false
	_slow_charges -= 1
	_slow_seconds_left = tuning.slow_time_duration
	powerups_changed.emit(_slow_charges, _blaster_ammo, _slow_seconds_left)
	attempt_snapshot_dirty.emit()
	return true


func fire_blaster(ray_origin: Vector3, ray_direction: Vector3) -> bool:
	if not is_gameplay_active() or _blaster_ammo <= 0 or _arena == null:
		return false
	if not bool(_arena.call("blast", ray_origin, ray_direction, tuning.blaster_impulse)):
		return false
	_blaster_ammo -= 1
	powerups_changed.emit(_slow_charges, _blaster_ammo, _slow_seconds_left)
	attempt_snapshot_dirty.emit()
	return true


func hazard_speed_multiplier() -> float:
	return tuning.slow_hazard_multiplier if _slow_seconds_left > 0.0 else 1.0


# ---------------------------------------------------------------- failure / victory
func _enter_earth_clear() -> void:
	_enter_stage_clear()


func _enter_stage_clear() -> void:
	if phase != Phase.ACTIVE:
		return
	_earth_clear_seconds = _elapsed_seconds
	phase = Phase.EARTH_CLEAR
	_paused = true
	_set_runtime_paused(true)
	phase_changed.emit(phase)
	pause_changed.emit(true)
	earth_cleared.emit(earth_clear_ms())
	stage_cleared.emit(earth_clear_ms())
	attempt_snapshot_dirty.emit()


func cash_out_stage() -> bool:
	if phase != Phase.EARTH_CLEAR or not _paused or _run_id == &"":
		return false
	_bank_receipt = _bank_current_run(true)
	if _bank_receipt.is_empty():
		settlement_failed.emit(
			"The run could not be banked safely. It remains paused and resumable.")
		attempt_snapshot_dirty.emit()
		return false
	phase = Phase.COMPLETE
	GameState.set_permanent_controls_locked(false)
	var results := results_snapshot()
	results["result_kind"] = "cash_out"
	phase_changed.emit(phase)
	pause_changed.emit(true)
	attempt_finished.emit(results)
	attempt_snapshot_dirty.emit()
	return true


func _bank_current_run(cleared: bool) -> Dictionary:
	return GameState.bank_run({
		"run_id": String(_run_id),
		"yard_id": String(GameState.get_selected_yard()),
		"session_cash": _cash,
		"cleared": cleared,
		"clear_ms": earth_clear_ms(),
		"stage_ms": mini(elapsed_ms(), int(round(stage_duration_seconds() * 1000.0))),
		"endless_ms": overflow_ms(),
		"level": get_level(),
		"pending_blueprints": 0,
		"bosses_defeated": 0,
	})


func _on_breach_expired(log_id: StringName) -> void:
	if not is_gameplay_active():
		return
	_paused = true
	var was_overflow := phase == Phase.OVERFLOW
	_set_runtime_paused(true)
	_bank_receipt = _bank_current_run(was_overflow and _earth_clear_seconds >= 0.0)
	if _bank_receipt.is_empty():
		pause_changed.emit(true)
		settlement_failed.emit(
			"The run could not be banked safely. It remains paused and resumable.")
		attempt_snapshot_dirty.emit()
		return
	phase = Phase.FAILED
	GameState.set_permanent_controls_locked(false)
	var results := results_snapshot(log_id)
	phase_changed.emit(phase)
	pause_changed.emit(true)
	attempt_finished.emit(results)
	attempt_snapshot_dirty.emit()


func results_snapshot(breached_log_id: StringName = &"") -> Dictionary:
	return {
		"phase": phase,
		"result_kind": "cash_out" if phase == Phase.COMPLETE else "failure",
		"breached_log_id": String(breached_log_id),
		"earth_remaining": _earth_remaining,
		"earth_clear_ms": earth_clear_ms(),
		"total_ms": elapsed_ms(),
		"stage_remaining_ms": stage_remaining_ms(),
		"overflow_ms": overflow_ms(),
		"manual_clears": _manual_clears,
		"splitter_rescues": _splitter_rescues,
		"peak_loose_logs": _peak_loose_logs,
		"cash_earned": _cash_earned,
		"cash_spent": _cash_spent,
		"permanent_purchases": _permanent_purchases,
		"run_id": String(_run_id),
		"session_cash": _cash,
		"xp": _xp,
		"level": get_level(),
		"power_slots": get_power_slots(),
		"power_ranks": get_run_power_ranks(),
		"bank_receipt": _bank_receipt.duplicate(true),
	}


# ---------------------------------------------------------------- arena receipts
func _on_loose_count_changed(count: int) -> void:
	_peak_loose_logs = maxi(_peak_loose_logs, count)
	loose_logs_changed.emit(count)


func _on_boundary_warning(log_id: StringName, seconds_left: float) -> void:
	boundary_warning_changed.emit(log_id, seconds_left)


func loose_log_count() -> int:
	return 0 if _arena == null else int(_arena.call("loose_log_count"))


# ---------------------------------------------------------------- queries / save
func get_cash() -> int:
	return _cash


func get_xp() -> int:
	return _xp


func get_level() -> int:
	return get_level_for_xp(_xp)


func get_level_for_xp(total_xp: int) -> int:
	var yard := _yard_definition()
	return 1 if yard == null else yard.level_for_xp(total_xp)


func get_level_progress_for_xp(total_xp: int) -> float:
	var yard := _yard_definition()
	return 0.0 if yard == null else yard.progress_for_xp(total_xp)


func get_xp_to_next_level_for_xp(total_xp: int) -> int:
	var yard := _yard_definition()
	return 1 if yard == null else yard.xp_remaining_for_xp(total_xp)


func get_run_id() -> StringName:
	return _run_id


func get_earth_remaining() -> int:
	return _earth_remaining


func elapsed_ms() -> int:
	return maxi(0, int(round(_elapsed_seconds * 1000.0)))


func stage_duration_seconds() -> float:
	var yard := _yard_definition()
	return maxf(1.0, yard.stage_duration_seconds) if yard != null else 1200.0


func stage_remaining_ms() -> int:
	if phase == Phase.OVERFLOW or _earth_clear_seconds >= 0.0:
		return 0
	return maxi(0, int(round(
		(stage_duration_seconds() - _elapsed_seconds) * 1000.0)))


func earth_clear_ms() -> int:
	return -1 if _earth_clear_seconds < 0.0 else int(round(_earth_clear_seconds * 1000.0))


func overflow_ms() -> int:
	return -1 if _earth_clear_seconds < 0.0 \
		else maxi(0, elapsed_ms() - earth_clear_ms())


func get_powerup_state() -> Dictionary:
	return {
		"slow_charges": _slow_charges,
		"blaster_ammo": _blaster_ammo,
		"slow_seconds_left": _slow_seconds_left,
	}


func get_splitter_state() -> Dictionary:
	return {
		"installed": _splitter_installed,
		"reliability_rank": _splitter_reliability_rank,
		"seconds_left": _splitter_seconds_left,
		"chance": splitter_chance(),
	}


func to_save_dict() -> Dictionary:
	if not has_live_attempt() and phase != Phase.SUSPENDED:
		return {}
	return {
		"schema_version": 1,
		"run_id": String(_run_id),
		"phase": phase,
		"cash": _cash,
		"xp": _xp,
		"level": get_level(),
		"xp_awarded_root_ids": _xp_awarded_root_ids.duplicate(true),
		"power_slot_order": get_power_slots(),
		"power_ranks": get_run_power_ranks(),
		"banned_power_ids": _banned_power_ids.duplicate(true),
		"rerolls_remaining": _rerolls_remaining,
		"banishes_remaining": _banishes_remaining,
		"earned_unpresented_levels": _earned_unpresented_levels.duplicate(),
		"ready_level_choices": _ready_level_choices.duplicate(),
		"completed_level_choices": _completed_level_choices.duplicate(true),
		"current_offer": _current_offer.duplicate(true),
		"offer_paused_run": _offer_paused_run,
		"offer_serial": _offer_serial,
		"payday_picks": _payday_picks,
		"pending_piece_cash": _pending_piece_cash.duplicate(),
		"earth_remaining": _earth_remaining,
		"elapsed_seconds": _elapsed_seconds,
		"earth_clear_seconds": _earth_clear_seconds,
		"delivery_seconds_left": _delivery_seconds_left,
		"delivery_tier": _delivery_tier,
		"slow_charges": _slow_charges,
		"blaster_ammo": _blaster_ammo,
		"slow_seconds_left": _slow_seconds_left,
		"splitter_installed": _splitter_installed,
		"splitter_reliability_rank": _splitter_reliability_rank,
		"splitter_seconds_left": _splitter_seconds_left,
		"spawn_serial": _spawn_serial,
		"rng_state": _rng.state,
		"waiting_for_active_log": _waiting_for_active_log,
		"active_log_id": String(_active_log_id),
		"boundary_timers_paused": _boundary_timers_paused,
		"manual_clears": _manual_clears,
		"splitter_rescues": _splitter_rescues,
		"peak_loose_logs": _peak_loose_logs,
		"cash_earned": _cash_earned,
		"cash_spent": _cash_spent,
		"permanent_purchases": _permanent_purchases,
		"arena": {} if _arena == null else _arena.call("to_save_dict"),
		"chopping": {} if _chopping == null else _chopping.call("to_run_save_dict"),
	}


func restore_attempt(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	_cancel_xp_presentations()
	_reset_attempt_state()
	var saved_phase := int(data.get("phase", Phase.ACTIVE))
	if saved_phase not in [Phase.ACTIVE, Phase.EARTH_CLEAR, Phase.OVERFLOW]:
		return false
	phase = saved_phase
	_paused = true
	_run_id = StringName(data.get("run_id", ""))
	if _run_id == &"":
		_run_id = _make_run_id(int(data.get("rng_state", 0)))
		if _run_id == &"":
			return false
	_cash = clampi(int(data.get("cash", 0)), 0, GameState.MAX_SAFE_ECONOMY_VALUE)
	_xp = clampi(int(data.get("xp", 0)), 0, GameState.MAX_SAFE_ECONOMY_VALUE)
	var saved_piece_cash: Variant = data.get("pending_piece_cash", [])
	if saved_piece_cash is Array:
		for raw_share: Variant in saved_piece_cash:
			if raw_share is int and int(raw_share) >= 0:
				_pending_piece_cash.append(int(raw_share))
	var saved_xp_roots: Variant = data.get("xp_awarded_root_ids", {})
	if saved_xp_roots is Dictionary:
		for raw_id: Variant in (saved_xp_roots as Dictionary):
			if raw_id is String or raw_id is StringName:
				var receipt_id := StringName(raw_id)
				if String(receipt_id).begins_with("%s::" % _run_id):
					_xp_awarded_root_ids[receipt_id] = true
	_restore_run_choice_state(data)
	_earth_remaining = clampi(int(data.get("earth_remaining", GameState.TOTAL_EARTH_TREES)),
		0, GameState.TOTAL_EARTH_TREES)
	_elapsed_seconds = maxf(0.0, float(data.get("elapsed_seconds", 0.0)))
	_earth_clear_seconds = float(data.get("earth_clear_seconds", -1.0))
	_delivery_seconds_left = maxf(0.0, float(data.get("delivery_seconds_left", delivery_interval())))
	_delivery_tier = clampi(int(data.get("delivery_tier", 0)), 0, max_delivery_tier())
	_slow_charges = clampi(int(data.get("slow_charges", 0)), 0, tuning.slow_time_charge_cap)
	_blaster_ammo = clampi(int(data.get("blaster_ammo", 0)), 0, tuning.blaster_ammo_cap)
	_slow_seconds_left = maxf(0.0, float(data.get("slow_seconds_left", 0.0)))
	_splitter_installed = bool(data.get("splitter_installed", false))
	_splitter_reliability_rank = clampi(int(data.get("splitter_reliability_rank", 0)),
		0, tuning.splitter_reliability_costs.size())
	_splitter_seconds_left = maxf(0.0, float(data.get("splitter_seconds_left", tuning.splitter_cycle_seconds)))
	_spawn_serial = maxi(0, int(data.get("spawn_serial", 0)))
	_rng.state = int(data.get("rng_state", 0))
	_waiting_for_active_log = bool(data.get("waiting_for_active_log", false))
	_active_log_id = StringName(data.get("active_log_id", ""))
	_boundary_timers_paused = bool(data.get("boundary_timers_paused", false))
	_manual_clears = maxi(0, int(data.get("manual_clears", 0)))
	_splitter_rescues = maxi(0, int(data.get("splitter_rescues", 0)))
	_peak_loose_logs = maxi(0, int(data.get("peak_loose_logs", 0)))
	_cash_earned = maxi(0, int(data.get("cash_earned", 0)))
	_cash_spent = maxi(0, int(data.get("cash_spent", 0)))
	_permanent_purchases = maxi(0, int(data.get("permanent_purchases", 0)))
	if _arena != null:
		_arena.call("restore_from_save", data.get("arena", {}))
		if _arena.has_method("set_boundary_timers_paused"):
			_arena.call("set_boundary_timers_paused", _boundary_timers_paused)
	if _chopping != null:
		_chopping.call("restore_run_save_dict", data.get("chopping", {}))
	_set_runtime_paused(true)
	GameState.set_permanent_controls_locked(true)
	if not _current_offer.is_empty():
		_offer_paused_run = true
	run_identity_changed.emit(_run_id)
	_emit_full_attempt_refresh()
	return true


func _set_runtime_paused(value: bool) -> void:
	if _arena != null:
		_arena.call("set_hazards_paused", value)
	if _chopping != null:
		_chopping.process_mode = Node.PROCESS_MODE_DISABLED if value \
			else Node.PROCESS_MODE_INHERIT


func _set_boundary_timers_paused(value: bool) -> void:
	_boundary_timers_paused = value
	if _arena != null and _arena.has_method("set_boundary_timers_paused"):
		_arena.call("set_boundary_timers_paused", value)


func _reset_attempt_state() -> void:
	phase = Phase.PREP
	_paused = true
	_cash = 0
	_xp = 0
	_run_id = &""
	_xp_awarded_root_ids.clear()
	_power_slot_order.clear()
	_power_ranks.clear()
	_banned_power_ids.clear()
	_rerolls_remaining = 0
	_banishes_remaining = 0
	_earned_unpresented_levels.clear()
	_ready_level_choices.clear()
	_completed_level_choices.clear()
	_current_offer.clear()
	_offer_paused_run = false
	_offer_serial = 0
	_payday_picks = 0
	_bank_receipt.clear()
	_pending_piece_cash.clear()
	_earth_remaining = GameState.TOTAL_EARTH_TREES
	_elapsed_seconds = 0.0
	_earth_clear_seconds = -1.0
	_delivery_seconds_left = 0.0
	_delivery_tier = 0
	_slow_charges = 0
	_blaster_ammo = 0
	_slow_seconds_left = 0.0
	_splitter_installed = false
	_splitter_reliability_rank = 0
	_splitter_seconds_left = 0.0
	_spawn_serial = 0
	_waiting_for_active_log = false
	_active_log_id = &""
	_boundary_timers_paused = false
	_manual_clears = 0
	_splitter_rescues = 0
	_peak_loose_logs = 0
	_cash_earned = 0
	_cash_spent = 0
	_permanent_purchases = 0


func _make_run_id(_seed: int) -> StringName:
	return GameState.issue_run_id()


func _root_xp_receipt_id(root_id: StringName) -> StringName:
	return StringName("%s::%s" % [_run_id, root_id])


func _cancel_xp_presentations() -> void:
	if _chopping == null:
		return
	if _chopping.has_method("cancel_reward_presentations"):
		_chopping.call("cancel_reward_presentations")
	elif _chopping.has_method("cancel_xp_presentations"):
		_chopping.call("cancel_xp_presentations")


func _emit_full_attempt_refresh() -> void:
	phase_changed.emit(phase)
	pause_changed.emit(_paused)
	cash_changed.emit(_cash)
	xp_changed.emit(_xp)
	level_choice_changed.emit(get_current_offer())
	power_slots_changed.emit(get_power_slots(), get_run_power_ranks())
	utility_charges_changed.emit(_rerolls_remaining, _banishes_remaining)
	earth_changed.emit(_earth_remaining, 0)
	run_clock_changed.emit(elapsed_ms())
	stage_time_changed.emit(stage_remaining_ms())
	delivery_changed.emit(_delivery_seconds_left, _delivery_tier)
	loose_logs_changed.emit(loose_log_count())
	powerups_changed.emit(_slow_charges, _blaster_ammo, _slow_seconds_left)
	splitter_changed.emit(_splitter_installed, _splitter_reliability_rank,
		_splitter_seconds_left)
	if phase == Phase.EARTH_CLEAR:
		stage_cleared.emit(earth_clear_ms())


func _yard_definition() -> YardDef:
	var yards := SurvivorsContent.yards()
	return null if yards == null else yards.by_id(GameState.get_selected_yard())


func _restore_run_choice_state(data: Dictionary) -> void:
	var saved_ranks: Variant = data.get("power_ranks", {})
	if saved_ranks is Dictionary:
		for raw_id: Variant in (saved_ranks as Dictionary):
			if not (raw_id is String or raw_id is StringName):
				continue
			var power_id := StringName(raw_id)
			var definition := _run_power_definition(power_id)
			var rank := int((saved_ranks as Dictionary)[raw_id])
			if definition != null and GameState.is_run_power_unlocked(power_id) \
					and rank > 0:
				_power_ranks[power_id] = clampi(rank, 1, definition.rank_cap)
	var saved_slots: Variant = data.get("power_slot_order", [])
	if saved_slots is Array:
		for raw_id: Variant in saved_slots:
			if _power_slot_order.size() >= MAX_RUN_POWER_SLOTS \
					or not (raw_id is String or raw_id is StringName):
				break
			var power_id := StringName(raw_id)
			if _power_ranks.has(power_id) and power_id not in _power_slot_order:
				_power_slot_order.append(power_id)
	# A rank without a stable slot is invalid disposable state.
	for raw_id: Variant in _power_ranks.keys():
		if StringName(raw_id) not in _power_slot_order:
			_power_ranks.erase(raw_id)
	var saved_bans: Variant = data.get("banned_power_ids", {})
	if saved_bans is Dictionary:
		for raw_id: Variant in (saved_bans as Dictionary):
			if (raw_id is String or raw_id is StringName) \
					and _run_power_definition(StringName(raw_id)) != null \
					and bool((saved_bans as Dictionary)[raw_id]):
				_banned_power_ids[StringName(raw_id)] = true
	var reroll_cap := maxi(0, int(round(GameState.get_meta_effect(
		ProgressionEffectDef.Kind.REROLL_CHARGES))))
	var banish_cap := maxi(0, int(round(GameState.get_meta_effect(
		ProgressionEffectDef.Kind.BANISH_CHARGES))))
	_rerolls_remaining = clampi(int(data.get("rerolls_remaining", reroll_cap)),
		0, reroll_cap)
	_banishes_remaining = clampi(int(data.get("banishes_remaining", banish_cap)),
		0, banish_cap)
	_completed_level_choices = _restore_level_set(
		data.get("completed_level_choices", {}))
	_earned_unpresented_levels = _restore_level_array(
		data.get("earned_unpresented_levels", []))
	_ready_level_choices = _restore_level_array(
		data.get("ready_level_choices", []))
	_current_offer = _restore_offer(data.get("current_offer", {}))
	_offer_paused_run = bool(data.get("offer_paused_run", false)) \
		or not _current_offer.is_empty()
	_offer_serial = maxi(int(data.get("offer_serial", 0)),
		int(_current_offer.get("offer_id", 0)))
	_payday_picks = maxi(0, int(data.get("payday_picks", 0)))


func _restore_level_set(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if raw is Dictionary:
		for raw_level: Variant in (raw as Dictionary):
			var level := int(raw_level)
			if level > 1 and level <= get_level() \
					and bool((raw as Dictionary)[raw_level]):
				out[level] = true
	return out


func _restore_level_array(raw: Variant) -> Array[int]:
	var out: Array[int] = []
	if raw is Array:
		for raw_level: Variant in raw:
			var level := int(raw_level)
			if level > 1 and level <= get_level() \
					and level not in out \
					and not bool(_completed_level_choices.get(level, false)):
				out.append(level)
	return out


func _restore_offer(raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		return {}
	var saved := raw as Dictionary
	var level := int(saved.get("level", -1))
	var raw_cards: Variant = saved.get("cards", [])
	if level <= 1 or level > get_level() or not (raw_cards is Array) \
			or (raw_cards as Array).is_empty():
		return {}
	var cards: Array[Dictionary] = []
	var ids: Dictionary = {}
	for raw_card: Variant in raw_cards:
		if not (raw_card is Dictionary):
			return {}
		var card := (raw_card as Dictionary).duplicate(true)
		var power_id := StringName(card.get("id", ""))
		if power_id == &"" or ids.has(power_id):
			return {}
		if power_id != PAYDAY_POWER_ID \
				and (not GameState.is_run_power_unlocked(power_id) \
				or _run_power_definition(power_id) == null):
			return {}
		if power_id == PAYDAY_POWER_ID and int(card.get("cash", 0)) <= 0:
			return {}
		ids[power_id] = true
		cards.append(card)
	return {
		"offer_id": maxi(1, int(saved.get("offer_id", 1))),
		"level": level,
		"slot_count": clampi(int(saved.get("slot_count", cards.size())),
			BASE_OFFER_CARD_COUNT, LUCK_OFFER_CARD_COUNT),
		"cards": cards,
	}
