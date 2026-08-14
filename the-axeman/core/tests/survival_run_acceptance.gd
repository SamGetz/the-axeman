extends Node3D
## Focused acceptance for the survival-era ownership and lifecycle boundaries.
## It is entirely in-memory and never touches the player's SaveSystem file.

class MockChopping:
	extends Node
	signal block_ready_for_log
	signal run_log_ready
	var staged: LogDescriptor
	var staged_with_hop := false
	var prepared := false

	func bind_run_director(_run: RunDirector) -> void:
		pass

	func clear_run_log() -> void:
		staged = null

	func stage_run_log(descriptor: LogDescriptor, hop: bool) -> void:
		staged = descriptor
		staged_with_hop = hop

	func build_run_log_mesh(_descriptor: LogDescriptor) -> Mesh:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.42, 0.86, 0.42)
		return mesh

	func prepare_for_suspend() -> void:
		prepared = true

	func to_run_save_dict() -> Dictionary:
		return {"descriptor": {} if staged == null else staged.to_dict(),
			"cut_journal": [{"piece_id": "root", "local_plane": Plane(Vector3.RIGHT, 0.0)}]}

	func restore_run_save_dict(data: Dictionary) -> void:
		var raw: Variant = data.get("descriptor", {})
		staged = LogDescriptor.from_save_dict(raw) if raw is Dictionary and not raw.is_empty() else null


class MockArena:
	extends Node
	signal loose_count_changed(count: int)
	signal boundary_warning(log_id: StringName, seconds_left: float)
	signal breach_expired(log_id: StringName)
	signal log_landed(log_id: StringName)
	var waiting: Dictionary = {}
	var paused := true
	var last_hazard_delta := 0.0
	var last_hazard_speed := 1.0
	var boundary_timers_paused := false
	var priority_id: StringName = &""

	func bind_run(_run: RunDirector, _chopping: Node, _tuning: SurvivalRunTuning) -> void:
		pass

	func spawn_loose_log(descriptor: LogDescriptor, _seed: int) -> Node:
		waiting[descriptor.id] = descriptor
		loose_count_changed.emit(waiting.size())
		return self

	func add_waiting(descriptor: LogDescriptor) -> void:
		waiting[descriptor.id] = descriptor
		loose_count_changed.emit(waiting.size())

	func eligible_log_ids() -> Array[StringName]:
		var out: Array[StringName] = []
		for raw_id: Variant in waiting:
			out.append(StringName(raw_id))
		return out

	func claim_for_block(id: StringName) -> LogDescriptor:
		var descriptor := waiting.get(id) as LogDescriptor
		waiting.erase(id)
		if descriptor != null:
			descriptor.transfer_from = Vector3(1.0, 0.4, 0.0)
		loose_count_changed.emit(waiting.size())
		return descriptor

	func highest_risk_outside_log_id() -> StringName:
		return priority_id if waiting.has(priority_id) else &""

	func claim_highest_risk_for_splitter() -> LogDescriptor:
		var ids := eligible_log_ids()
		return null if ids.is_empty() else claim_for_block(ids[0])

	func blast(_origin: Vector3, _direction: Vector3, _impulse: float) -> bool:
		return not waiting.is_empty()

	func advance_hazards(delta: float, speed: float) -> void:
		last_hazard_delta = delta
		last_hazard_speed = speed

	func set_hazards_paused(value: bool) -> void:
		paused = value

	func set_boundary_timers_paused(value: bool) -> void:
		boundary_timers_paused = value

	func loose_log_count() -> int:
		return waiting.size()

	func clear_all() -> void:
		waiting.clear()
		loose_count_changed.emit(0)

	func to_save_dict() -> Dictionary:
		var logs: Array[Dictionary] = []
		for descriptor: LogDescriptor in waiting.values():
			logs.append({"descriptor": descriptor.to_dict()})
		return {"logs": logs}

	func restore_from_save(data: Dictionary) -> void:
		waiting.clear()
		var logs: Variant = data.get("logs", [])
		if logs is Array:
			for row: Variant in logs:
				if row is Dictionary and row.get("descriptor", {}) is Dictionary:
					var descriptor := LogDescriptor.from_save_dict(row.descriptor)
					waiting[descriptor.id] = descriptor


var _passed := 0
var _failed := 0


func _ready() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	await _test_descriptor_and_real_arena()
	_test_migration_contract()
	await _test_run_lifecycle()
	await _test_rejected_failure_banking()
	print("SURVIVAL ACCEPTANCE: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _test_descriptor_and_real_arena() -> void:
	var tuning := (load("res://data/survival_run_tuning_placeholder.tres") as SurvivalRunTuning).duplicate(true)
	_check(tuning.validate().is_empty() and tuning.tuning_status.begins_with("PLACEHOLDER"),
		"all survival values remain valid, data-backed, and explicitly provisional")
	_check(is_equal_approx(tuning.boundary_grace_seconds, 5.0),
		"the proposed outside-boundary grace is five continuous seconds")
	var descriptor := _descriptor(&"arena_log", 1)
	var saved := descriptor.to_dict()
	var restored := LogDescriptor.from_save_dict(saved)
	_check(restored.id == descriptor.id and restored.species_id == descriptor.species_id,
		"delivered logs round-trip a stable identity and species")

	var arena := LooseLogArena.new()
	var chopping := MockChopping.new()
	add_child(chopping)
	add_child(arena)
	arena.bind_run(null, chopping, tuning)
	var body := arena.spawn_loose_log(descriptor, 12345)
	_check(body != null and body.global_position.y >= tuning.arrival_height,
		"whole logs spawn physically above the circular arena")
	_check(arena.get_node_or_null("RedBoundary") != null and body.freeze,
		"a visible red boundary exists and menu-time bodies are frozen")
	var boundary := arena.get_node("RedBoundary") as MeshInstance3D
	var boundary_material := boundary.mesh.surface_get_material(0) as StandardMaterial3D
	_check(boundary.mesh is ArrayMesh and boundary_material != null
		and boundary_material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA,
		"the red circle is a translucent ribbon with vertex-faded inner and outer edges")
	var expired := [false]
	var reset_seen := [false]
	arena.breach_expired.connect(func(_id: StringName) -> void: expired[0] = true)
	arena.boundary_warning.connect(func(_id: StringName, left: float) -> void:
		if left < 0.0: reset_seen[0] = true)
	arena.set_hazards_paused(false)
	body.global_position = Vector3(tuning.boundary_radius + 0.2, 0.5, 0.0)
	arena.advance_hazards(4.9, 1.0)
	_check(not bool(expired[0]) and body.boundary_exposure > 4.8,
		"a loose whole log survives until its continuous grace expires")
	body.global_position = Vector3.ZERO
	arena.advance_hazards(0.1, 1.0)
	_check(is_zero_approx(body.boundary_exposure) and bool(reset_seen[0]),
		"re-entering the boundary fully resets that log's timer")
	body.global_position = Vector3(tuning.boundary_radius + 0.2, 0.5, 0.0)
	body.landed = false
	arena.set_boundary_timers_paused(true)
	arena.advance_hazards(5.0, 1.0)
	_check(is_zero_approx(body.boundary_exposure) and not bool(expired[0]),
		"the boundary countdown freezes while a completed log changes over")
	arena.set_boundary_timers_paused(false)
	arena.advance_hazards(0.2, 1.0)
	_check(arena.highest_risk_outside_log_id() == descriptor.id,
		"an out-of-bounds log is the next manual rescue priority even while settling")
	arena.advance_hazards(4.8, 1.0)
	_check(bool(expired[0]), "five continuous outside seconds emits the death breach")
	arena.clear_all()
	arena.queue_free()
	chopping.queue_free()
	await get_tree().process_frame


func _test_migration_contract() -> void:
	var legacy := {
		"cash": 999999,
		"tool_tiers": {Enums.ToolType.AXE: 3},
		"building_tiers": {
			String(GameState.UPGRADE_BALANCED_AXE): 2,
			String(GameState.UPGRADE_SUPPLIER_LEDGER): 2,
			"mission_control": 7,
		},
		"owned_species": ["quaking_aspen", "spiralwood"],
		"selected_species": "quaking_aspen",
		"xp": 4321,
		"skill_levels": {"strong_arms": 2, "orbital_procurement": 9},
		"earth_trees_remaining": 12,
		"earth_master": true,
	}
	var migrated := SaveSystem._migrate_legacy_profile(legacy, 17)
	GameState.apply_save_dict(migrated)
	_check(SaveSystem.SAVE_VERSION == 19 and migrated.has("home_cash")
		and not migrated.has("cash") and not migrated.has("xp")
		and not migrated.has("earth_trees_remaining"),
		"v19 migration converts retired progression into the permanent Home Cash profile")
	_check(GameState.get_home_cash() > 999999
		and GameState.get_meta_upgrade_ranks().is_empty()
		and GameState.get_unlocked_run_powers().size() == 12,
		"v17 cash and recognised progression refund without inventing paid meta ranks")
	var legacy_records := GameState.get_legacy_records()
	_check(not migrated.has("building_tiers") and not migrated.has("owned_species")
		and bool(legacy_records.get("earth", {}).get("earth_cleared", false))
		and int(legacy_records.get("source_version", -1)) == 17,
		"v17 retires old equipment, Woods, and Earth while preserving read-only records")
	_check(Market.get_price(&"aspen_firewood") > 0
		and Market.get_price(&"spiralwood_firewood") == 0,
		"only the 25 terrestrial species remain in the live market")


func _test_run_lifecycle() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var tuning := (load("res://data/survival_run_tuning_placeholder.tres") as SurvivalRunTuning).duplicate(true)
	tuning.delivery_intervals = PackedFloat32Array([2.0, 1.5, 1.0, 0.5])
	tuning.splitter_base_chance = 1.0
	var chopping := MockChopping.new()
	var arena := MockArena.new()
	var run := RunDirector.new()
	run.tuning = tuning
	add_child(chopping)
	add_child(arena)
	add_child(run)
	await get_tree().process_frame
	run.set_process(false)
	run.bind_runtime(chopping, arena)
	run.start_attempt(424242)
	_check(run.phase == RunDirector.Phase.ACTIVE and not run.is_paused()
		and chopping.staged != null and not arena.paused,
		"a seeded attempt begins active with one whole log on the block")
	_check(run.get_cash() == 0 and run.get_xp() == 0 and run.get_level() == 1
		and run.stage_remaining_ms() == int(run.stage_duration_seconds() * 1000.0),
		"attempt cash, XP, level, and stage clock reset at the full-run boundary")

	run._process(run.delivery_interval() + 0.1)
	_check(arena.loose_log_count() == 1,
		"the delivery timer adds waiting logs independently of chopping")
	var first := chopping.staged
	var first_result := run.complete_manual_log(first, 4)
	_check(int(first_result.get("cash_total", 0)) > 0
		and run.get_cash() == int(first_result.get("cash_total", 0))
		and int(run.get_powerup_state().slow_charges) == 0,
		"manual completion commits one fixed root payout without retired powerups")
	var completed_species := SpeciesTable.by_id(first.species_id)
	var session_cash_after_completion := run.get_cash()
	var displayed_cash_shares := 0
	if completed_species != null:
		for _piece_index: int in range(4):
			displayed_cash_shares += run.settle_completed_piece(completed_species.yield_item)
	_check(completed_species != null
		and displayed_cash_shares == int(first_result.get("cash_total", 0))
		and run.get_cash() == session_cash_after_completion
		and InventoryManager.get_count(completed_species.yield_item) == 0,
		"landed coin receipts validate inventory and display every share without paying twice")
	_check(arena.boundary_timers_paused,
		"manual completion pauses only the boundary danger timer during changeover")
	_check(not run.activate_slow_time(),
		"retired Slow Time cannot activate during a survivors attempt")
	var before_ms := run.elapsed_ms()
	run.set("_delivery_seconds_left", 2.0)
	run._process(1.0)
	_check(run.elapsed_ms() == before_ms + 1000
		and is_equal_approx(arena.last_hazard_delta, 1.0)
		and is_equal_approx(float(run.to_save_dict().delivery_seconds_left),
			1.0),
		"retired Slow Time no longer alters hazards or the stage clock")

	var paused_at := run.elapsed_ms()
	run.pause_attempt()
	run._process(1.0)
	_check(run.elapsed_ms() == paused_at and arena.paused
		and chopping.process_mode == Node.PROCESS_MODE_DISABLED,
		"opening a menu pauses the clock, loose physics, and chopping together")
	run.resume_attempt()
	_check(not arena.paused and chopping.process_mode == Node.PROCESS_MODE_INHERIT,
		"closing a menu resumes the full attempt")

	var exposed_id: StringName = arena.eligible_log_ids()[0]
	arena.add_waiting(_descriptor(&"safe_fallback", 45))
	arena.priority_id = exposed_id
	chopping.block_ready_for_log.emit()
	_check(chopping.staged != null and chopping.staged_with_hop
		and chopping.staged.id == exposed_id,
		"completion prioritises an out-of-bounds loose log and requests its block hop")
	_check(arena.boundary_timers_paused,
		"the danger timer remains frozen while the priority log is visibly in flight")
	chopping.run_log_ready.emit()
	_check(not arena.boundary_timers_paused,
		"the danger timer resumes when the replacement log lands on the block")

	run.award_cash(tuning.splitter_purchase_cost + 10)
	var purse_before_failure := run.get_cash()
	_check(not run.purchase_splitter() and not run.try_spend_cash(1)
		and not bool(run.get_splitter_state().installed)
		and run.get_cash() == purse_before_failure,
		"session cash cannot buy the retired run splitter or be spent during play")
	var profile_before_failure := GameState.to_save_dict()
	_check(not profile_before_failure.has("xp")
		and not profile_before_failure.has("skill_levels")
		and not profile_before_failure.has("permanent_upgrades"),
		"the permanent profile carries no live XP, skill-tree, or old equipment state")

	var failed_results: Array[Dictionary] = [{}]
	run.attempt_finished.connect(func(results: Dictionary) -> void: failed_results[0] = results)
	arena.breach_expired.emit(&"outside_log")
	_check(run.phase == RunDirector.Phase.FAILED and not failed_results[0].is_empty()
		and int(failed_results[0].get("bank_receipt", {}).get("cash_banked", -1))
			== purse_before_failure
		and GameState.get_home_cash() == purse_before_failure,
		"an expired boundary timer settles the full session purse exactly once")
	run.start_attempt(99)
	_check(run.get_cash() == 0 and not bool(run.get_splitter_state().installed)
		and int(run.get_powerup_state().slow_charges) == 0
		and run.get_xp() == 0 and run.get_level() == 1
		and GameState.get_home_cash() == purse_before_failure
		and GameState.get_unlocked_run_powers().size() == 12,
		"death restart resets disposable state while the settled home profile survives")

	var near_clear := run.to_save_dict()
	near_clear.elapsed_seconds = run.stage_duration_seconds() - 0.05
	_check(run.restore_attempt(near_clear), "a near-clear attempt snapshot restores")
	run.resume_attempt()
	var clear_events := [0]
	run.stage_cleared.connect(func(_ms: int) -> void: clear_events[0] += 1)
	run._process(0.1)
	_check(run.phase == RunDirector.Phase.EARTH_CLEAR and run.is_paused()
		and int(clear_events[0]) == 1 and run.earth_clear_ms() >= 0,
		"the 20-minute stage boundary pauses once for the cash-out decision")
	run.resume_attempt()
	_check(run.phase == RunDirector.Phase.EARTH_CLEAR and run.is_paused(),
		"generic resume cannot silently choose endless at stage clear")
	run.continue_endless()
	_check(run.phase == RunDirector.Phase.OVERFLOW and not run.is_paused(),
		"the same attempt continues into endless overflow")
	arena.breach_expired.emit(&"overflow_breach")
	var yard_record := GameState.get_yard_record(GameState.DEFAULT_YARD_ID)
	_check(int(yard_record.get("clears", 0)) > 0
		and int(yard_record.get("longest_endless_ms", -1)) >= 0,
		"the final endless breach stores the stage clear and endless records")

	run.start_attempt(7)
	run.award_cash(321)
	var suspended := run.suspend_attempt()
	_check(chopping.prepared and int(suspended.phase) == RunDirector.Phase.ACTIVE
		and int(suspended.cash) == 321 and suspended.chopping.has("cut_journal"),
		"suspension normalises animations and saves the active cut journal")
	var restored_chopping := MockChopping.new()
	var restored_arena := MockArena.new()
	var restored_run := RunDirector.new()
	restored_run.tuning = tuning
	add_child(restored_chopping)
	add_child(restored_arena)
	add_child(restored_run)
	await get_tree().process_frame
	restored_run.set_process(false)
	restored_run.bind_runtime(restored_chopping, restored_arena)
	_check(restored_run.restore_attempt(suspended) and restored_run.get_cash() == 321
		and restored_run.is_paused(),
		"a suspended attempt restores once, paused, without inventing rewards")

	run.queue_free()
	arena.queue_free()
	chopping.queue_free()
	restored_run.queue_free()
	restored_arena.queue_free()
	restored_chopping.queue_free()


func _test_rejected_failure_banking() -> void:
	GameState.reset_to_defaults()
	var tuning := (load("res://data/survival_run_tuning_placeholder.tres") \
		as SurvivalRunTuning).duplicate(true)
	var chopping := MockChopping.new()
	var arena := MockArena.new()
	var run := RunDirector.new()
	run.tuning = tuning
	add_child(chopping)
	add_child(arena)
	add_child(run)
	await get_tree().process_frame
	run.set_process(false)
	run.bind_runtime(chopping, arena)
	run.start_attempt(8080)
	run.award_cash(77)
	var run_id := run.get_run_id()
	var prior := GameState.bank_run({
		"run_id": String(run_id), "yard_id": "yard_one", "session_cash": 0,
	})
	var failures := [0]
	var finishes := [0]
	run.settlement_failed.connect(func(_message: String) -> void: failures[0] += 1)
	run.attempt_finished.connect(func(_results: Dictionary) -> void: finishes[0] += 1)
	arena.breach_expired.emit(&"rejected_settlement")
	var resumable := run.to_save_dict()
	_check(not prior.is_empty() and run.phase == RunDirector.Phase.ACTIVE \
		and run.is_paused() and run.has_live_attempt() and run.get_cash() == 77 \
		and int(failures[0]) == 1 and int(finishes[0]) == 0 \
		and GameState.are_permanent_controls_locked() \
		and int(resumable.get("cash", -1)) == 77,
		"a rejected failure settlement remains paused, locked, and resumable without losing its purse")
	run.abandon_attempt()
	run.queue_free()
	arena.queue_free()
	chopping.queue_free()


func _descriptor(id: StringName, serial: int) -> LogDescriptor:
	var species := SpeciesTable.starting_species()
	return LogDescriptor.create(id, species.id, 0, serial, serial * 17)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("PASS: " + message)
	else:
		_failed += 1
		push_error("FAIL: " + message)
