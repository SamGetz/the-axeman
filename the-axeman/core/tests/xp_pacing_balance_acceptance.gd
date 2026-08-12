extends Node
## Focused regression for the level-to-skill promise and the runaway XP sources
## found in the first uninterrupted fresh-save pacing session.

var _passes := 0
var _fails := 0


func _ready() -> void:
	print("=== XP PACING BALANCE ACCEPTANCE ===")
	_test_one_level_one_point_contract()
	_test_core_tree_manual_projection()
	_test_watched_automation_time_budget()
	await _test_splitter_fractional_carry()
	_test_masterwork_source_and_queue_bounds()
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	print("=== XP PACING BALANCE RESULT: %d passed, %d failed ===" % [
		_passes, _fails])
	if _fails == 0:
		print("=== ALL XP PACING BALANCE CRITERIA PASS ===")
	get_tree().quit(1 if _fails > 0 else 0)


func _test_one_level_one_point_contract() -> void:
	GameState.reset_to_defaults()
	var curve := GameConfig.current().level_curve
	GameState.add_xp(curve.total_xp_for_level(85))
	_check(GameState.get_level() == 85
		and GameState.get_skill_points_earned() == SkillTree.core_purchase_count()
		and GameState.get_skill_points_available() == SkillTree.core_purchase_count(),
		"level 85 still earns exactly the 84 points required by the terrestrial tree")
	_check(curve.endgame_plateau_level > 85
		and curve.xp_to_next(85) > curve.xp_to_next(80),
		"the authored curve continues growing until after the core skill-point run")


func _test_core_tree_manual_projection() -> void:
	var curve := GameConfig.current().level_curve
	var pacing := GameConfig.current().xp_pacing
	var target_xp := curve.total_xp_for_level(85)
	var total_xp := 0
	var elapsed_seconds := 0.0
	var target_seconds := -1.0
	var species := SpeciesTable.all()
	for index in range(species.size()):
		var wood: SpeciesDef = species[index]
		var mastery := M7CContent.mastery().by_species_id(wood.id)
		var logs := mastery.mastery_target
		var awarded_xp := maxi(1, int(round(float(wood.xp_reward)
			* pacing.global_xp_multiplier)))
		if index + 1 < species.size():
			var next_wood: SpeciesDef = species[index + 1]
			var next_threshold := curve.total_xp_for_level(next_wood.unlock_level)
			while total_xp + logs * awarded_xp < next_threshold:
				logs += 1
		for _log in range(logs):
			total_xp += awarded_xp
			elapsed_seconds += pacing.expected_active_seconds_for_species(wood.id)
			if target_seconds < 0.0 and total_xp >= target_xp:
				target_seconds = elapsed_seconds
	# This deliberately generous lower bound pretends the fully upgraded 100%-rate
	# splitter is available and running beside every manual swing from minute zero.
	# Even that impossible opening setup must not reproduce the 30-minute cap-out.
	var max_parallel_seconds := target_seconds / 2.0
	_check(target_seconds >= pacing.core_tree_target_min_seconds
		and target_seconds <= pacing.core_tree_target_max_seconds
		and max_parallel_seconds > 1800.0,
		"point 84 lands inside the %.0f–%.0f minute placeholder band and even a max-parallel splitter bound stays above 30 minutes (%.1f / %.1f)" % [
			pacing.core_tree_target_min_seconds / 60.0,
			pacing.core_tree_target_max_seconds / 60.0,
			target_seconds / 60.0, max_parallel_seconds / 60.0])


func _test_watched_automation_time_budget() -> void:
	var pacing := GameConfig.current().xp_pacing
	var curve := GameConfig.current().level_curve
	var exact_rate := true
	for index in [0, 12, 24]:
		var species := SpeciesTable.at(index)
		var manual_seconds := pacing.expected_active_seconds_for_species(species.id)
		for cycle_seconds: float in [5.0, 2.5]:
			for rate: float in [0.20, 1.0]:
				var cycle_xp: float = pacing.watched_automation_base_xp_for_cycle(
					species, cycle_seconds, rate)
				var projected_per_minute: float = cycle_xp / cycle_seconds * 60.0
				var intended_per_minute: float = float(species.xp_reward) * rate \
					/ manual_seconds * 60.0
				exact_rate = exact_rate and is_equal_approx(
					projected_per_minute, intended_per_minute)
	_check(exact_rate,
		"splitter speed and represented output cannot multiply its authored XP-per-minute share")
	var final_species := SpeciesTable.all()[-1]
	var strongest_cycle := pacing.watched_automation_base_xp_for_cycle(
		final_species, 2.5, 1.0) * pacing.global_xp_multiplier * 1.20
	var final_span := float(curve.xp_to_next(final_species.unlock_level))
	_check(strongest_cycle / final_span < 0.05,
		"even a max-rate late splitter cycle stays below 5% of one routine level span")


func _test_splitter_fractional_carry() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var profile := MechanicalSplitter.profile_definitions()[0]
	var species := SpeciesTable.by_id(profile.automation_species_id)
	var mastery := M7CContent.mastery().by_species_id(species.id)
	var machine := MechanicalSplitter.machine_definition()
	GameState.apply_save_dict({
		"building_tiers": {
			String(machine.id): GameState.DEFAULT_BUILDING_TIER + 1,
			String(profile.id): GameState.DEFAULT_BUILDING_TIER + 1,
		},
		"species_mastery_progress": {String(species.id): mastery.mastery_target},
		"splitter_assigned_species": String(species.id),
	})
	var runtime := MechanicalSplitterRuntime.new()
	add_child(runtime)
	await get_tree().process_frame
	runtime.set_yard_active(true)
	var first_two_zero := true
	var awarded_total := 0
	var cycle_count := 8
	for cycle in range(cycle_count):
		var queued := runtime.try_queue_assigned_input()
		runtime._process(runtime.effective_duration_seconds())
		first_two_zero = first_two_zero and queued \
			and (cycle >= 2 or runtime.last_xp_earned() == 0)
		awarded_total += runtime.last_xp_earned()
	var multiplier := GameConfig.current().xp_pacing.global_xp_multiplier * (1.0 \
		+ SkillTree.total_modifier(GameplayModifierDef.Kind.GLOBAL_XP_GAIN))
	var expected_total := int(floor(runtime.automation_base_xp_budget_for_cycle(
		species.id) * multiplier * float(cycle_count) + 0.000001))
	_check(first_two_zero and awarded_total == expected_total
		and GameState.get_xp() == expected_total,
		"sub-integer final splitter XP carries exactly without per-cycle or multiplier rounding inflation")
	runtime.queue_free()
	await get_tree().process_frame


func _test_masterwork_source_and_queue_bounds() -> void:
	GameState.reset_to_defaults()
	var curve := GameConfig.current().level_curve
	GameState.add_xp(curve.total_xp_for_level(22))
	_buy_ranks(&"lessons_learned", 5)
	_buy_ranks(&"studied_practice", 5)
	_buy_ranks(&"balanced_growth", 5)
	_buy_ranks(&"broad_experience", 1)
	_buy_ranks(&"quick_study", 1)
	_buy_ranks(&"grain_reader", 1)
	_buy_ranks(&"perfect_lesson", 1)
	_buy_ranks(&"eureka", 1)
	_buy_ranks(&"master_axeman", 1)
	_check(SkillTree.get_level(&"master_axeman") == 1,
		"test setup reaches Master Axeman through the real level and purchase flow")
	var level_before := GameState.get_level()
	GameState.award_xp(curve.xp_to_next(level_before) * 4,
		GameState.XP_ORIGIN_SPLITTER)
	_check(GameState.get_level() > level_before + 1
		and GameState.get_masterwork_pending() == 0,
		"a multi-level automation receipt cannot manufacture Masterwork rewards")
	_move_one_xp_before_next_level()
	GameState.award_xp(1, GameState.XP_ORIGIN_MANUAL)
	_check(GameState.get_masterwork_pending() == 1,
		"an ordinary manual level-up prepares exactly one Masterwork")
	GameState.award_xp(curve.xp_to_next(GameState.get_level()) * 4,
		GameState.XP_ORIGIN_MANUAL)
	_check(GameState.get_masterwork_pending() == 1,
		"a multi-level ordinary receipt cannot stack more than one Masterwork")
	_check(GameState.consume_masterwork() and GameState.get_masterwork_pending() == 0,
		"the prepared Masterwork is consumed by one manual log")
	_move_one_xp_before_next_level()
	GameState.award_xp(1, GameState.XP_ORIGIN_MASTERWORK)
	_move_one_xp_before_next_level()
	GameState.award_xp(curve.xp_to_next(GameState.get_level()) * 4,
		GameState.XP_ORIGIN_GRAIN)
	_check(GameState.get_masterwork_pending() == 0,
		"Masterwork and grain level-ups cannot recursively refill the reward")
	var legacy := GameState.to_save_dict()
	legacy["masterwork_pending"] = 99
	GameState.apply_save_dict(legacy)
	_check(GameState.get_masterwork_pending() == 1,
		"legacy stacked Masterwork queues load as one safe next-log reward")


func _move_one_xp_before_next_level() -> void:
	var remaining := GameState.get_xp_to_next_level()
	if remaining > 1:
		GameState.add_xp(remaining - 1)


func _buy_ranks(skill_id: StringName, count: int) -> void:
	for _rank in range(count):
		SkillTree.buy(skill_id)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)
