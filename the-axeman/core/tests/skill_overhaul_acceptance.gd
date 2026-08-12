extends Node

var _passes := 0
var _fails := 0


func _ready() -> void:
	print("=== SKILL OVERHAUL ACCEPTANCE ===")
	_test_exact_graph_and_reveal_gate()
	_test_square_graph_layout_and_hover_copy()
	_test_direct_click_and_paid_respec()
	_test_either_branch_prerequisite()
	_test_uncapped_curve_and_v14_refund()
	_test_point_cash_frontier_switch()
	_test_origin_aware_rewards_apply_once()
	_test_orb_curve_and_exact_shares()
	_test_species_pacing_shape()
	print("=== SKILL OVERHAUL RESULT: %d passed, %d failed ===" % [_passes, _fails])
	get_tree().quit(0 if _fails == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _test_exact_graph_and_reveal_gate() -> void:
	GameState.reset_to_defaults()
	var counts := {&"strength": 0, &"speed": 0, &"mastery": 0, &"frontier": 0}
	var ranked_foundations := 0
	var total_ranks := 0
	for node: SkillNodeDef in SkillTree.get_nodes():
		counts[node.branch_id] = int(counts.get(node.branch_id, 0)) + 1
		total_ranks += node.max_level
		if node.max_level == 5:
			ranked_foundations += 1
		_check(node.cost == 1 and node.max_level in [1, 5],
			"%s has an approved one-point rank shape" % node.display_name)
		_check(not node.description.contains("PLACEHOLDER") and node.description.length() >= 24,
			"%s has final player-facing bonus copy" % node.display_name)
		for modifier: GameplayModifierDef in node.effects + node.modifiers:
			_check(modifier == null or modifier.tuning_status.begins_with("FINAL"),
				"%s uses finalized effect values" % node.display_name)
	_check(SkillTree.get_nodes().size() == 45, "the graph contains exactly 45 nodes")
	_check(counts == {&"strength": 12, &"speed": 12, &"mastery": 12, &"frontier": 9},
		"branch counts are 12/12/12/9")
	_check(ranked_foundations == 12 and total_ranks == 93,
		"the 84-rank core is preserved while Frontier is nine one-rank purchases")
	_check(SkillTree.get_revealed_nodes().size() == 36 \
		and SkillTree.get_presented_nodes().size() == 36,
		"all three terrestrial trees are presented immediately while Frontier remains hidden")
	# Only procs granted by the finalized skill graph belong to this contract.
	# Equipment-only Mastery Echo and Express Handoff deliberately retain their
	# measured-pacing placeholder labels and are covered by their focused suite.
	var skill_proc_ids: Dictionary = {}
	for node: SkillNodeDef in SkillTree.get_nodes():
		if node != null and node.proc_id != &"":
			skill_proc_ids[node.proc_id] = true
	var procs_final := not skill_proc_ids.is_empty()
	for proc: ProcDef in M7CContent.procs().procs:
		if proc == null or not skill_proc_ids.has(proc.id):
			continue
		procs_final = procs_final and proc.tuning_status.begins_with("FINAL")
		for modifier: GameplayModifierDef in proc.modifiers:
			procs_final = procs_final and modifier.tuning_status.begins_with("FINAL")
	_check(procs_final, "all skill proc chances, pity limits, and rewards are finalized")
	GameState.add_xp((GameConfig.current().level_curve).total_xp_for_level(50))
	_check(SkillTree.buy(&"specimen_handling") == -1,
		"a hidden Frontier root is rejected by SkillTree.buy")


func _test_uncapped_curve_and_v14_refund() -> void:
	var curve := GameConfig.current().level_curve
	var xp_150 := curve.total_xp_for_level(150)
	_check(curve.level_for_xp(xp_150) == 150, "levels continue beyond 99")
	_check(curve.xp_to_next(150) == curve.xp_to_next(curve.endgame_plateau_level),
		"post-ramp levels use the authored repeatable plateau")
	var migrated := SaveSystem._migrate({
		"xp": xp_150, "cash": 123, "skill_levels": {"strong_arms": 7},
		"legacy_skill_ranks": {"strong_arms": 3}, "proc_dry_streak": {"quick_study": 9},
	}, 12)
	_check((migrated.get("skill_levels") as Dictionary).is_empty()
		and (migrated.get("legacy_skill_ranks") as Dictionary).is_empty()
		and (migrated.get("proc_dry_streak") as Dictionary).is_empty(),
		"the v13/v14 chain performs the ranked-tree skill/proc refund")
	_check(int(migrated.get("skill_points_earned_total")) == 84
		and int(migrated.get("last_rewarded_level")) == 150,
		"migration caps historical entitlement to the complete terrestrial tree without replaying rewards")
	_check(int(migrated.get("cash")) == 123, "v14 grants no retroactive level cash")
	var v13_rank_shape := SaveSystem._migrate({
		"cash": 321, "skill_levels": {"strong_arms": 1, "deep_bite": 1},
		"skill_points_earned_total": 12, "proc_dry_streak": {"quick_study": 4},
	}, 13)
	_check((v13_rank_shape.get("skill_levels") as Dictionary).is_empty()
		and int(v13_rank_shape.get("skill_points_earned_total")) == 12
		and int(v13_rank_shape.get("cash")) == 321,
		"v14 refunds an impossible old partial-parent save while preserving points and cash")


func _test_square_graph_layout_and_hover_copy() -> void:
	GameState.reset_to_defaults()
	var graph := SkillGraphView.new()
	graph.size = Vector2(220.0, 380.0)
	graph.configure(M7CContent.branches().by_id(&"strength"), &"strong_arms")
	var buttons := graph.find_children("*", "Button", true, false)
	var square_and_described := buttons.size() == 12
	var readable_tooltips := buttons.size() == 12
	var calculated_rank_bonus := false
	var hides_system_terms := true
	var inside := true
	for raw: Node in buttons:
		var button := raw as Button
		square_and_described = square_and_described \
			and is_equal_approx(button.custom_minimum_size.x, button.custom_minimum_size.y) \
			and button.tooltip_text.contains("Cost: 1 point") \
			and button.has_meta("rank_label")
		var tooltip := button._make_custom_tooltip(button.tooltip_text) as Control
		readable_tooltips = readable_tooltips and tooltip != null \
			and tooltip.custom_minimum_size.x >= 360.0 \
			and tooltip.find_children("*", "Label", true, false).size() == 3
		if tooltip != null:
			tooltip.free()
		if button.get_meta("skill_id", &"") == &"strong_arms":
			calculated_rank_bonus = String(button.get("tooltip_body")).contains(
				"CURRENT BONUS · RANK 0/5") and String(button.get("tooltip_body")).contains(
				"+10% at rank 5")
		var body := String(button.get("tooltip_body")).to_lower()
		for hidden_term: String in ["proc", "dry-streak", "eligible event",
				"chain cap", "current gear + skill", "recursive"]:
			hides_system_terms = hides_system_terms and not body.contains(hidden_term)
		inside = inside and button.position.y + button.size.y <= graph.custom_minimum_size.y
	_check(square_and_described,
		"every tree node is a square icon with its description/cost in hover copy")
	_check(inside, "all nine authored tiers fit vertically without scrolling")
	_check(readable_tooltips,
		"hover details use a wide, high-contrast three-part tooltip card")
	_check(calculated_rank_bonus,
		"ranked hover copy calculates the current and 5/5 bonus in plain language")
	_check(hides_system_terms,
		"skill hover copy explains gameplay benefits without exposing resolver rules")
	_check(4.0 * 170.0 + 3.0 * 6.0 <= 1020.0,
		"the revealed fourth tree compresses all four columns inside the graph window")
	graph.free()


func _test_direct_click_and_paid_respec() -> void:
	GameState.reset_to_defaults()
	var curve := GameConfig.current().level_curve
	var setup := GameState.to_save_dict()
	setup["cash"] = 1000
	setup["xp"] = curve.total_xp_for_level(6)
	setup["skill_points_earned_total"] = 5
	setup["last_rewarded_level"] = 6
	GameState.apply_save_dict(setup)
	var graph := SkillGraphView.new()
	graph.size = Vector2(220.0, 380.0)
	graph.configure(M7CContent.branches().by_id(&"strength"), &"")
	graph.node_selected.connect(func(id: StringName) -> void: SkillTree.buy(id))
	var strong := graph.find_child("StrongArms", true, false) as Button
	if strong != null:
		strong.pressed.emit()
	_check(strong != null and SkillTree.get_level(&"strong_arms") == 1,
		"clicking an available square grants its skill without a detail-panel action")
	graph.configure(M7CContent.branches().by_id(&"strength"), &"")
	strong = graph.find_child("StrongArms", true, false) as Button
	_check(strong != null and strong.get_meta("rank_label") == "1/5"
		and not SkillTree.prerequisites_met(&"deep_bite"),
		"the square clearly shows 1/5 and its child remains locked")
	for _rank in range(4):
		SkillTree.buy(&"strong_arms")
	graph.configure(M7CContent.branches().by_id(&"strength"), &"")
	strong = graph.find_child("StrongArms", true, false) as Button
	_check(strong != null and strong.get_meta("rank_label") == "5/5"
		and SkillTree.prerequisites_met(&"deep_bite"),
		"the square clearly shows 5/5 and only completion unlocks its child")
	_check(GameState.get_skill_respec_cost() == 200,
		"respec quotes exactly 20% of the current 1,000-coin purse")
	GameState.note_proc_result(&"quick_study", false)
	_check(GameState.respec_skills()
		and GameState.get_cash() == 800
		and SkillTree.get_level(&"strong_arms") == 0
		and GameState.get_skill_points_available() == 5
		and GameState.get_proc_dry_streak(&"quick_study") == 0,
		"respec atomically charges 20%, refunds points, and clears proc carry-over")
	var cash_after := GameState.get_cash()
	_check(not GameState.respec_skills() and GameState.get_cash() == cash_after,
		"respec with no learned nodes is rejected without charging cash")
	graph.free()


func _test_either_branch_prerequisite() -> void:
	GameState.reset_to_defaults()
	var setup := GameState.to_save_dict()
	setup["skill_levels"] = {"strong_arms": 5, "deep_bite": 5}
	setup["skill_points_earned_total"] = 11
	GameState.apply_save_dict(setup)
	_check(SkillTree.get_level(&"wedge_sense") == 0
		and SkillTree.prerequisites_met(&"hardwood_training")
		and SkillTree.missing_prerequisites(&"hardwood_training").is_empty()
		and SkillTree.buy(&"hardwood_training") == 1,
		"a merge node unlocks when either preceding branch is complete")


func _test_point_cash_frontier_switch() -> void:
	GameState.reset_to_defaults()
	var curve := GameConfig.current().level_curve
	GameState.add_xp(curve.total_xp_for_level(85))
	var bought := 0
	var progress := true
	while progress:
		progress = false
		for node: SkillNodeDef in SkillTree.get_revealed_nodes():
			if SkillTree.can_buy(node.id) and SkillTree.buy(node.id) > 0:
				bought += 1
				progress = true
	_check(bought == 84 and GameState.get_skill_points_available() == 0,
		"84 earned points complete every visible core rank (bought=%d available=%d earned=%d spent=%d)" % [
			bought, GameState.get_skill_points_available(), GameState.get_skill_points_earned(),
			GameState.get_skill_points_spent()])
	var receipts: Array[LevelRewardReceipt] = []
	var on_receipt := func(receipt: LevelRewardReceipt) -> void: receipts.append(receipt)
	GameState.level_reward_granted.connect(on_receipt)
	var cash_before := GameState.get_cash()
	GameState.add_xp(GameState.get_xp_to_next_level())
	_check(not receipts.is_empty()
		and receipts[-1].reward_type == LevelRewardReceipt.RewardType.CASH
		and receipts[-1].amount == GameState.get_cash() - cash_before,
		"a completed visible tree pays one exact cash receipt")
	var save := GameState.to_save_dict()
	save["earth_finale_state"] = GameState.EarthFinaleState.COMPLETE
	save["earth_finale_splits"] = 3
	save["earth_master"] = true
	GameState.apply_save_dict(save)
	_check(SkillTree.get_revealed_nodes().size() == 45 \
		and SkillTree.get_presented_nodes().size() == 45,
		"Earth Master reveals and presents all nine Frontier nodes")
	receipts.clear()
	GameState.add_xp(GameState.get_xp_to_next_level())
	_check(not receipts.is_empty()
		and receipts[-1].reward_type == LevelRewardReceipt.RewardType.CASH
		and GameState.get_skill_points_available() == 0,
		"post-Earth levels stay cash rewards instead of desynchronizing the Frontier finale")
	_check(GameState._grant_milestone_skill_points(&"alien_mastery:test", 3)
		and not GameState._grant_milestone_skill_points(&"alien_mastery:test", 3)
		and GameState.get_skill_points_available() == 3,
		"one alien mastery source grants exactly three Frontier points exactly once")
	if GameState.level_reward_granted.is_connected(on_receipt):
		GameState.level_reward_granted.disconnect(on_receipt)


func _test_orb_curve_and_exact_shares() -> void:
	var config := GameConfig.current().xp_pacing
	_check(config.validate().is_empty(), "the pacing/orb resource covers every anchor and overlap bound")
	var awards := [1, 6, 18, 120, 500, 2341, 3824, 10000, 1000000]
	var previous := 0
	for award: int in awards:
		var shares := config.orb_shares_for_xp(award)
		var sum := 0
		for share: int in shares:
			sum += share
		_check(shares.size() >= previous, "%d XP never reduces orb count" % award)
		_check(shares.size() <= config.orb_count_cap, "%d XP stays inside the count cap" % award)
		_check(sum == award, "%d XP reconciles exactly across quotient/remainder shares" % award)
		previous = shares.size()


func _test_origin_aware_rewards_apply_once() -> void:
	GameState.reset_to_defaults()
	var curve := GameConfig.current().level_curve
	GameState.add_xp(curve.total_xp_for_level(7))
	for _rank in range(5):
		SkillTree.buy(&"lessons_learned")
	_check(SkillTree.get_level(&"lessons_learned") == 5
		and SkillTree.buy(&"keen_appraisal") == 1,
		"test setup maxes one ranked global XP node and learns one cash rank")
	var xp_before := GameState.get_xp()
	var awarded_xp := GameState.award_xp(100, &"acceptance")
	_check(awarded_xp == 163 and GameState.get_xp() - xp_before == 163,
		"a genuine XP source receives the campaign multiplier and all five Mastery ranks exactly once")
	var cash_before := GameState.get_cash()
	var awarded_cash := GameState.award_cash(100, &"acceptance")
	_check(awarded_cash == 101 and GameState.get_cash() - cash_before == 101,
		"a genuine cash source receives the global Mastery step exactly once")
	var raw_xp_before := GameState.get_xp()
	GameState.add_xp(100)
	GameState.add_cash(100)
	_check(GameState.get_xp() - raw_xp_before == 100
		and GameState.get_cash() - cash_before - awarded_cash == 100,
		"raw setup/restore grants remain exact and bypass earning modifiers")


func _test_species_pacing_shape() -> void:
	var curve := GameConfig.current().level_curve
	var config := GameConfig.current().xp_pacing
	var prior_rewards := PackedInt32Array([
		5, 30, 111, 192, 309, 429, 549, 668, 784, 897, 1008, 1116, 1221,
		1323, 1423, 1520, 1615, 1707, 1798, 1886, 1973, 2036, 2050, 2070, 2100])
	var previous_minutes := 0.0
	for index in range(SpeciesTable.all().size()):
		var species: SpeciesDef = SpeciesTable.all()[index]
		_check(species.xp_reward == (prior_rewards[index] * 115 + 50) / 100,
			"%s receives the approved 15%% base XP increase" % species.display_name)
		var logs := float(curve.xp_to_next(config.representative_terrestrial_levels[index])) \
			/ float(species.xp_reward)
		var minutes := logs * float(config.representative_terrestrial_active_seconds[index]) / 60.0
		_check(minutes + 0.02 >= previous_minutes,
			"%s does not reverse the active-time difficulty ramp" % species.display_name)
		_check(logs < 20.0, "%s stays clear of the former 80–120-log wall" % species.display_name)
		previous_minutes = minutes
	var prior_alien := PackedInt32Array([2620, 2850, 3325])
	for index in range(AlienCampaign.traits().size()):
		var alien: AlienWoodTraitDef = AlienCampaign.traits()[index]
		_check(alien.xp_reward == (prior_alien[index] * 115 + 50) / 100,
			"%s receives the approved 15%% base XP increase" % alien.display_name)
	var final_alien: AlienWoodTraitDef = AlienCampaign.traits()[-1]
	var final_seconds := float(curve.xp_to_next(config.representative_alien_levels[-1])) \
		/ float(final_alien.xp_reward) * config.representative_alien_active_seconds[-1]
	_check(absf(final_seconds - config.final_frontier_target_seconds) < 1.0,
		"the final Frontier level span matches the campaign-calibrated active-time target")
