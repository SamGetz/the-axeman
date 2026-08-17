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
signal run_power_runtime_changed(state: Dictionary)
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
signal boss_stack_changed(display_name: String, remaining_logs: int)
signal attempt_finished(results: Dictionary)
signal settlement_failed(message: String)
signal attempt_snapshot_dirty
signal active_log_requested(descriptor: LogDescriptor)

@export var tuning: SurvivalRunTuning

const MAX_RUN_POWER_SLOTS := 6
const BASE_OFFER_CARD_COUNT := 3
const LUCK_OFFER_CARD_COUNT := 4
const PAYDAY_POWER_ID := &"payday"
const _PERIODIC_INTERVAL_KINDS := {
	&"flying_wedge": ProgressionEffectDef.Kind.FLYING_WEDGE_INTERVAL,
	&"crosscut_sweep": ProgressionEffectDef.Kind.CROSSCUT_SWEEP_INTERVAL,
	&"maul_drop": ProgressionEffectDef.Kind.MAUL_DROP_INTERVAL,
	&"splitter_rig": ProgressionEffectDef.Kind.SPLITTER_RIG_INTERVAL,
	&"stump_pulse": ProgressionEffectDef.Kind.STUMP_PULSE_INTERVAL,
	&"sawblade_halo": ProgressionEffectDef.Kind.SAWBLADE_HALO_INTERVAL,
}
const _MAX_PERIODIC_TRIGGERS_PER_ADVANCE := 1024
const _RUNTIME_HUD_REFRESH_INTERVAL := 0.10

var phase: Phase = Phase.PREP
var _paused := true
var _cash := 0
var _xp := 0
var _run_id: StringName = &""
var _xp_awarded_root_ids: Dictionary = {}
var _power_slot_order: Array[StringName] = []
var _power_ranks: Dictionary = {}
var _power_pick_multipliers: Dictionary = {}
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
var _next_boss_schedule_index := 0
var _pending_boss_schedule_indices: Array[int] = []
## Bottom-to-top descriptors not yet promoted into the one cuttable top slot.
var _boss_stack_remaining: Array[LogDescriptor] = []
var _active_boss_id: StringName = &""
var _active_boss_name := ""
var _active_boss_tier := 0
var _bosses_defeated := 0
var _pending_blueprint_rolls: Array[int] = []
var _boundary_timers_paused := false
var _manual_clears := 0
var _splitter_rescues := 0
var _peak_loose_logs := 0
var _cash_earned := 0
var _cash_spent := 0
var _permanent_purchases := 0
var _pending_piece_cash: Array[int] = []
var _periodic_power_seconds_left: Dictionary = {}
var _run_power_trigger_counts: Dictionary = {}
var _rescue_charges_remaining := 0
var _rescue_charges_granted := 0
var _momentum_stacks := 0
var _orbiting_axe_contact_cooldowns: Dictionary = {}
var _automatic_completion_ids: Dictionary = {}
var _completion_power_queue: Array[Dictionary] = []
var _resolving_completion_powers := false
var _yard_magnet_cycle_seconds_left := 0.0
var _yard_magnet_pulse_seconds_left := 0.0
var _debug_forced_offer_quality := RunOfferTuning.Quality.INVALID
var _runtime_hud_refresh_elapsed := 0.0
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
	_refresh_run_power_environment(false)


func _process(delta: float) -> void:
	if _paused or phase not in [Phase.ACTIVE, Phase.OVERFLOW]:
		return
	_elapsed_seconds += delta
	if phase == Phase.ACTIVE:
		_queue_due_boss_encounters()
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
	var live_yard := _yard_definition()
	if _maximum_delivery_pressure_active(live_yard):
		# Entering the final pressure window must not inherit a slower remainder.
		# Both the interval and batch now come from the curves' rightmost points.
		_delivery_seconds_left = minf(_delivery_seconds_left,
			delivery_interval())
	_delivery_seconds_left -= hazard_delta
	while _delivery_seconds_left <= 0.0:
		_delivery_seconds_left += delivery_interval()
		if _spawn_delivery_batch() <= 0:
			break
	if _splitter_installed:
		_splitter_seconds_left -= hazard_delta
		if _splitter_seconds_left <= 0.0:
			_splitter_seconds_left += tuning.splitter_cycle_seconds
			_resolve_splitter_cycle()
	_advance_run_power_runtime(delta)
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
	var tier_count := yard.delivery_tier_interval_scales.size() \
		if yard != null else tuning.delivery_intervals.size()
	return clampi(GameState.get_max_frequency_tier(), 0,
		maxi(0, tier_count - 1))


func set_delivery_tier(tier: int) -> bool:
	# Starting frequency is selected at Home. A live attempt cannot alter it.
	return false


func delivery_interval() -> float:
	var yard := _yard_definition()
	return _delivery_interval_for_level(get_level(),
		_maximum_delivery_pressure_active(yard))


func _delivery_interval_for_level(level: int,
		force_curve_end := false) -> float:
	var yard := _yard_definition()
	if yard != null:
		return yard.delivery_interval_seconds(level, _delivery_tier,
			force_curve_end)
	var tier := clampi(_delivery_tier, 0, tuning.delivery_intervals.size() - 1)
	return float(tuning.delivery_intervals[tier])


## Both ordinary and maximum-pressure wave sizes come directly from the selected
## level's editable amount curve. No code derives counts from interval floors.
func delivery_batch_size(level: int = -1) -> int:
	var yard := _yard_definition()
	if yard == null:
		return 1
	var safe_level := get_level() if level <= 0 else maxi(1, level)
	return yard.delivery_batch_size(safe_level,
		_maximum_delivery_pressure_active(yard))


func _maximum_delivery_pressure_active(yard: YardDef = null) -> bool:
	var definition := yard if yard != null else _yard_definition()
	return definition != null and ((phase == Phase.OVERFLOW \
		and definition.force_curve_end_in_endless) \
		or (phase == Phase.ACTIVE and definition.force_curve_end_in_final_window \
			and stage_duration_seconds() - _elapsed_seconds \
			<= definition.final_pressure_remaining_seconds))


func _first_delivery_floor_level() -> int:
	var yard := _yard_definition()
	if yard == null:
		return 1
	for level: int in range(1, 1001):
		if yard.delivery_batch_size(level) > 1:
			return level
	return 1000


func _spawn_delivery_batch() -> int:
	var spawned := 0
	for _batch_index: int in range(delivery_batch_size()):
		# An empty block always receives the first due root directly. The loose-log
		# cap remains a renderer/physics guard for the remaining yard wave.
		if not _waiting_for_active_log and tuning.loose_log_soft_cap > 0 \
				and loose_log_count() >= tuning.loose_log_soft_cap:
			break
		_spawn_timed_log(false)
		spawned += 1
	if spawned > 0:
		attempt_snapshot_dirty.emit()
	return spawned


func _spawn_timed_log(mark_dirty: bool = true) -> void:
	var descriptor := _make_descriptor()
	# When completion has left the block waiting and the yard has no eligible
	# replacement, the due delivery is already the next workpiece. Send it
	# directly above the block instead of touching down in the yard first.
	if _waiting_for_active_log and _chopping != null:
		_waiting_for_active_log = false
		_active_log_id = descriptor.id
		active_log_requested.emit(descriptor)
		_chopping.call("stage_run_log", descriptor, false)
	elif _arena != null:
		_arena.call("spawn_loose_log", descriptor, _rng.randi())
	if mark_dirty:
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


## Boss schedules now resolve as five ordinary-hardness roots on the stump,
## never as one oversized descriptor. A due encounter waits for the current
## workpiece to finish, then takes block priority ahead of loose-yard claims.
func _queue_due_boss_encounters() -> void:
	var yard := _yard_definition()
	if yard == null:
		return
	while _next_boss_schedule_index < yard.bosses.size():
		var boss := yard.bosses[_next_boss_schedule_index]
		if boss == null:
			_next_boss_schedule_index += 1
			continue
		if _elapsed_seconds < boss.scheduled_seconds:
			break
		_pending_boss_schedule_indices.append(_next_boss_schedule_index)
		_next_boss_schedule_index += 1
	if _active_log_id == &"" and _waiting_for_active_log \
			and _active_boss_id == &"" \
			and not _pending_boss_schedule_indices.is_empty():
		_claim_next_active_log()


func _boss_schedule_index_after_elapsed(seconds: float) -> int:
	var yard := _yard_definition()
	if yard == null:
		return 0
	var index := 0
	while index < yard.bosses.size():
		var boss := yard.bosses[index]
		if boss != null and boss.scheduled_seconds > seconds:
			break
		index += 1
	return index


func _begin_pending_boss_stack() -> bool:
	if _chopping == null or _pending_boss_schedule_indices.is_empty():
		return false
	var yard := _yard_definition()
	if yard == null:
		return false
	var schedule_index: int = int(_pending_boss_schedule_indices.pop_front())
	if schedule_index < 0 or schedule_index >= yard.bosses.size():
		return false
	var boss := yard.bosses[schedule_index]
	if boss == null:
		return false
	var descriptors := _make_boss_stack_descriptors(boss, yard)
	if descriptors.size() != tuning.boss_stack_log_count:
		return false
	_boss_stack_remaining.assign(descriptors)
	var active := _boss_stack_remaining.pop_back() as LogDescriptor
	_active_boss_id = boss.id
	_active_boss_name = boss.display_name
	_active_boss_tier = boss.boss_tier
	_waiting_for_active_log = false
	_active_log_id = active.id
	active_log_requested.emit(active)
	_chopping.call("stage_boss_log_stack", descriptors)
	boss_stack_changed.emit(_active_boss_name,
		_boss_stack_remaining.size() + 1)
	attempt_snapshot_dirty.emit()
	return true


func _make_boss_stack_descriptors(boss: YardBossDef,
		yard: YardDef) -> Array[LogDescriptor]:
	var descriptors: Array[LogDescriptor] = []
	var count := tuning.boss_stack_log_count
	var species := SpeciesTable.by_id(boss.species_id)
	if species == null or species.meshes.is_empty() or count != 5:
		return descriptors
	# Preserve the authored one-boss jackpot exactly, but split it over five
	# ordinary roots. The old hardness/mass multipliers are intentionally unused:
	# the stack depth, not one damage sponge, is the encounter challenge.
	var cash_total := _scaled_reward_snapshot(
		boss.cash_jackpot, ProgressionEffectDef.Kind.SESSION_CASH_MULTIPLIER)
	var xp_total := _scaled_reward_snapshot(
		boss.xp_jackpot, ProgressionEffectDef.Kind.RUN_XP_MULTIPLIER)
	for stack_index: int in range(count):
		_spawn_serial += 1
		var descriptor := LogDescriptor.create(
			StringName("run_boss_%s_%d" % [boss.id, stack_index + 1]),
			boss.species_id,
			_rng.randi_range(0, species.meshes.size() - 1),
			_spawn_serial, _rng.randi())
		descriptor.run_id = _run_id
		descriptor.yard_id = yard.id
		descriptor.boss_id = boss.id
		descriptor.boss_tier = boss.boss_tier
		descriptor.hardness_snapshot = yard.hardness_multiplier(get_level())
		descriptor.cash_reward_snapshot = _boss_reward_share(
			cash_total, stack_index, count)
		descriptor.xp_reward_snapshot = _boss_reward_share(
			xp_total, stack_index, count)
		descriptors.append(descriptor)
	return descriptors


func _boss_reward_share(total: int, index: int, count: int) -> int:
	if total <= 0 or count <= 0 or index < 0 or index >= count:
		return 0
	return int(total / count) + (1 if index < total % count else 0)


func _scaled_reward_snapshot(base_amount: int,
		kind: ProgressionEffectDef.Kind) -> int:
	if base_amount <= 0:
		return 0
	if kind == ProgressionEffectDef.Kind.RUN_XP_MULTIPLIER:
		return _scaled_run_xp(base_amount)
	var multiplier := maxf(1.0, get_effect(kind))
	var scaled := float(base_amount) * multiplier
	if not is_finite(scaled) or scaled >= float(GameState.MAX_SAFE_ECONOMY_VALUE):
		return GameState.MAX_SAFE_ECONOMY_VALUE
	return clampi(maxi(base_amount, int(round(scaled))), 1,
		GameState.MAX_SAFE_ECONOMY_VALUE)


## One composition point for every disposable XP source. Root and boss rewards
## snapshot this final value when delivered; event bonuses use the same helper
## immediately before committing, so neither route can miss or double the boost.
func _scaled_run_xp(base_amount: int) -> int:
	if base_amount <= 0:
		return 0
	var global_multiplier := 1.0 if tuning == null else maxf(
		1.0, tuning.global_xp_gain_multiplier)
	var power_multiplier := maxf(1.0, get_effect(
		ProgressionEffectDef.Kind.RUN_XP_MULTIPLIER))
	var scaled := float(base_amount) * global_multiplier * power_multiplier
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
	if _active_boss_id != &"":
		if not _boss_stack_remaining.is_empty():
			var next_stack_log := _boss_stack_remaining.pop_back() as LogDescriptor
			_active_log_id = next_stack_log.id
			_waiting_for_active_log = false
			active_log_requested.emit(next_stack_log)
			if _chopping != null:
				_chopping.call("stage_next_boss_stack_log", next_stack_log)
			boss_stack_changed.emit(_active_boss_name,
				_boss_stack_remaining.size() + 1)
			attempt_snapshot_dirty.emit()
			return
		_finish_boss_stack()
	if _begin_pending_boss_stack():
		return
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


func _finish_boss_stack() -> void:
	if _active_boss_id == &"":
		return
	_bosses_defeated += 1
	_pending_blueprint_rolls.append(_rng.randi())
	_active_boss_id = &""
	_active_boss_name = ""
	_active_boss_tier = 0
	_boss_stack_remaining.clear()
	if _chopping != null and _chopping.has_method("end_boss_log_stack"):
		_chopping.call("end_boss_log_stack")
	boss_stack_changed.emit("", 0)
	attempt_snapshot_dirty.emit()


func get_boss_stack_state() -> Dictionary:
	return {
		"boss_id": String(_active_boss_id),
		"display_name": _active_boss_name,
		"tier": _active_boss_tier,
		"remaining_logs": _boss_stack_remaining.size() \
			+ (1 if _active_boss_id != &"" else 0),
		"pending_schedules": _pending_boss_schedule_indices.duplicate(),
		"bosses_defeated": _bosses_defeated,
		"pending_blueprints": _pending_blueprint_rolls.size(),
	}


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
	# Currency was committed atomically when the root completed. Finished-piece
	# settlement only validates inventory and attaches display shares to coins.
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
	return _commit_xp(_scaled_run_xp(base_amount))


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
	var offered_card := _offer_card_for(power_id)
	if offered_card.is_empty():
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
		if definition == null or not _run_power_has_effect_headroom(power_id):
			return false
		var current_rank := get_run_power_rank(power_id)
		if current_rank >= definition.rank_cap:
			return false
		var quality := int(offered_card.get("quality",
			RunOfferTuning.Quality.COMMON)) as RunOfferTuning.Quality
		var quality_multiplier := _quality_multiplier_for(quality)
		if quality_multiplier <= 0.0 \
				or not is_equal_approx(quality_multiplier, float(
				offered_card.get("quality_multiplier", 0.0))) \
				or not _quality_would_change_power(power_id, quality):
			return false
		if current_rank <= 0:
			if _power_slot_order.size() >= MAX_RUN_POWER_SLOTS:
				return false
			_power_slot_order.append(power_id)
		var next_rank := current_rank + 1
		var pick_multipliers := _pick_multipliers_for(power_id, current_rank)
		pick_multipliers.append(quality_multiplier)
		_power_pick_multipliers[power_id] = pick_multipliers
		_power_ranks[power_id] = next_rank
		_on_run_power_rank_changed(power_id, current_rank, next_rank, quality)
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


func get_run_power_pick_multipliers() -> Dictionary:
	var out: Dictionary = {}
	for power_id: StringName in _power_slot_order:
		out[String(power_id)] = _pick_multipliers_for(
			power_id, get_run_power_rank(power_id))
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
				var authored := definition.effect_value_for_pick_multipliers(
					kind, _pick_multipliers_for(power_id, rank))
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


## Chance authority for run powers. Callers keep geometry/debug forcing local,
## while this uses the attempt RNG that already round-trips in the save snapshot.
func roll_run_power_chance(power_id: StringName, chance: float) -> bool:
	if not is_gameplay_active() or get_run_power_rank(power_id) <= 0 \
			or chance <= 0.0:
		return false
	if chance >= 1.0:
		return true
	var fired := _rng.randf() < clampf(chance, 0.0, 1.0)
	attempt_snapshot_dirty.emit()
	return fired


func on_manual_strike_resolved(did_split: bool, world_position: Vector3,
		sequence_cuts: int = 1) -> Dictionary:
	var receipt: Dictionary = {}
	if phase not in [Phase.ACTIVE, Phase.OVERFLOW]:
		return receipt
	var changed := false
	var momentum_rank := get_run_power_rank(&"momentum")
	if momentum_rank > 0:
		var max_stacks := maxi(0, int(round(get_effect(
			ProgressionEffectDef.Kind.MOMENTUM_MAX_STACKS))))
		var next_stacks := mini(max_stacks, _momentum_stacks + 1) \
			if did_split else 0
		if next_stacks != _momentum_stacks:
			_momentum_stacks = next_stacks
			changed = true
		receipt["momentum_stacks"] = _momentum_stacks
	elif _momentum_stacks != 0:
		_momentum_stacks = 0
		changed = true

	if did_split and get_run_power_rank(&"cant_hook") > 0 \
			and _arena != null and _arena.has_method("pull_highest_risk"):
		var tug: Dictionary = _arena.call("pull_highest_risk", &"cant_hook",
			get_effect(ProgressionEffectDef.Kind.CANT_HOOK_FORCE))
		if not tug.is_empty():
			receipt["cant_hook"] = tug
			_note_run_power_trigger(&"cant_hook", world_position, 1)
			changed = true

	if get_run_power_rank(&"earthshaker") > 0:
		var threshold := maxi(1, int(round(get_effect(
			ProgressionEffectDef.Kind.EARTHSHAKER_TRIGGER_CUTS))))
		if sequence_cuts >= threshold and _arena != null:
			var radius := scale_power_area(get_effect(
				ProgressionEffectDef.Kind.EARTHSHAKER_RADIUS))
			var cuts: Array = []
			var pulse: Array = []
			if _arena.has_method("cut_all_in_radius"):
				cuts = _arena.call("cut_all_in_radius", &"earthshaker",
					world_position, radius)
			if _arena.has_method("apply_inward_pulse"):
				pulse = _arena.call("apply_inward_pulse", &"earthshaker",
					world_position, radius, get_effect(
					ProgressionEffectDef.Kind.EARTHSHAKER_INWARD_FORCE))
			if not cuts.is_empty() or not pulse.is_empty():
				receipt["earthshaker"] = {"cuts": cuts, "pulse": pulse}
				_note_run_power_trigger(&"earthshaker", world_position,
					maxi(cuts.size(), pulse.size()))
				changed = true
	if changed:
		_emit_run_power_runtime_refresh(true)
	return receipt


func on_root_completed(descriptor: LogDescriptor,
		world_position: Vector3) -> Dictionary:
	if descriptor == null or phase not in [Phase.ACTIVE, Phase.OVERFLOW] \
			or _arena == null:
		return {}
	_completion_power_queue.append({
		"descriptor": descriptor,
		"world_position": world_position,
	})
	# Timber Burst can now finish another root, which legitimately fires another
	# completion burst. Drain those follow-on events iteratively so a crowded
	# late-run yard cannot turn a long chain reaction into deep call recursion.
	if _resolving_completion_powers:
		return {}
	_resolving_completion_powers = true
	var first_receipt: Dictionary = {}
	var is_first := true
	while not _completion_power_queue.is_empty():
		var event := _completion_power_queue.pop_front() as Dictionary
		var event_receipt := _resolve_root_completion_powers(
			event.get("descriptor") as LogDescriptor,
			event.get("world_position", Vector3.ZERO))
		if is_first:
			first_receipt = event_receipt
			is_first = false
	_resolving_completion_powers = false
	return first_receipt


func _resolve_root_completion_powers(descriptor: LogDescriptor,
		world_position: Vector3) -> Dictionary:
	var receipt: Dictionary = {}
	if descriptor == null or phase not in [Phase.ACTIVE, Phase.OVERFLOW] \
			or _arena == null:
		return receipt
	var changed := false
	if get_run_power_rank(&"powder_keg") > 0:
		var radius := scale_power_area(get_effect(
			ProgressionEffectDef.Kind.POWDER_KEG_RADIUS))
		var cuts: Array = []
		var pulse: Array = []
		if _arena.has_method("queue_power_cuts"):
			cuts = _arena.call("queue_power_cuts", &"powder_keg", maxi(0,
				int(round(get_effect(ProgressionEffectDef.Kind.POWDER_KEG_CUT_COUNT)))),
				world_position, radius, &"nearest", [])
		if _arena.has_method("apply_inward_pulse"):
			pulse = _arena.call("apply_inward_pulse", &"powder_keg",
				world_position, radius, get_effect(
				ProgressionEffectDef.Kind.POWDER_KEG_INWARD_FORCE))
		if not cuts.is_empty() or not pulse.is_empty():
			receipt["powder_keg"] = {"cuts": cuts, "pulse": pulse}
			_note_run_power_trigger(&"powder_keg", world_position,
				maxi(1, _cut_receipt_count(cuts)))
			changed = true
	if get_run_power_rank(&"kindling_chain") > 0 \
			and _arena.has_method("queue_power_cuts"):
		var chain: Array = _arena.call("queue_power_cuts", &"kindling_chain",
			maxi(0, int(round(get_effect(
				ProgressionEffectDef.Kind.KINDLING_CHAIN_COUNT)))), world_position,
			scale_power_area(get_effect(
				ProgressionEffectDef.Kind.KINDLING_CHAIN_RANGE)),
			&"endangered_spread", [])
		if not chain.is_empty():
			receipt["kindling_chain"] = chain
			_note_run_power_trigger(&"kindling_chain", world_position,
				_cut_receipt_count(chain))
			changed = true
	if get_run_power_rank(&"timber_burst") > 0 \
			and _arena.has_method("cut_all_in_radius"):
		var timber_radius := scale_power_area(get_effect(
			ProgressionEffectDef.Kind.TIMBER_BURST_RADIUS))
		var burst_cuts: Array = _arena.call("cut_all_in_radius", &"timber_burst",
			world_position, timber_radius)
		if not burst_cuts.is_empty():
			receipt["timber_burst"] = burst_cuts
			_note_run_power_trigger(&"timber_burst", world_position,
				_cut_receipt_count(burst_cuts))
			changed = true
	if changed:
		_emit_run_power_runtime_refresh(true)
	return receipt


## Compatibility seam for older probes. Completion powers are intentionally
## source-neutral: manual and automatic root completions share the same bounded
## Powder Keg / Kindling Chain behavior promised by their catalogue copy.
func on_manual_root_completed(descriptor: LogDescriptor,
		world_position: Vector3) -> Dictionary:
	return on_root_completed(descriptor, world_position)


func trigger_splinter_volley(world_position: Vector3) -> Array[Dictionary]:
	if get_run_power_rank(&"splinter_volley") <= 0 or _arena == null \
			or not _arena.has_method("queue_power_cuts"):
		return []
	var split_count := maxi(0, int(round(get_effect(
		ProgressionEffectDef.Kind.SPLINTER_COUNT))))
	if split_count <= 0:
		return []
	var receipts: Array[Dictionary] = _arena.call("queue_power_cuts",
		&"splinter_volley", split_count, world_position, INF,
		&"nearest_single", [])
	if not receipts.is_empty():
		var applied := _cut_receipt_count(receipts)
		var target_position := _first_cut_receipt_position(receipts,
			world_position)
		_run_power_trigger_counts[&"splinter_volley"] = maxi(0, int(
			_run_power_trigger_counts.get(&"splinter_volley", 0))) + 1
		if _chopping != null and _chopping.has_method(
				"present_splinter_volley"):
			_chopping.call("present_splinter_volley", world_position,
				target_position, applied)
		else:
			_present_run_power_trigger(&"splinter_volley", target_position,
				applied)
		_emit_run_power_runtime_refresh(true)
	return receipts


## Lets an on-block guaranteed cut spill unused work to loose roots without
## letting chopping reach through to arena internals. The originating caller
## owns the single trigger receipt/presentation, so this applies immediate real
## cuts to the selected loose-root descendants without duplicating the burst.
func queue_run_power_cuts(power_id: StringName, count: int,
		world_position: Vector3 = Vector3.ZERO,
		mode: StringName = &"endangered") -> int:
	if count <= 0 or get_run_power_rank(power_id) <= 0 \
			or phase not in [Phase.ACTIVE, Phase.OVERFLOW]:
		return 0
	return _queue_arena_cut_count(power_id, count, world_position, INF, mode)


## Exact-once normal-root payout when a run power makes the completing cut on the
## active block. It deliberately does not increment manual-completion records.
func complete_automatic_active_log(descriptor: LogDescriptor, piece_count: int,
		power_id: StringName) -> Dictionary:
	if descriptor == null or descriptor.id != _active_log_id:
		return {}
	var receipt := _complete_automatic_descriptor(descriptor, power_id,
		maxi(0, piece_count))
	if receipt.is_empty():
		return {}
	_active_log_id = &""
	_set_boundary_timers_paused(true)
	receipt["piece_count"] = maxi(0, piece_count)
	attempt_snapshot_dirty.emit()
	return receipt


## Exact-once completion for a root whose final real descendant was cut in the
## loose yard. It receives the same snapshotted cash/XP and completion chains as
## an automatic block finish, without impersonating a manual chop record.
func complete_off_block_log(descriptor: LogDescriptor, piece_count: int,
		power_id: StringName, world_position: Vector3) -> Dictionary:
	var receipt := _complete_automatic_descriptor(descriptor, power_id)
	if receipt.is_empty():
		return {}
	receipt["piece_count"] = maxi(0, piece_count)
	receipt["off_block"] = true
	on_root_completed(descriptor, world_position)
	attempt_snapshot_dirty.emit()
	return receipt


## Acceptance seam only. It never changes permanent Blueprint ownership or the
## production offer pool; rank zero removes the temporary test power again.
func debug_set_run_power_rank(power_id: StringName, rank: int) -> bool:
	var definition := _run_power_definition(power_id)
	if definition == null or rank < 0 or rank > definition.rank_cap:
		return false
	var current_rank := get_run_power_rank(power_id)
	if rank == current_rank:
		return true
	if rank > 0 and current_rank <= 0:
		if _power_slot_order.size() >= MAX_RUN_POWER_SLOTS:
			return false
		_power_slot_order.append(power_id)
	if rank <= 0:
		_power_ranks.erase(power_id)
		_power_slot_order.erase(power_id)
		_power_pick_multipliers.erase(power_id)
	else:
		_power_ranks[power_id] = rank
		_power_pick_multipliers[power_id] = _pick_multipliers_for(power_id, rank)
	_on_run_power_rank_changed(power_id, current_rank, rank)
	power_slots_changed.emit(get_power_slots(), get_run_power_ranks())
	attempt_snapshot_dirty.emit()
	return true


## Acceptance-only quality forcing. It affects every non-Payday card in the
## next generated offer, then clears itself; production rolls remain saved-RNG.
func debug_force_next_offer_quality(quality: RunOfferTuning.Quality) -> bool:
	if quality < RunOfferTuning.Quality.COMMON \
			or quality > RunOfferTuning.Quality.LEGENDARY:
		return false
	_debug_forced_offer_quality = quality
	return true


func debug_advance_run_power_time(seconds: float) -> void:
	if seconds <= 0.0 or not is_gameplay_active():
		return
	_advance_run_power_runtime(seconds)


## Public bookkeeping seam for event-driven effects whose physical work is
## resolved by ChoppingMinigame. Presentation can be skipped when that caller
## already spawned feedback at the exact cut point.
func record_run_power_trigger(power_id: StringName, world_position: Vector3,
		amount: int = 1, present_feedback: bool = false) -> bool:
	if phase not in [Phase.ACTIVE, Phase.OVERFLOW] \
			or get_run_power_rank(power_id) <= 0 or amount <= 0:
		return false
	_run_power_trigger_counts[power_id] = maxi(0, int(
		_run_power_trigger_counts.get(power_id, 0))) + 1
	if present_feedback:
		_present_run_power_trigger(power_id, world_position, amount)
	_emit_run_power_runtime_refresh(true)
	return true


func get_run_power_runtime_state() -> Dictionary:
	var momentum_max := maxi(0, int(round(get_effect(
		ProgressionEffectDef.Kind.MOMENTUM_MAX_STACKS))))
	var arena_state: Dictionary = {}
	if _arena != null and _arena.has_method("get_run_power_runtime_state"):
		arena_state = _arena.call("get_run_power_runtime_state")
	var periodic := _string_keyed_runtime(_periodic_power_seconds_left)
	return {
		"periodic_seconds_left": periodic,
		"timers": periodic.duplicate(true),
		"trigger_counts": _string_keyed_runtime(_run_power_trigger_counts),
		"rescue_charges_remaining": _rescue_charges_remaining,
		"rescue_charges": _rescue_charges_remaining,
		"rescue_charges_granted": _rescue_charges_granted,
		"momentum_stacks": _momentum_stacks,
		"momentum_max_stacks": momentum_max,
		"momentum_speed_bonus": float(_momentum_stacks) * get_effect(
			ProgressionEffectDef.Kind.MOMENTUM_SPEED_PER_STACK),
		"momentum_reliability_bonus": float(_momentum_stacks) * get_effect(
			ProgressionEffectDef.Kind.MOMENTUM_RELIABILITY_PER_STACK),
		"orbit_contact_cooldowns": _string_keyed_runtime(
			_orbiting_axe_contact_cooldowns),
		"effective_boundary_radius": _effective_boundary_radius(),
		"effective_boundary_grace": _effective_boundary_grace(),
		"arrival_lateral_multiplier": _arrival_multiplier(
			ProgressionEffectDef.Kind.ARRIVAL_LATERAL_MULTIPLIER),
		"arrival_bounce_multiplier": _arrival_multiplier(
			ProgressionEffectDef.Kind.ARRIVAL_BOUNCE_MULTIPLIER),
		"arrival_outward_multiplier": _arrival_multiplier(
			ProgressionEffectDef.Kind.ARRIVAL_OUTWARD_MULTIPLIER),
		"yard_magnet_force": get_effect(ProgressionEffectDef.Kind.YARD_MAGNET_FORCE),
		"yard_magnet_interval": _yard_magnet_interval(),
		"yard_magnet_cycle_seconds_left": _yard_magnet_cycle_seconds_left,
		"yard_magnet_pulse_seconds_left": _yard_magnet_pulse_seconds_left,
		"yard_magnet_active": _yard_magnet_pulse_seconds_left > 0.0,
		"area_size_multiplier": get_area_size_multiplier(),
		"power_ranks": get_run_power_ranks(),
		"pick_multipliers": get_run_power_pick_multipliers(),
		"power_pick_multipliers": get_run_power_pick_multipliers(),
		"arena": arena_state,
	}


## Lightweight presentation state. Full arena/body snapshots remain available
## to save/debug callers but are not copied through the HUD signal on timer ticks.
func get_run_power_hud_state() -> Dictionary:
	var periodic := _string_keyed_runtime(_periodic_power_seconds_left)
	return {
		"periodic_seconds_left": periodic,
		"timers": periodic.duplicate(true),
		"trigger_counts": _string_keyed_runtime(_run_power_trigger_counts),
		"rescue_charges_remaining": _rescue_charges_remaining,
		"rescue_charges": _rescue_charges_remaining,
		"momentum_stacks": _momentum_stacks,
		"yard_magnet_interval": _yard_magnet_interval(),
		"yard_magnet_cycle_seconds_left": _yard_magnet_cycle_seconds_left,
		"yard_magnet_pulse_seconds_left": _yard_magnet_pulse_seconds_left,
		"yard_magnet_active": _yard_magnet_pulse_seconds_left > 0.0,
		"pick_multipliers": get_run_power_pick_multipliers(),
		"power_pick_multipliers": get_run_power_pick_multipliers(),
	}


func _on_run_power_rank_changed(power_id: StringName, previous_rank: int,
		next_rank: int,
		acquisition_quality: int = RunOfferTuning.Quality.COMMON) -> void:
	if _PERIODIC_INTERVAL_KINDS.has(power_id):
		if next_rank <= 0:
			_periodic_power_seconds_left.erase(power_id)
		else:
			var interval := _periodic_interval(power_id)
			var previous_left := float(_periodic_power_seconds_left.get(
				power_id, interval))
			_periodic_power_seconds_left[power_id] = interval \
				if previous_rank <= 0 else minf(previous_left, interval)
	if power_id == &"last_ditch_rescue":
		var previous_cap := _rescue_charges_granted
		var next_cap := maxi(0, int(round(get_effect(
			ProgressionEffectDef.Kind.RESCUE_CHARGES)))) if next_rank > 0 else 0
		if next_cap > previous_cap:
			_rescue_charges_remaining += next_cap - previous_cap
		_rescue_charges_granted = next_cap
		_rescue_charges_remaining = clampi(_rescue_charges_remaining, 0, next_cap)
	if power_id == &"momentum":
		if next_rank <= 0:
			_momentum_stacks = 0
		else:
			_momentum_stacks = mini(_momentum_stacks, maxi(0, int(round(
				get_effect(ProgressionEffectDef.Kind.MOMENTUM_MAX_STACKS)))))
	if power_id == &"whirling_axe" and next_rank <= 0:
		_orbiting_axe_contact_cooldowns.clear()
	if power_id == &"yard_magnet":
		if next_rank <= 0:
			_yard_magnet_cycle_seconds_left = 0.0
			_yard_magnet_pulse_seconds_left = 0.0
			_sync_yard_magnet_force(0.0)
		else:
			var interval := _yard_magnet_interval()
			if previous_rank <= 0:
				# Acquisition has an immediate readable pulse, then follows the
				# authored cadence instead of feeling inert for five seconds.
				_yard_magnet_cycle_seconds_left = interval
				_yard_magnet_pulse_seconds_left = \
					tuning.yard_magnet_pulse_duration_seconds
			else:
				_yard_magnet_cycle_seconds_left = minf(
					_yard_magnet_cycle_seconds_left, interval)
			_sync_yard_magnet_force(get_effect(
				ProgressionEffectDef.Kind.YARD_MAGNET_FORCE) \
				if _yard_magnet_pulse_seconds_left > 0.0 else 0.0)
	_refresh_run_power_environment(false)
	if _chopping != null and _chopping.has_method("refresh_run_power_visuals"):
		_chopping.call("refresh_run_power_visuals")
	if next_rank > previous_rank:
		_present_run_power_acquisition(power_id, Vector3(0.0, 0.8, 0.0),
			next_rank, acquisition_quality)
	_emit_run_power_runtime_refresh(false)


func _advance_run_power_runtime(seconds: float) -> void:
	if seconds <= 0.0 or phase not in [Phase.ACTIVE, Phase.OVERFLOW] or _paused:
		return
	var runtime_moved := false
	var triggered := false
	var became_ready := false
	runtime_moved = _advance_yard_magnet_runtime(seconds) or runtime_moved
	triggered = _advance_orbiting_axes(seconds) or triggered
	for raw_id: Variant in _PERIODIC_INTERVAL_KINDS:
		var power_id := StringName(raw_id)
		if get_run_power_rank(power_id) <= 0:
			_periodic_power_seconds_left.erase(power_id)
			continue
		var interval := _periodic_interval(power_id)
		if interval <= 0.0:
			continue
		var previous_left := float(_periodic_power_seconds_left.get(
			power_id, interval))
		var left := previous_left - seconds
		var fired := 0
		while left <= 0.0 and fired < _MAX_PERIODIC_TRIGGERS_PER_ADVANCE:
			if not _trigger_periodic_power(power_id):
				# Keep the proc ready. A block transition/no-target frame must not
				# silently consume a rank-one automatic power.
				left = 0.0
				break
			left += interval
			fired += 1
			triggered = true
		_periodic_power_seconds_left[power_id] = left
		runtime_moved = runtime_moved or not is_equal_approx(left, previous_left)
		became_ready = became_ready or (previous_left > 0.05 and left <= 0.05)
	runtime_moved = runtime_moved or triggered
	if runtime_moved:
		_runtime_hud_refresh_elapsed += seconds
		# Timer-only status is presentation, so ten updates per second is both
		# readable and enough. Real procs remain immediate and snapshot-dirty.
		if triggered or became_ready \
				or _runtime_hud_refresh_elapsed >= _RUNTIME_HUD_REFRESH_INTERVAL:
			_emit_run_power_runtime_refresh(triggered)


func _yard_magnet_interval() -> float:
	if get_run_power_rank(&"yard_magnet") <= 0:
		return 0.0
	return maxf(0.001, get_effect(
		ProgressionEffectDef.Kind.YARD_MAGNET_PULSE_INTERVAL))


func _advance_yard_magnet_runtime(seconds: float) -> bool:
	var interval := _yard_magnet_interval()
	if interval <= 0.0:
		var had_state := _yard_magnet_cycle_seconds_left > 0.0 \
			or _yard_magnet_pulse_seconds_left > 0.0
		_yard_magnet_cycle_seconds_left = 0.0
		_yard_magnet_pulse_seconds_left = 0.0
		_sync_yard_magnet_force(0.0)
		return had_state
	var previous_cycle := _yard_magnet_cycle_seconds_left
	var previous_pulse := _yard_magnet_pulse_seconds_left
	if _yard_magnet_cycle_seconds_left <= 0.0:
		_yard_magnet_cycle_seconds_left = interval
	if _yard_magnet_pulse_seconds_left > 0.0:
		_yard_magnet_pulse_seconds_left = maxf(0.0,
			_yard_magnet_pulse_seconds_left - seconds)
	_yard_magnet_cycle_seconds_left -= seconds
	while _yard_magnet_cycle_seconds_left <= 0.0:
		var overshoot := -_yard_magnet_cycle_seconds_left
		_yard_magnet_cycle_seconds_left += interval
		_yard_magnet_pulse_seconds_left = maxf(0.0,
			tuning.yard_magnet_pulse_duration_seconds - overshoot)
	_sync_yard_magnet_force(get_effect(
		ProgressionEffectDef.Kind.YARD_MAGNET_FORCE) \
		if _yard_magnet_pulse_seconds_left > 0.0 else 0.0, seconds)
	return not is_equal_approx(previous_cycle,
		_yard_magnet_cycle_seconds_left) \
		or not is_equal_approx(previous_pulse,
			_yard_magnet_pulse_seconds_left)


func _sync_yard_magnet_force(force: float, seconds: float = 0.0) -> int:
	if _arena == null or not _arena.has_method("apply_yard_magnet"):
		return 0
	return int(_arena.call("apply_yard_magnet", maxf(0.0, force),
		maxf(0.000001, seconds)))


func _trigger_periodic_power(power_id: StringName) -> bool:
	var applied := 0
	var presentation_position := Vector3(0.0, 0.8, 0.0)
	match power_id:
		&"flying_wedge":
			var cuts := maxi(0, int(round(get_effect(
				ProgressionEffectDef.Kind.FLYING_WEDGE_CUT_COUNT))))
			# "Nearest failure" is a loose-root hazard rule. Only fall back to
			# the active block when no endangered loose root can receive the cut.
			var receipts := _queue_arena_cut_receipts(power_id, cuts,
				Vector3.ZERO, INF, &"endangered")
			applied = _cut_receipt_count(receipts)
			presentation_position = _first_cut_receipt_position(
				receipts, presentation_position)
			if applied <= 0:
				applied = _apply_chopping_power_cuts(power_id, cuts, &"endangered")
		&"crosscut_sweep":
			applied = _complete_chopping_power_log(power_id, &"sweep")
			if _arena != null and _arena.has_method("crosscut_sweep"):
				var axis := int(_run_power_trigger_counts.get(power_id, 0)) % 2
				var receipts: Array = _arena.call("crosscut_sweep", power_id,
					scale_power_area(get_effect(
						ProgressionEffectDef.Kind.CROSSCUT_SWEEP_WIDTH)), axis)
				applied += _cut_receipt_count(receipts)
		&"maul_drop":
			var cuts := maxi(0, int(round(get_effect(
				ProgressionEffectDef.Kind.MAUL_DROP_CUT_COUNT))))
			# Boss/hardness ordering lives on loose descriptors; the block is a
			# fallback so a normal active root cannot mask a waiting boss.
			var receipts := _queue_arena_cut_receipts(power_id, cuts,
				Vector3.ZERO, INF, &"hardest")
			applied = _cut_receipt_count(receipts)
			presentation_position = _first_cut_receipt_position(
				receipts, presentation_position)
			if applied <= 0:
				applied = _apply_chopping_power_cuts(power_id, cuts, &"hardest")
		&"splitter_rig":
			if _arena != null and _arena.has_method(
					"claim_endangered_non_boss_for_splitter"):
				var descriptor: LogDescriptor = _arena.call(
					"claim_endangered_non_boss_for_splitter")
				if descriptor != null:
					if descriptor.has_transfer_pose():
						presentation_position = descriptor.transfer_from
					if not _complete_automatic_descriptor(
							descriptor, power_id).is_empty():
						applied = 1
						on_root_completed(descriptor, presentation_position)
		&"stump_pulse":
			if _arena != null and _arena.has_method("apply_inward_pulse"):
				var pulse: Array = _arena.call("apply_inward_pulse", power_id,
					Vector3.ZERO, scale_power_area(_effective_boundary_radius()), get_effect(
						ProgressionEffectDef.Kind.STUMP_PULSE_FORCE))
				applied = pulse.size()
		&"sawblade_halo":
			if _arena != null and _arena.has_method("cut_all_in_radius"):
				var radius := scale_power_area(get_effect(
					ProgressionEffectDef.Kind.SAWBLADE_HALO_RADIUS))
				var receipts: Array = _arena.call("cut_all_in_radius", power_id,
					Vector3.ZERO, radius)
				applied = _cut_receipt_count(receipts)
	if applied <= 0:
		return false
	_note_run_power_trigger(power_id, presentation_position, applied)
	return true


func _advance_orbiting_axes(seconds: float) -> bool:
	for raw_id: Variant in _orbiting_axe_contact_cooldowns.keys():
		var left := maxf(0.0, float(_orbiting_axe_contact_cooldowns[raw_id]) - seconds)
		if is_zero_approx(left):
			_orbiting_axe_contact_cooldowns.erase(raw_id)
		else:
			_orbiting_axe_contact_cooldowns[raw_id] = left
	if get_run_power_rank(&"whirling_axe") <= 0 or _arena == null \
			or not _arena.has_method("queue_orbiting_axe_contacts"):
		return false
	var geometry := _orbiting_axe_contact_geometry()
	if geometry.is_empty():
		return false
	var cooldown := maxf(0.001, get_effect(
		ProgressionEffectDef.Kind.ORBITING_AXE_CONTACT_COOLDOWN))
	var contacts := 0
	var excluded: Array = []
	for raw_id: Variant in _orbiting_axe_contact_cooldowns:
		if float(_orbiting_axe_contact_cooldowns.get(raw_id, 0.0)) > 0.0:
			excluded.append(StringName(raw_id))
	var receipts: Array = _arena.call("queue_orbiting_axe_contacts",
		&"whirling_axe", geometry.get("axes", []), excluded)
	for raw_receipt: Variant in receipts:
		if not (raw_receipt is Dictionary):
			continue
		var hit_id := StringName((raw_receipt as Dictionary).get("log_id", ""))
		if hit_id == &"":
			continue
		_orbiting_axe_contact_cooldowns[hit_id] = cooldown
		contacts += 1
	if contacts > 0:
		_note_run_power_trigger(&"whirling_axe",
			geometry.get("centre", Vector3.ZERO), contacts)
		return true
	return false


func _orbiting_axe_contact_geometry() -> Dictionary:
	if not (_chopping is Node3D):
		return {}
	var orbit_root := _chopping.get_node_or_null("RunPowerOrbitingAxes") as Node3D
	if orbit_root == null:
		return {}
	var centre := orbit_root.global_position
	var axes: Array[Dictionary] = []
	for raw_axe: Node in orbit_root.get_children():
		var axe := raw_axe as Node3D
		if axe == null:
			continue
		var flat := Vector2(axe.global_position.x - centre.x,
			axe.global_position.z - centre.z)
		if flat.length() <= 0.0001:
			continue
		var contact_radius := 0.0
		for raw_mesh: Node in axe.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := raw_mesh as MeshInstance3D
			if mesh_instance != null and mesh_instance.mesh != null:
				contact_radius = maxf(contact_radius,
					axe.global_position.distance_to(mesh_instance.global_position)
					+ mesh_instance.mesh.get_aabb().size.length() * 0.5)
		axes.append({
			"position": axe.global_position,
			"contact_radius": contact_radius,
		})
	if axes.is_empty():
		return {}
	return {
		"centre": centre,
		"axes": axes,
	}


func _periodic_interval(power_id: StringName) -> float:
	if not _PERIODIC_INTERVAL_KINDS.has(power_id):
		return 0.0
	return maxf(0.001, get_effect(int(_PERIODIC_INTERVAL_KINDS[power_id])))


func _apply_chopping_power_cuts(power_id: StringName, count: int,
		mode: StringName) -> int:
	if count <= 0 or _chopping == null \
			or not _chopping.has_method("apply_run_power_cuts"):
		return 0
	# Periodic powers are counted and presented once by this director after all
	# active-block and loose-root work is resolved. Suppress the chopping helper's
	# normal per-cut burst so one proc cannot render duplicate named silhouettes.
	return maxi(0, int(_chopping.call("apply_run_power_cuts", power_id,
		count, mode, false)))


func _complete_chopping_power_log(power_id: StringName,
		mode: StringName) -> int:
	if _chopping == null \
			or not _chopping.has_method("complete_run_power_log"):
		return 0
	return maxi(0, int(_chopping.call("complete_run_power_log", power_id,
		mode, false)))


func _queue_arena_cut_count(power_id: StringName, count: int,
		origin: Vector3, max_range: float, mode: StringName) -> int:
	return _cut_receipt_count(_queue_arena_cut_receipts(power_id, count,
		origin, max_range, mode))


func _queue_arena_cut_receipts(power_id: StringName, count: int,
		origin: Vector3, max_range: float, mode: StringName) -> Array:
	if count <= 0 or _arena == null or not _arena.has_method("queue_power_cuts"):
		return []
	return _arena.call("queue_power_cuts", power_id, count,
		origin, max_range, mode, [])


func _cut_receipt_count(receipts: Array) -> int:
	var applied := 0
	for raw: Variant in receipts:
		if raw is Dictionary:
			applied += maxi(0, int((raw as Dictionary).get("cuts", 0)))
	return applied


func _first_cut_receipt_position(receipts: Array,
		fallback: Vector3) -> Vector3:
	if receipts.is_empty() or not (receipts[0] is Dictionary):
		return fallback
	var first := receipts[0] as Dictionary
	var receipt_position: Variant = first.get("position", null)
	if receipt_position is Vector3:
		return receipt_position as Vector3
	if _arena == null or not _arena.has_method("get_log_world_position"):
		return fallback
	var log_id := StringName(first.get("log_id", ""))
	return fallback if log_id == &"" else _arena.call(
		"get_log_world_position", log_id) as Vector3


func _complete_automatic_descriptor(descriptor: LogDescriptor,
		power_id: StringName, presented_piece_count: int = -1) -> Dictionary:
	if descriptor == null or descriptor.id == &"" \
			or descriptor.run_id != _run_id \
			or descriptor.yard_id != GameState.get_selected_yard() \
			or descriptor.cash_reward_snapshot <= 0 \
			or descriptor.xp_reward_snapshot <= 0 \
			or phase not in [Phase.ACTIVE, Phase.OVERFLOW] \
			or bool(_automatic_completion_ids.get(descriptor.id, false)):
		return {}
	_automatic_completion_ids[descriptor.id] = true
	var xp_receipt_id := _root_xp_receipt_id(descriptor.id)
	var xp_awarded := 0
	if not _xp_awarded_root_ids.has(xp_receipt_id):
		_xp_awarded_root_ids[xp_receipt_id] = true
		xp_awarded = _commit_xp(descriptor.xp_reward_snapshot)
		if xp_awarded <= 0:
			_xp_awarded_root_ids.erase(xp_receipt_id)
	# Active-block automatic cuts still produce real firewood and coin tokens;
	# preserve their display shares exactly like manual completion. A loose root
	# consumed by Splitter Rig has no pieces, so it settles directly instead.
	var cash_awarded := _prepare_root_cash_shares(descriptor,
		presented_piece_count) if presented_piece_count >= 0 \
		else award_cash(descriptor.cash_reward_snapshot)
	return {
		"power_id": String(power_id),
		"root_id": String(descriptor.id),
		"cash_total": cash_awarded,
		"xp_total": xp_awarded,
		"automatic": true,
	}


func _note_run_power_trigger(power_id: StringName, world_position: Vector3,
		amount: int) -> void:
	_run_power_trigger_counts[power_id] = maxi(0, int(
		_run_power_trigger_counts.get(power_id, 0))) + 1
	_present_run_power_trigger(power_id, world_position, amount)


func _present_run_power_trigger(power_id: StringName, world_position: Vector3,
		amount: int) -> void:
	if _chopping != null and _chopping.has_method("present_run_power_trigger"):
		_chopping.call("present_run_power_trigger", power_id, world_position,
			maxi(1, amount))


func _present_run_power_acquisition(power_id: StringName,
		world_position: Vector3, rank: int, quality: int) -> void:
	if _chopping != null and _chopping.has_method("present_run_power_acquisition"):
		_chopping.call("present_run_power_acquisition", power_id, world_position,
			maxi(1, rank), quality)


func _effective_boundary_radius() -> float:
	return maxf(0.1, tuning.boundary_radius + get_effect(
		ProgressionEffectDef.Kind.BOUNDARY_RADIUS))


func _effective_boundary_grace() -> float:
	return maxf(0.0, tuning.boundary_grace_seconds + get_effect(
		ProgressionEffectDef.Kind.BOUNDARY_GRACE))


func get_area_size_multiplier() -> float:
	return maxf(1.0, get_effect(
		ProgressionEffectDef.Kind.AREA_SIZE_MULTIPLIER))


func scale_power_area(base_size: float) -> float:
	return maxf(0.0, base_size) * get_area_size_multiplier()


func _arrival_multiplier(kind: ProgressionEffectDef.Kind) -> float:
	var value := get_effect(kind)
	return 1.0 if value <= 0.0 else value


func _refresh_run_power_environment(emit_runtime: bool = true) -> void:
	if tuning == null:
		return
	if _arena != null and _arena.has_method("set_run_power_environment"):
		_arena.call("set_run_power_environment", _effective_boundary_radius(),
			_effective_boundary_grace(), _arrival_multiplier(
			ProgressionEffectDef.Kind.ARRIVAL_LATERAL_MULTIPLIER),
			_arrival_multiplier(ProgressionEffectDef.Kind.ARRIVAL_BOUNCE_MULTIPLIER),
			_arrival_multiplier(ProgressionEffectDef.Kind.ARRIVAL_OUTWARD_MULTIPLIER))
	if emit_runtime:
		_emit_run_power_runtime_refresh(false)


func _emit_run_power_runtime_refresh(mark_dirty: bool) -> void:
	_runtime_hud_refresh_elapsed = 0.0
	run_power_runtime_changed.emit(get_run_power_hud_state())
	if mark_dirty:
		attempt_snapshot_dirty.emit()


func _string_keyed_runtime(source: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for raw_id: Variant in source:
		out[String(raw_id)] = source[raw_id]
	return out


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
	var selected := _uniform_power_sample(eligible, count)
	var cards: Array[Dictionary] = []
	var forced_quality := _debug_forced_offer_quality
	for power_id: StringName in selected:
		var definition := _run_power_definition(power_id)
		if definition == null:
			continue
		var current_rank := get_run_power_rank(power_id)
		var quality := _roll_offer_quality_for_power(power_id, forced_quality)
		var quality_multiplier := _quality_multiplier_for(quality)
		var pick_multipliers := _pick_multipliers_for(power_id, current_rank)
		cards.append({
			"id": String(power_id),
			"display_name": definition.display_name,
			"description": definition.description,
			"current_rank": current_rank,
			"next_rank": current_rank + 1,
			"rank_cap": definition.rank_cap,
			"icon_path": definition.icon_path,
			"quality": quality,
			"quality_name": _quality_display_name(quality),
			"quality_multiplier": quality_multiplier,
			"pick_multipliers": pick_multipliers,
			"effect_summary": definition.effect_summary_for_pick_multipliers(
				pick_multipliers, quality_multiplier),
		})
	_debug_forced_offer_quality = RunOfferTuning.Quality.INVALID
	if cards.is_empty():
		var offer_tuning := SurvivorsContent.run_offer_tuning()
		var cash := 1 if offer_tuning == null else offer_tuning.payday_amount(
			level, _payday_picks)
		cards.append({
			"id": String(PAYDAY_POWER_ID),
			"display_name": "Payday",
			"description": "Take an escalating session-cash payout.",
			"current_rank": _payday_picks,
			"next_rank": _payday_picks + 1,
			"rank_cap": -1,
			"icon_path": "res://assets/ui/coin.png",
			"cash": cash,
			"quality": RunOfferTuning.Quality.COMMON,
			"quality_name": _quality_display_name(RunOfferTuning.Quality.COMMON),
			"quality_multiplier": _quality_multiplier_for(
				RunOfferTuning.Quality.COMMON),
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
		if definition == null or get_run_power_rank(power_id) >= definition.rank_cap \
				or not _run_power_has_effect_headroom(power_id):
			continue
		if slots_full and power_id not in _power_slot_order:
			continue
		eligible.append(power_id)
	eligible.sort()
	return eligible


## Every offered rank must change at least one live value at one available card
## quality. This catches domain-floor/plateau edge cases without treating a
## stronger pick as if it consumed multiple owned ranks.
func _run_power_has_effect_headroom(power_id: StringName) -> bool:
	var definition := _run_power_definition(power_id)
	var rank := get_run_power_rank(power_id)
	if definition == null or rank >= definition.rank_cap:
		return false
	for quality: int in range(RunOfferTuning.Quality.COMMON,
			RunOfferTuning.Quality.LEGENDARY + 1):
		if _quality_would_change_power(power_id, quality as RunOfferTuning.Quality):
			return true
	return false


func _uniform_power_sample(source: Array[StringName], count: int) -> Array[StringName]:
	var pool := source.duplicate()
	var out: Array[StringName] = []
	while out.size() < count and not pool.is_empty():
		# Sampling without replacement from a uniformly indexed pool gives every
		# legal identity the same chance. Luck affects card count and the separate
		# upgrade-quality roll, never which power name is chosen.
		var picked := _rng.randi_range(0, pool.size() - 1)
		out.append(pool[picked])
		pool.remove_at(picked)
	return out


func _roll_offer_quality_for_power(power_id: StringName,
		forced_quality: int = RunOfferTuning.Quality.INVALID) \
		-> RunOfferTuning.Quality:
	var meaningful: Array[int] = []
	for quality: int in range(RunOfferTuning.Quality.COMMON,
			RunOfferTuning.Quality.LEGENDARY + 1):
		if _quality_would_change_power(power_id, quality as RunOfferTuning.Quality):
			meaningful.append(quality)
	return _roll_offer_quality(forced_quality, meaningful)


func _quality_would_change_power(power_id: StringName,
		quality: RunOfferTuning.Quality) -> bool:
	var definition := _run_power_definition(power_id)
	var rank := get_run_power_rank(power_id)
	if definition == null or rank >= definition.rank_cap:
		return false
	var multiplier := _quality_multiplier_for(quality)
	if multiplier <= 0.0:
		return false
	var current_picks := _pick_multipliers_for(power_id, rank)
	var next_picks := current_picks.duplicate()
	next_picks.append(multiplier)
	for effect: ProgressionEffectDef in definition.effects:
		if effect == null:
			continue
		var current := definition.effect_value_for_pick_multipliers(
			effect.kind, current_picks)
		var next := definition.effect_value_for_pick_multipliers(
			effect.kind, next_picks)
		if not is_equal_approx(current, next):
			return true
	return false


func _roll_offer_quality(forced_quality: int = RunOfferTuning.Quality.INVALID,
		allowed_qualities: Array[int] = []) \
		-> RunOfferTuning.Quality:
	var offer_tuning := SurvivorsContent.run_offer_tuning()
	if offer_tuning == null:
		return RunOfferTuning.Quality.COMMON
	var qualities: Array[int] = [
		RunOfferTuning.Quality.COMMON,
		RunOfferTuning.Quality.RARE,
		RunOfferTuning.Quality.EPIC,
		RunOfferTuning.Quality.LEGENDARY,
	]
	if not allowed_qualities.is_empty():
		var filtered: Array[int] = []
		for quality: int in qualities:
			if quality in allowed_qualities:
				filtered.append(quality)
		qualities = filtered
	if qualities.is_empty():
		return RunOfferTuning.Quality.COMMON
	if forced_quality >= RunOfferTuning.Quality.COMMON \
			and forced_quality <= RunOfferTuning.Quality.LEGENDARY \
			and forced_quality in qualities:
		return forced_quality as RunOfferTuning.Quality
	var rare_luck := maxf(1.0, GameState.get_meta_effect(
		ProgressionEffectDef.Kind.RARE_QUALITY_WEIGHT))
	var epic_luck := maxf(1.0, GameState.get_meta_effect(
		ProgressionEffectDef.Kind.EPIC_QUALITY_WEIGHT))
	var weights := PackedFloat64Array()
	var total := 0.0
	for raw_quality: int in qualities:
		var quality := raw_quality as RunOfferTuning.Quality
		var weight := offer_tuning.quality_weight_for(quality)
		if quality == RunOfferTuning.Quality.RARE:
			weight *= rare_luck
		elif quality == RunOfferTuning.Quality.EPIC:
			weight *= epic_luck
		weight = maxf(0.000001, weight)
		weights.append(weight)
		total += weight
	var roll := _rng.randf() * total
	for index: int in range(qualities.size()):
		roll -= weights[index]
		if roll <= 0.0:
			return qualities[index] as RunOfferTuning.Quality
	return qualities.back() as RunOfferTuning.Quality


func _quality_multiplier_for(quality: RunOfferTuning.Quality) -> float:
	var offer_tuning := SurvivorsContent.run_offer_tuning()
	return 0.0 if offer_tuning == null else maxf(0.0,
		offer_tuning.quality_multiplier_for(quality))


func _quality_display_name(quality: RunOfferTuning.Quality) -> String:
	return RunOfferTuning.quality_display_name(int(quality))


func _pick_multipliers_for(power_id: StringName, rank: int) -> Array[float]:
	var out: Array[float] = []
	var safe_rank := maxi(0, rank)
	var common := _quality_multiplier_for(RunOfferTuning.Quality.COMMON)
	if common <= 0.0:
		common = 1.0
	var maximum := maxf(common,
		_quality_multiplier_for(RunOfferTuning.Quality.LEGENDARY))
	var raw: Variant = _power_pick_multipliers.get(power_id,
		_power_pick_multipliers.get(String(power_id), []))
	if raw is Array:
		for index: int in range(mini(safe_rank, (raw as Array).size())):
			out.append(clampf(float((raw as Array)[index]), common, maximum))
	while out.size() < safe_rank:
		out.append(common)
	return out


func _offer_contains(power_id: StringName) -> bool:
	for card: Dictionary in _offer_cards():
		if StringName(card.get("id", "")) == power_id:
			return true
	return false


func _offer_card_for(power_id: StringName) -> Dictionary:
	for card: Dictionary in _offer_cards():
		if StringName(card.get("id", "")) == power_id:
			return card.duplicate(true)
	return {}


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
		"pending_blueprint_rolls": _pending_blueprint_rolls.duplicate(),
		"bosses_defeated": _bosses_defeated,
	})


func _on_breach_expired(log_id: StringName) -> void:
	if not is_gameplay_active():
		return
	if _rescue_charges_remaining > 0 \
			and get_run_power_rank(&"last_ditch_rescue") > 0 \
			and _arena != null and _arena.has_method("rescue_log"):
		var rescue_position := Vector3.ZERO
		if _arena.has_method("get_log_world_position"):
			rescue_position = _arena.call("get_log_world_position", log_id)
		if bool(_arena.call("rescue_log", log_id)):
			_rescue_charges_remaining -= 1
			_note_run_power_trigger(&"last_ditch_rescue", rescue_position, 1)
			_emit_run_power_runtime_refresh(true)
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
		"bosses_defeated": _bosses_defeated,
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
		"power_pick_multipliers": get_run_power_pick_multipliers(),
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
	return maxf(1.0, yard.stage_duration_seconds) if yard != null else 900.0


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
		"power_pick_multipliers": get_run_power_pick_multipliers(),
		"run_power_runtime": {
			"periodic_seconds_left": _string_keyed_runtime(
				_periodic_power_seconds_left),
			"trigger_counts": _string_keyed_runtime(_run_power_trigger_counts),
			"rescue_charges_remaining": _rescue_charges_remaining,
			"rescue_charges_granted": _rescue_charges_granted,
			"momentum_stacks": _momentum_stacks,
			"orbit_contact_cooldowns": _string_keyed_runtime(
				_orbiting_axe_contact_cooldowns),
			"automatic_completion_ids": _string_keyed_runtime(
				_automatic_completion_ids),
			"yard_magnet_cycle_seconds_left": _yard_magnet_cycle_seconds_left,
			"yard_magnet_pulse_seconds_left": _yard_magnet_pulse_seconds_left,
		},
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
		"next_boss_schedule_index": _next_boss_schedule_index,
		"pending_boss_schedule_indices": _pending_boss_schedule_indices.duplicate(),
		"boss_stack_remaining": _descriptor_save_array(_boss_stack_remaining),
		"active_boss_id": String(_active_boss_id),
		"active_boss_name": _active_boss_name,
		"active_boss_tier": _active_boss_tier,
		"bosses_defeated": _bosses_defeated,
		"pending_blueprint_rolls": _pending_blueprint_rolls.duplicate(),
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


func _descriptor_save_array(descriptors: Array[LogDescriptor]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for descriptor: LogDescriptor in descriptors:
		if descriptor != null:
			out.append(descriptor.to_dict())
	return out


func _descriptor_array(raw: Variant) -> Array[LogDescriptor]:
	var out: Array[LogDescriptor] = []
	if not (raw is Array):
		return out
	for value: Variant in raw:
		if not (value is Dictionary):
			continue
		var descriptor := LogDescriptor.from_dict(value as Dictionary)
		if descriptor.is_valid() and descriptor.run_id == _run_id \
				and descriptor.yard_id == GameState.get_selected_yard():
			out.append(descriptor)
	return out


func _int_array(raw: Variant) -> Array[int]:
	var out: Array[int] = []
	if raw is Array:
		for value: Variant in raw:
			if value is int:
				out.append(int(value))
	return out


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
	var saved_chopping: Variant = data.get("chopping", {})
	# A transitioning snapshot is taken after the completed root's cash/XP became
	# authoritative but before its physical billets paid out their cosmetic coin
	# receipts. Those bodies are intentionally not persisted, so their shares must
	# not survive restore and become stale claims against the next completed root.
	var discard_transition_receipts := saved_chopping is Dictionary \
		and bool((saved_chopping as Dictionary).get("transitioning", false))
	var saved_piece_cash: Variant = data.get("pending_piece_cash", [])
	if saved_piece_cash is Array and not discard_transition_receipts:
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
	_restore_run_power_runtime(data.get("run_power_runtime", {}))
	_refresh_run_power_environment(false)
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
	var legacy_next_boss_index := _boss_schedule_index_after_elapsed(
		_elapsed_seconds)
	_next_boss_schedule_index = maxi(0,
		int(data.get("next_boss_schedule_index", legacy_next_boss_index)))
	_pending_boss_schedule_indices = _int_array(
		data.get("pending_boss_schedule_indices", []))
	_boss_stack_remaining = _descriptor_array(
		data.get("boss_stack_remaining", []))
	_active_boss_id = StringName(data.get("active_boss_id", ""))
	_active_boss_name = String(data.get("active_boss_name", ""))
	_active_boss_tier = maxi(0, int(data.get("active_boss_tier", 0)))
	_bosses_defeated = maxi(0, int(data.get("bosses_defeated", 0)))
	_pending_blueprint_rolls = _int_array(
		data.get("pending_blueprint_rolls", []))
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
		_chopping.call("restore_run_save_dict",
			saved_chopping if saved_chopping is Dictionary else {})
		if _active_boss_id != &"" and _chopping.has_method(
				"restore_boss_log_stack"):
			_chopping.call("restore_boss_log_stack", _boss_stack_remaining)
		if _chopping.has_method("refresh_run_power_visuals"):
			# Rebuild orbiting/environment visuals without offering Grain Reader
			# again; chopping just restored its exact active mark and provenance.
			_chopping.call("refresh_run_power_visuals", true)
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
	_power_pick_multipliers.clear()
	_periodic_power_seconds_left.clear()
	_run_power_trigger_counts.clear()
	_rescue_charges_remaining = 0
	_rescue_charges_granted = 0
	_momentum_stacks = 0
	_orbiting_axe_contact_cooldowns.clear()
	_automatic_completion_ids.clear()
	_completion_power_queue.clear()
	_resolving_completion_powers = false
	_yard_magnet_cycle_seconds_left = 0.0
	_yard_magnet_pulse_seconds_left = 0.0
	_sync_yard_magnet_force(0.0)
	_debug_forced_offer_quality = RunOfferTuning.Quality.INVALID
	_runtime_hud_refresh_elapsed = 0.0
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
	_next_boss_schedule_index = 0
	_pending_boss_schedule_indices.clear()
	_boss_stack_remaining.clear()
	_active_boss_id = &""
	_active_boss_name = ""
	_active_boss_tier = 0
	_bosses_defeated = 0
	_pending_blueprint_rolls.clear()
	_boundary_timers_paused = false
	_manual_clears = 0
	_splitter_rescues = 0
	_peak_loose_logs = 0
	_cash_earned = 0
	_cash_spent = 0
	_permanent_purchases = 0
	_refresh_run_power_environment(false)
	if _chopping != null and _chopping.has_method("refresh_run_power_visuals"):
		_chopping.call("refresh_run_power_visuals")


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
	boss_stack_changed.emit(_active_boss_name,
		_boss_stack_remaining.size() + (1 if _active_boss_id != &"" else 0))
	powerups_changed.emit(_slow_charges, _blaster_ammo, _slow_seconds_left)
	splitter_changed.emit(_splitter_installed, _splitter_reliability_rank,
		_splitter_seconds_left)
	run_power_runtime_changed.emit(get_run_power_hud_state())
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
	_restore_power_pick_multipliers(data.get("power_pick_multipliers", {}))
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


func _restore_power_pick_multipliers(raw: Variant) -> void:
	_power_pick_multipliers.clear()
	var saved: Dictionary = raw as Dictionary if raw is Dictionary else {}
	for power_id: StringName in _power_slot_order:
		var rank := get_run_power_rank(power_id)
		var saved_picks: Variant = saved.get(String(power_id),
			saved.get(power_id, []))
		if saved_picks is Array:
			_power_pick_multipliers[power_id] = (saved_picks as Array).duplicate()
		_power_pick_multipliers[power_id] = _pick_multipliers_for(power_id, rank)


func _restore_run_power_runtime(raw: Variant) -> void:
	var state: Dictionary = raw as Dictionary if raw is Dictionary else {}
	var saved_timers: Dictionary = _runtime_dictionary(
		state.get("periodic_seconds_left", state.get("timers", {})))
	for raw_id: Variant in _PERIODIC_INTERVAL_KINDS:
		var power_id := StringName(raw_id)
		if get_run_power_rank(power_id) <= 0:
			continue
		var interval := _periodic_interval(power_id)
		var saved_left := float(_runtime_value(saved_timers, power_id, interval))
		_periodic_power_seconds_left[power_id] = clampf(saved_left, 0.0, interval)

	var saved_counts := _runtime_dictionary(state.get("trigger_counts", {}))
	for raw_id: Variant in saved_counts:
		var power_id := StringName(raw_id)
		if _run_power_definition(power_id) == null \
				or get_run_power_rank(power_id) <= 0:
			continue
		_run_power_trigger_counts[power_id] = maxi(0,
			int(saved_counts[raw_id]))

	var rescue_cap := maxi(0, int(round(get_effect(
		ProgressionEffectDef.Kind.RESCUE_CHARGES))))
	_rescue_charges_granted = rescue_cap
	_rescue_charges_remaining = clampi(int(state.get(
		"rescue_charges_remaining", state.get("rescue_charges", rescue_cap))),
		0, rescue_cap)
	var momentum_cap := maxi(0, int(round(get_effect(
		ProgressionEffectDef.Kind.MOMENTUM_MAX_STACKS))))
	_momentum_stacks = clampi(int(state.get("momentum_stacks", 0)),
		0, momentum_cap)

	if get_run_power_rank(&"whirling_axe") > 0:
		var saved_cooldowns := _runtime_dictionary(
			state.get("orbit_contact_cooldowns", {}))
		var cooldown_cap := maxf(0.0, get_effect(
			ProgressionEffectDef.Kind.ORBITING_AXE_CONTACT_COOLDOWN))
		for raw_id: Variant in saved_cooldowns:
			if not (raw_id is String or raw_id is StringName):
				continue
			var log_id := StringName(raw_id)
			var seconds_left := clampf(float(saved_cooldowns[raw_id]),
				0.0, cooldown_cap)
			if log_id != &"" and seconds_left > 0.0:
				_orbiting_axe_contact_cooldowns[log_id] = seconds_left

	var saved_completions := _runtime_dictionary(
		state.get("automatic_completion_ids", {}))
	for raw_id: Variant in saved_completions:
		if (raw_id is String or raw_id is StringName) \
				and StringName(raw_id) != &"" \
				and bool(saved_completions[raw_id]):
			_automatic_completion_ids[StringName(raw_id)] = true

	var magnet_interval := _yard_magnet_interval()
	if magnet_interval > 0.0:
		_yard_magnet_cycle_seconds_left = clampf(float(state.get(
			"yard_magnet_cycle_seconds_left", magnet_interval)),
			0.0, magnet_interval)
		_yard_magnet_pulse_seconds_left = clampf(float(state.get(
			"yard_magnet_pulse_seconds_left",
			tuning.yard_magnet_pulse_duration_seconds)), 0.0,
			tuning.yard_magnet_pulse_duration_seconds)
	else:
		_yard_magnet_cycle_seconds_left = 0.0
		_yard_magnet_pulse_seconds_left = 0.0
	_sync_yard_magnet_force(get_effect(
		ProgressionEffectDef.Kind.YARD_MAGNET_FORCE) \
		if _yard_magnet_pulse_seconds_left > 0.0 else 0.0)


func _runtime_dictionary(raw: Variant) -> Dictionary:
	return raw as Dictionary if raw is Dictionary else {}


func _runtime_value(source: Dictionary, id: StringName,
		fallback: Variant) -> Variant:
	return source.get(String(id), source.get(id, fallback))


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
		# Pre-uniform suspended attempts may carry the retired identity-rarity
		# field. It has no live meaning and is removed during normal restore.
		card.erase("rarity")
		var power_id := StringName(card.get("id", ""))
		if power_id == &"" or ids.has(power_id):
			return {}
		if power_id != PAYDAY_POWER_ID \
				and (not GameState.is_run_power_unlocked(power_id) \
				or _run_power_definition(power_id) == null):
			return {}
		if power_id == PAYDAY_POWER_ID and int(card.get("cash", 0)) <= 0:
			return {}
		if power_id != PAYDAY_POWER_ID:
			var definition := _run_power_definition(power_id)
			var current_rank := get_run_power_rank(power_id)
			if definition == null or current_rank >= definition.rank_cap:
				return {}
			var quality := int(card.get("quality",
				RunOfferTuning.Quality.COMMON)) as RunOfferTuning.Quality
			var multiplier := _quality_multiplier_for(quality)
			if multiplier <= 0.0 \
					or not _quality_would_change_power(power_id, quality):
				return {}
			var picks := _pick_multipliers_for(power_id, current_rank)
			card["display_name"] = definition.display_name
			card["description"] = definition.description
			card["current_rank"] = current_rank
			card["next_rank"] = current_rank + 1
			card["rank_cap"] = definition.rank_cap
			card["icon_path"] = definition.icon_path
			card["quality"] = quality
			card["quality_name"] = _quality_display_name(quality)
			card["quality_multiplier"] = multiplier
			card["pick_multipliers"] = picks
			card["effect_summary"] = definition.effect_summary_for_pick_multipliers(
				picks, multiplier)
		else:
			card["quality"] = RunOfferTuning.Quality.COMMON
			card["quality_name"] = _quality_display_name(
				RunOfferTuning.Quality.COMMON)
			card["quality_multiplier"] = _quality_multiplier_for(
				RunOfferTuning.Quality.COMMON)
		ids[power_id] = true
		cards.append(card)
	return {
		"offer_id": maxi(1, int(saved.get("offer_id", 1))),
		"level": level,
		"slot_count": clampi(int(saved.get("slot_count", cards.size())),
			BASE_OFFER_CARD_COUNT, LUCK_OFFER_CARD_COUNT),
		"cards": cards,
	}
