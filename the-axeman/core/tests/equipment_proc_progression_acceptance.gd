extends Node
## Focused contract for the proc-driven cash-shop equipment slice.

var _passes := 0
var _fails := 0


func _ready() -> void:
	print("=== EQUIPMENT PROC PROGRESSION ACCEPTANCE ===")
	_test_catalogue_shape()
	_test_atomic_purchase_and_active_profile()
	_test_combined_sources_and_persisted_fairness()
	_test_stump_and_auxiliary_composition()
	_test_mastery_root_receipt()
	_test_shop_identity_copy()
	await _test_gear_only_strike_and_follow_up()
	await _test_gear_only_mastery_grain_and_handoff()
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	print("=== EQUIPMENT PROC RESULT: %d passed, %d failed ===" % [_passes, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _test_catalogue_shape() -> void:
	var axes: Array[UpgradeDef] = []
	var stumps: Array[UpgradeDef] = []
	var ids: Dictionary = {}
	for definition: UpgradeDef in Shop.get_upgrades():
		if definition == null or definition.equipment_slot == UpgradeDef.EquipmentSlot.NONE:
			continue
		_check(not ids.has(definition.id), "equipment identity is unique: %s" % definition.id)
		ids[definition.id] = true
		_check(definition.purchase_form == UpgradeDef.PurchaseForm.ONE_TIME \
			and definition.max_level == 1,
			"%s is a one-time identity, not a rank" % definition.display_name)
		if definition.equipment_slot == UpgradeDef.EquipmentSlot.AXE:
			axes.append(definition)
		else:
			stumps.append(definition)
	_check(axes.size() == 8 and stumps.size() == 8,
		"the cash shop contains exactly eight new axes and eight new stumps")
	for family: Array[UpgradeDef] in [axes, stumps]:
		family.sort_custom(func(a: UpgradeDef, b: UpgradeDef) -> bool:
			return a.equipment_stage < b.equipment_stage)
		for index in range(family.size()):
			_check(family[index].equipment_stage == index + 1,
				"%s occupies authored equipment stage %d" % [family[index].display_name, index + 1])
			if index > 0:
				_check(family[index].required_upgrade_id == family[index - 1].id,
					"%s directly requires the prior named purchase" % family[index].display_name)
	var expected_axe_costs := [100, 500, 2500, 12500, 75000, 750000, 75000000, 25000000000]
	var expected_stump_costs := [150, 650, 3000, 15000, 90000, 900000, 90000000, 30000000000]
	for index in range(8):
		_check(axes[index].base_cost == expected_axe_costs[index]
			and stumps[index].base_cost == expected_stump_costs[index],
			"stage %d carries the approved axe and stump cash prices" % (index + 1))
	_check(axes[0].required_upgrade_id == &"balanced_axe"
		and stumps[0].required_upgrade_id == &"reinforced_chopping_block"
		and axes[1].unlock_order_id == &"aspen_hearth_load"
		and stumps[2].unlock_order_id == &"pine_campsite_load"
		and axes[3].required_mastered_species_count == 3
		and stumps[3].required_mastered_species_count == 3,
		"the early chain carries its equipment, order and three-mastery gates")
	for family: Array[UpgradeDef] in [axes, stumps]:
		_check(family[4].campaign_gate == UpgradeDef.CampaignGate.LOG_FEEDER
			and family[5].campaign_gate == UpgradeDef.CampaignGate.HEADQUARTERS_YARD
			and family[6].campaign_gate == UpgradeDef.CampaignGate.EARTH_MASTER
			and family[7].campaign_gate == UpgradeDef.CampaignGate.FIRST_ALIEN_SPECIMEN,
			"%s carries the typed late-campaign gate sequence" % family[7].display_name)
	_check(M7CContent.equipment().equipment.size() == 20,
		"the visual catalogue has stable entries for all identities plus fallbacks")


func _test_atomic_purchase_and_active_profile() -> void:
	GameState.reset_to_defaults()
	GameState.apply_save_dict({
		"cash": 99,
		"completed_orders": ["campfire_warmup"],
		"building_tiers": {"balanced_axe": 2},
	})
	_check(Shop.buy(&"tempered_woodsmans_axe") == -1
		and GameState.get_cash() == 99
		and Shop.get_level(&"tempered_woodsmans_axe") == 0,
		"an unaffordable equipment purchase changes neither cash nor ownership")
	GameState.add_cash(1)
	_check(Shop.buy(&"tempered_woodsmans_axe") == 1
		and GameState.get_cash() == 0,
		"an affordable equipment purchase spends cash and grants ownership atomically")
	GameState.apply_save_dict({
		"building_tiers": {
			"balanced_axe": 2,
			"tempered_woodsmans_axe": 2,
			"forged_splitting_maul": 2,
		},
	})
	var active := Shop.active_equipment(UpgradeDef.EquipmentSlot.AXE)
	_check(active != null and active.id == &"forged_splitting_maul"
		and is_equal_approx(Shop.equipment_proc_chance(&"double_strike"), 0.04),
		"only the highest owned axe supplies its active Strike chance")
	_check(is_equal_approx(Shop.total_effect(UpgradeDef.Effect.SPLIT_RELIABILITY), 0.05),
		"Balanced Axe and both named axe reliability contributions remain cumulative")


func _test_combined_sources_and_persisted_fairness() -> void:
	GameState.reset_to_defaults()
	GameState.apply_save_dict({"building_tiers": {
		"balanced_axe": 2,
		"tempered_woodsmans_axe": 2,
		"forged_splitting_maul": 2,
	}})
	_check(is_equal_approx(ProgressionProcs.effective_chance(&"double_strike"), 0.04)
		and ProgressionProcs.effective_chain_cap(&"double_strike") == 1,
		"gear alone enables its weaker Double Strike profile")
	var proc := ProgressionProcs.proc_def(&"double_strike")
	ProcResolver.should_proc_with_chance(proc,
		ProgressionProcs.effective_chance(&"double_strike"), 0)
	var streak := GameState.get_proc_dry_streak(&"double_strike")
	GameState.set_skill_level(&"double_strike", 1)
	_check(is_equal_approx(ProgressionProcs.effective_chance(&"double_strike"), 0.14)
		and GameState.get_proc_dry_streak(&"double_strike") == streak,
		"the approved 10-point skill chance adds to gear without resetting fairness")
	var saved := GameState.to_save_dict()
	GameState.reset_to_defaults()
	GameState.apply_save_dict(saved)
	_check(GameState.get_proc_dry_streak(&"double_strike") == streak,
		"the combined-source proc keeps its dry streak across save restore")
	_check(ProgressionProcs.proc_def(&"mastery_echo").bad_luck_bound == 20
		and ProgressionProcs.proc_def(&"express_handoff").bad_luck_bound == 12,
		"new equipment proc families carry their provisional authored bounds")


func _test_mastery_root_receipt() -> void:
	GameState.reset_to_defaults()
	var species := SpeciesTable.starting_species()
	_check(species != null and GameState.record_species_completion_receipt(
			species.id, &"equipment_proc_mastery_root", 2)
		and GameState.get_species_mastery_progress(species.id) == 2,
		"one root-bound GameState receipt can award ordinary mastery plus one Echo point")
	_check(not GameState.record_species_completion_receipt(
			species.id, &"equipment_proc_mastery_root", 2)
		and GameState.get_species_mastery_progress(species.id) == 2,
		"the mastery writer rejects a duplicate root without another award")


func _test_shop_identity_copy() -> void:
	GameState.reset_to_defaults()
	var hud: Control = load("res://scenes/2d_management/yard_hud.tscn").instantiate()
	var definition := Shop.get_upgrade(&"tempered_woodsmans_axe")
	var shelf: Control = hud._build_shop_row(definition)
	var shelf_copy := _control_text(shelf)
	_check(shelf_copy.contains("Tempered Woodsman’s Axe")
		and shelf_copy.contains("Adds 1% split chance")
		and shelf_copy.contains("3% chance for a successful cut to make 1 extra cut")
		and not shelf_copy.to_lower().contains("proc")
		and not shelf_copy.to_lower().contains("dry-streak")
		and not shelf_copy.to_lower().contains("eligible event")
		and not shelf_copy.to_lower().contains("current gear + skill")
		and not shelf_copy.to_lower().contains("rank"),
		"an axe shelf card explains its gameplay effects without resolver terminology")
	GameState.apply_save_dict({"building_tiers": {"tempered_woodsmans_axe": 2}})
	var purchased: Control = hud._build_purchased_row(definition)
	var purchased_copy := _control_text(purchased)
	_check(purchased_copy.contains("Owned")
		and not purchased_copy.to_lower().contains("rank"),
		"a purchased axe identity appears separately as Owned without skill-upgrade wording")
	shelf.queue_free()
	purchased.queue_free()
	hud.queue_free()


func _test_stump_and_auxiliary_composition() -> void:
	GameState.reset_to_defaults()
	GameState.apply_save_dict({"building_tiers": {
		"iron_block_dogs": 2,
		"log_cradle": 2,
		"raised_split_stand": 2,
		"handcart_workshop": 5,
		"tool_care_bench": 5,
		"grading_lamp": 3,
		"customer_record_cabinet": 3,
		"supplier_holding_racks": 3,
		"xenowood_specimen_vise": 3,
	}})
	var active := Shop.active_equipment(UpgradeDef.EquipmentSlot.WORKSTATION)
	_check(active != null and active.id == &"raised_split_stand"
		and is_equal_approx(Shop.equipment_proc_chance(&"quick_study"), 0.05)
		and is_equal_approx(Shop.equipment_proc_chance(&"mastery_echo"), 0.03)
		and is_equal_approx(Shop.equipment_proc_chance(&"grain_read"), 0.005),
		"only the highest stump supplies each active Mastery proc profile")
	_check(is_equal_approx(Shop.total_effect(UpgradeDef.Effect.WORK_RADIUS), 0.07),
		"all owned stump work-radius contributions remain cumulative")
	_check(is_equal_approx(Shop.equipment_proc_chance(&"express_handoff"), 0.12)
		and is_equal_approx(Shop.equipment_proc_chance(&"follow_up"), 0.08),
		"four auxiliary ranks contribute 3-point Handoff and 2-point Follow-Up steps")
	_check(is_equal_approx(Shop.total_effect(UpgradeDef.Effect.CRAFT_TOLERANCE), 0.02)
		and is_equal_approx(Shop.total_effect(UpgradeDef.Effect.COMMISSION_REPUTATION), 2.0)
		and CompanyLogistics.supplier_queue_capacity()
			== CompanySimulation.config().supplier_queue_capacity + 12
		and is_equal_approx(Shop.total_effect(UpgradeDef.Effect.ALIEN_HANDLING), 0.04),
		"support purchases retain craftsmanship, reputation, logistics and alien-handling roles")
	GameState.apply_save_dict({"building_tiers": {
		"tempered_woodsmans_axe": 2,
		"forged_splitting_maul": 2,
		"steel_cheek_axe": 2,
		"journeymans_bearded_axe": 2,
		"hardwood_pattern_axe": 2,
	}})
	_check(ProgressionProcs.effective_chain_cap(&"double_strike") == 2
		and is_equal_approx(ProgressionProcs.effective_chance(&"double_strike"), 0.06),
		"the fifth named axe independently opens its authored Triple Strike profile")


func _test_gear_only_strike_and_follow_up() -> void:
	GameState.reset_to_defaults()
	GameState.apply_save_dict({"building_tiers": {
		"tempered_woodsmans_axe": 2,
		"tool_care_bench": 2,
	}})
	var mg: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	mg.debug_forced_species = 0
	mg.debug_forced_mesh = 0
	mg.debug_split_roll = 1
	mg.debug_force_proc = 1
	mg.auto_sell = false
	mg.orbs_enabled = false
	add_child(mg)
	await get_tree().process_frame
	var before: int = mg.piece_count()
	mg.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
	await get_tree().process_frame
	_check(SkillTree.get_level(&"double_strike") == 0
		and mg.debug_last_double_strike_cuts() == 1
		and mg.piece_count() == before + 2,
		"gear-only Double Strike performs one real bounded bonus cut")
	_check(mg.debug_last_follow_up_swings() <= 0,
		"a fired Strike chain has first refusal and suppresses Follow-Up on that root")
	mg.queue_free()
	await get_tree().process_frame

	GameState.reset_to_defaults()
	GameState.apply_save_dict({"building_tiers": {"tool_care_bench": 2}})
	var follow: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	follow.debug_forced_species = 0
	follow.debug_forced_mesh = 0
	follow.debug_split_roll = 0
	follow.debug_force_proc = 1
	follow.auto_sell = false
	follow.orbs_enabled = false
	add_child(follow)
	await get_tree().process_frame
	follow.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
	await get_tree().process_frame
	_check(SkillTree.get_level(&"follow_up") == 0
		and follow.debug_last_follow_up_swings() == 1
		and follow.debug_scar_count() == 2,
		"gear-only Follow-Up turns a failed root swing into one non-recursive bonus swing")
	follow.queue_free()
	await get_tree().process_frame


func _test_gear_only_mastery_grain_and_handoff() -> void:
	GameState.reset_to_defaults()
	GameState.apply_save_dict({"building_tiers": {
		"iron_block_dogs": 2,
		"log_cradle": 2,
		"handcart": 2,
		"handcart_workshop": 2,
	}})
	var mg: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	mg.debug_forced_species = 0
	mg.debug_forced_mesh = 0
	mg.debug_force_proc = 1
	mg.auto_sell = true
	mg.orbs_enabled = false
	add_child(mg)
	await get_tree().process_frame
	var species := SpeciesTable.starting_species()
	var base: int = species.xp_reward
	var awarded: int = mg.debug_award_log_xp_event(
		&"manual", &"gear_mastery_completion", true, false, base)
	var expected_xp := int(round(float(base * 2) * (1.0
		+ SpeciesMastery.total_effect(GameplayModifierDef.Kind.MANUAL_XP))))
	expected_xp = maxi(1, int(round(float(expected_xp) \
		* GameConfig.current().xp_pacing.global_xp_multiplier)))
	_check(SkillTree.get_level(&"quick_study") == 0
		and awarded == expected_xp
		and mg.debug_last_quick_study_bonus() == base
		and GameState.get_species_mastery_progress(species.id) == 2,
		"gear-only stump XP and Mastery Echo resolve independently on one manual root")
	_check(mg.debug_has_express_handoff_pending(),
		"gear-only Express Handoff queues exactly the next log")
	mg._spawn_fresh_log(false)
	_check(not mg.debug_has_express_handoff_pending()
		and is_equal_approx(mg.debug_last_log_arrival_ms(), 100.0),
		"Express Handoff is consumed once at the existing minimum arrival duration")
	mg.queue_free()
	await get_tree().process_frame

	GameState.reset_to_defaults()
	GameState.apply_save_dict({"building_tiers": {
		"iron_block_dogs": 2,
		"log_cradle": 2,
		"raised_split_stand": 2,
	}})
	var grain: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	grain.debug_forced_species = 0
	grain.debug_forced_mesh = 0
	grain.debug_force_grain = 1
	grain.auto_sell = false
	grain.orbs_enabled = false
	add_child(grain)
	await get_tree().process_frame
	_check(SkillTree.get_level(&"grain_reader") == 0 and grain.debug_has_grain_cue(),
		"gear-only Golden Grain uses the existing preflighted permanent mark path")
	grain.queue_free()
	await get_tree().process_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _control_text(root: Node) -> String:
	var text := ""
	if root is Label:
		text += (root as Label).text + "\n"
	for child: Node in root.get_children():
		text += _control_text(child)
	return text
