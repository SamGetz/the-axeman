extends Node
## FILE: res://core/tests/m7c_acceptance.gd
## ATTACHES TO: res://core/tests/m7c_acceptance.tscn. Not shipped.
##
## M7C grows slice by slice. Current groups cover save-v2 skill migration,
## typed content schemas/validators, the three-bough UI, Slice 5 Strength,
## Slice 6 Technique (Quick Study plus grain-reading feedback), and Slice 7
## Speed (Follow-Up plus Ready Stance's CHOP_SPEED wiring). Mastery and
## equipment loadout still have no gameplay.

const _FIXTURES := "res://core/tests/fixtures/"
const _BACKUP_PATH := "user://the_axeman_save.m7c_testbackup"

var _passes := 0
var _fails := 0


func _ready() -> void:
	print("=== M7C ACCEPTANCE — v14 ranked refund, typed 45-node graph and procs ===")
	_stash_real_save()
	_test_revised_skill_graph_contract()
	_test_typed_live_catalogues_validate()
	_test_skill_validator_rejects_bad_graphs()
	_test_content_validators_reject_bad_rows()
	_test_orphan_proc_validator_rejects_unowned_procs()
	_restore_real_save()
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	print("=== M7C RESULT: %d passed, %d failed ===" % [_passes, _fails])
	if _fails == 0:
		print("=== ALL M7C ACCEPTANCE CRITERIA PASS ===")
	get_tree().quit()


func _test_revised_skill_graph_contract() -> void:
	GameState.reset_to_defaults()
	var branch_counts := {&"strength": 0, &"speed": 0, &"mastery": 0, &"frontier": 0}
	var ranked_foundations := 0
	var total_ranks := 0
	for node: SkillNodeDef in SkillTree.get_nodes():
		branch_counts[node.branch_id] = int(branch_counts.get(node.branch_id, 0)) + 1
		total_ranks += node.max_level
		if node.node_type == SkillNodeDef.NodeType.FOUNDATION and node.max_level == 5:
			ranked_foundations += 1
	_check(SkillTree.get_nodes().size() == 45,
		"the replacement catalogue has exactly 45 nodes")
	_check(branch_counts == {&"strength": 12, &"speed": 12, &"mastery": 12, &"frontier": 9},
		"the replacement branch distribution is 12/12/12/9")
	_check(ranked_foundations == 12 and total_ranks == 93,
		"12 foundation nodes preserve the 84-rank core plus nine Frontier purchases")
	_check(SkillTree.get_revealed_nodes().size() == 36,
		"Frontier is completely absent before Earth Master")
	var curve := GameConfig.current().level_curve
	GameState.add_xp(curve.total_xp_for_level(10))
	_check(SkillTree.buy(&"specimen_handling") == -1,
		"the model rejects a hidden Frontier purchase, not just the HUD")
	var migrated := SaveSystem._migrate({
		"xp": curve.total_xp_for_level(10), "cash": 77,
		"skill_levels": {"strong_arms": 4}, "legacy_skill_ranks": {"strong_arms": 2},
		"proc_dry_streak": {"quick_study": 5},
	}, 12)
	_check((migrated.get("skill_levels", {}) as Dictionary).is_empty()
		and (migrated.get("legacy_skill_ranks", {}) as Dictionary).is_empty(),
		"v13 applies the approved full node and legacy-cost refund")
	_check((migrated.get("proc_dry_streak", {}) as Dictionary).is_empty()
		and int(migrated.get("cash", 0)) == 77,
		"v13 clears affected proc streaks without retroactive cash")


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("PASS: " + label)
	else:
		_fails += 1
		print("FAIL: " + label)


func _fixture_progression(name: String) -> Dictionary:
	var cfg := ConfigFile.new()
	var err := cfg.load(_FIXTURES + name)
	_check(err == OK, "hand-authored fixture %s parses" % name)
	var data: Variant = cfg.get_value("progression", "data", {})
	return data as Dictionary if data is Dictionary else {}


func _test_all_mappings_and_exact_refunds() -> void:
	var migrated := SaveSystem._migrate(
		_fixture_progression("m7c_v1_all_skill_mappings.cfg"), 1)
	var skills: Dictionary = migrated.get("skill_levels", {})
	var legacy: Dictionary = migrated.get("legacy_skill_ranks", {})
	_check(skills.get("strong_arms", 0) == 3, "Strong Arms retains all 3 valid ranks")
	_check(skills.get("quick_hands", 0) == 4, "Quick Hands retains all 4 valid ranks")
	_check(skills.get("ready_stance", 0) == 2 and not skills.has("keen_edge"),
		"Keen Edge renames to Ready Stance without leaving its old id")
	_check(skills.get("quick_study", 0) == 2 and not skills.has("woodsman"),
		"Woodsman renames to Quick Study without leaving its old id")
	_check(not skills.has("splitter"), "Splitter is retired, never converted to Double Strike")
	_check(not skills.has("double_strike"), "migration does not silently award Double Strike")
	_check(not skills.has("master_axeman") and not skills.has("negotiator"),
		"Master Axeman and Negotiator remain absent from the current save shape")
	_check(legacy == {"strong_arms": 3, "quick_hands": 4, "ready_stance": 2, "quick_study": 2},
		"retained ranks carry their exact prototype-cost basis")

	GameState.apply_save_dict(migrated)
	_check(GameState.get_skill_points_spent() == 17,
		"retained ranks spend exactly 17 prototype points")
	_check(GameState.get_skill_points_available() == 81,
		"the removed 16-point spend is refunded through the derived balance (81 available)")


func _test_duplicates_caps_and_corrupt_ranks() -> void:
	var migrated := SaveSystem._migrate(
		_fixture_progression("m7c_v1_duplicate_caps_corrupt.cfg"), 1)
	var skills: Dictionary = migrated.get("skill_levels", {})
	_check(skills.get("ready_stance", 0) == 5,
		"old/new Ready Stance ids keep the greater rank and clamp to cap 5")
	_check(skills.get("quick_study", 0) == 4,
		"old/new Quick Study ids keep the greater rank, never add to 6")
	_check(not skills.has("strong_arms"), "a non-numeric retained rank is dropped safely")
	_check(not skills.has("splitter") and not skills.has("negotiator"),
		"negative retired/corrupt ranks cannot survive migration")


func _test_partial_fixture_and_idempotence() -> void:
	var original := _fixture_progression("m7c_v1_partial.cfg")
	var migrated := SaveSystem._migrate(original, 1)
	_check(migrated.get("cash", 0) == 73, "unrelated progression survives migration unchanged")
	_check((migrated.get("skill_levels", {}) as Dictionary).get("ready_stance", 0) == 1,
		"a partial skill dictionary migrates its one known rank")
	var twice := SaveSystem._migrate(migrated.duplicate(true), SaveSystem.SAVE_VERSION)
	_check(twice == migrated, "a current-version dictionary is byte-shape idempotent")
	var malformed := SaveSystem._migrate({"skill_levels": ["not", "a", "dictionary"]}, 1)
	_check(malformed.get("skill_levels", null) == {}, "a malformed skill field degrades to an empty tree")


func _test_load_save_reload_and_source_preservation() -> void:
	SaveSystem.delete_save()
	var fixture := ConfigFile.new()
	_check(fixture.load(_FIXTURES + "m7c_v1_all_skill_mappings.cfg") == OK,
		"round-trip fixture opens")
	_check(fixture.save(SaveSystem.SAVE_PATH) == OK, "version-1 fixture is installed as the live test save")

	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	_check(SaveSystem.load_game() == SaveSystem.LoadResult.OK, "a version-1 file loads through migration")
	_check(GameState.get_skill_level(&"ready_stance") == 2
		and GameState.get_skill_level(&"quick_study") == 2,
		"renamed ranks are live after the complete state validates")
	var untouched := ConfigFile.new()
	untouched.load(SaveSystem.SAVE_PATH)
	_check(int(untouched.get_value("meta", "version", -1)) == 1,
		"loading leaves the original version-1 file untouched")

	_check(SaveSystem.save_game(), "the next atomic save succeeds")
	var upgraded := ConfigFile.new()
	upgraded.load(SaveSystem.SAVE_PATH)
	_check(int(upgraded.get_value("meta", "version", -1)) == SaveSystem.SAVE_VERSION,
		"only that successful save replaces it with the current version")
	GameState.reset_to_defaults()
	_check(SaveSystem.load_game() == SaveSystem.LoadResult.OK, "the current-version save reloads")
	_check(GameState.get_skill_level(&"ready_stance") == 2
		and GameState.get_skill_level(&"quick_study") == 2,
		"renamed ranks survive load-save-reload")
	_check(GameState.get_skill_points_spent() == 17,
		"prototype cost basis survives load-save-reload exactly")


func _test_typed_live_catalogues_validate() -> void:
	var branches := M7CContent.branches()
	var procs := M7CContent.procs()
	var mastery := M7CContent.mastery()
	var equipment := M7CContent.equipment()
	_check(branches != null and branches.branches.size() == 4,
		"the live catalogue retains the three terrestrial branches plus the provisional Frontier branch")
	_check(procs != null and procs.procs.size() == 6
		and procs.by_id(&"double_strike") != null
		and procs.by_id(&"follow_up") != null
		and procs.by_id(&"quick_study") != null
		and procs.by_id(&"grain_read") != null
		and procs.by_id(&"mastery_echo") != null
		and procs.by_id(&"express_handoff") != null,
		"skill and equipment proc families are typed catalogue rows")
	_check(mastery != null and mastery.definitions.size() == SpeciesTable.count(),
		"every live species has one mastery-schema row (%d)" % SpeciesTable.count())
	_check(equipment != null and equipment.equipment.size() == 20,
		"starting/M7A gear plus eight named axes and eight named stumps have typed rows")
	_check(equipment.starting_for_slot(EquipmentDef.Slot.AXE).id == &"basic_axe"
		and equipment.starting_for_slot(EquipmentDef.Slot.WORKSTATION).id == &"basic_chopping_block",
		"both loadout slots have explicit safe starting fallbacks")
	var errors := M7CContent.validate_all()
	_check(errors.is_empty(), "all shipping M7C resources validate (%s)" % str(errors))
	var quick_study := SkillTree.get_node_def(&"quick_study")
	_check(quick_study != null
		and quick_study.branch_id == &"mastery"
		and quick_study.node_type == SkillNodeDef.NodeType.PROC
		and quick_study.proc_id == &"quick_study",
		"skill meaning comes from typed branch/node/proc fields, not display copy")


func _test_skill_validator_rejects_bad_graphs() -> void:
	var branches := M7CContent.branches()
	var procs := M7CContent.procs()

	var duplicate := SkillTreeTable.new()
	var duplicate_node := _test_skill(&"same")
	duplicate.nodes = [duplicate_node, duplicate_node]
	_check(_has_error(M7CContent.validate_skill_tree(duplicate, branches, procs), "duplicate skill id"),
		"tree validation rejects duplicate ids")

	var dangling := SkillTreeTable.new()
	var dangling_node := _test_skill(&"dangling")
	dangling_node.requires = [&"missing"]
	dangling.nodes = [dangling_node]
	_check(_has_error(M7CContent.validate_skill_tree(dangling, branches, procs), "dangling prerequisite"),
		"tree validation rejects dangling prerequisites")

	var cycle := SkillTreeTable.new()
	var cycle_a := _test_skill(&"cycle_a")
	var cycle_b := _test_skill(&"cycle_b")
	cycle_a.requires = [&"cycle_b"]
	cycle_b.requires = [&"cycle_a"]
	cycle.nodes = [cycle_a, cycle_b]
	_check(_has_error(M7CContent.validate_skill_tree(cycle, branches, procs), "prerequisite cycle"),
		"tree validation rejects cycles")

	var illegal := SkillTreeTable.new()
	var illegal_node := _test_skill(&"illegal")
	illegal_node.node_type = 99
	illegal_node.max_level = 0
	illegal_node.cost = 0
	illegal_node.branch_id = &"unknown_branch"
	illegal_node.presentation_position = Vector2i(99, 99)
	illegal.nodes = [illegal_node]
	var illegal_errors := M7CContent.validate_skill_tree(illegal, branches, procs)
	_check(_has_error(illegal_errors, "illegal node type"), "tree validation rejects illegal node types")
	_check(_has_error(illegal_errors, "unknown branch"), "tree validation rejects unknown branches")
	_check(_has_error(illegal_errors, "invalid cap") and _has_error(illegal_errors, "invalid cost"),
		"tree validation rejects invalid caps and costs")

	var layout := SkillTreeTable.new()
	var layout_node := _test_skill(&"off_bough")
	layout_node.presentation_position = Vector2i(99, 99)
	layout.nodes = [layout_node]
	_check(_has_error(M7CContent.validate_skill_tree(layout, branches, procs), "impossible layout"),
		"tree validation rejects impossible bough layout references")


func _test_content_validators_reject_bad_rows() -> void:
	var branch_table := SkillBranchTable.new()
	var bad_branch := SkillBranchDef.new()
	bad_branch.id = &"duplicate_branch"
	bad_branch.layout_slots = [Vector2i.ZERO, Vector2i.ZERO]
	branch_table.branches = [bad_branch, bad_branch]
	var branch_errors := M7CContent.validate_branches(branch_table)
	_check(_has_error(branch_errors, "duplicate branch id")
		and _has_error(branch_errors, "empty display name")
		and _has_error(branch_errors, "duplicate layout slot"),
		"branch validation rejects duplicate ids, missing copy and duplicate slots")

	var proc_table := ProcTable.new()
	var bad_proc := ProcDef.new()
	bad_proc.id = &"bad_proc"
	bad_proc.display_name = "Bad Proc"
	bad_proc.announcement_key = &""
	bad_proc.base_chance = 2.0
	bad_proc.chain_cap = 0
	bad_proc.bad_luck_bound = 0
	proc_table.procs = [bad_proc, bad_proc]
	var proc_errors := M7CContent.validate_procs(proc_table)
	_check(_has_error(proc_errors, "duplicate proc id")
		and _has_error(proc_errors, "invalid chance")
		and _has_error(proc_errors, "invalid chain cap")
		and _has_error(proc_errors, "invalid bad-luck policy")
		and _has_error(proc_errors, "no announcement key"),
		"proc validation rejects duplicate and unsafe resolver data")

	var mastery_table := SpeciesMasteryTable.new()
	var bad_mastery := SpeciesMasteryDef.new()
	bad_mastery.species_id = &"invented_wood"
	bad_mastery.mastery_target = 2
	bad_mastery.manual_completion_award = 0
	var bad_threshold := SpeciesMasteryThresholdDef.new()
	bad_threshold.required_progress = 2
	bad_threshold.rewards = []
	var backwards_threshold := SpeciesMasteryThresholdDef.new()
	backwards_threshold.required_progress = 1
	backwards_threshold.rewards = []
	mastery_table.thresholds = [bad_threshold, backwards_threshold]
	var bad_requirement := CertificationRequirementDef.new()
	bad_requirement.kind = 99
	bad_requirement.required_count = 0
	var bad_requirements: Array[CertificationRequirementDef] = [bad_requirement]
	bad_mastery.certification_requirements = bad_requirements
	mastery_table.definitions = [bad_mastery, bad_mastery]
	var mastery_errors := M7CContent.validate_mastery(mastery_table)
	_check(_has_error(mastery_errors, "duplicate mastery species")
		and _has_error(mastery_errors, "unknown species")
		and _has_error(mastery_errors, "invalid target/award")
		and _has_error(mastery_errors, "invalid threshold")
		and _has_error(mastery_errors, "illegal certification requirement"),
		"mastery validation rejects duplicate, unknown, unordered and illegal requirements")

	var equipment_table := EquipmentTable.new()
	var bad_equipment := EquipmentDef.new()
	bad_equipment.id = &"bad_equipment"
	bad_equipment.slot = 99
	bad_equipment.ownership_upgrade_id = &"invented_purchase"
	var bad_modifier := GameplayModifierDef.new()
	bad_modifier.kind = 99
	bad_modifier.operation = 99
	bad_modifier.magnitude = NAN
	bad_modifier.tuning_status = ""
	var bad_modifiers: Array[GameplayModifierDef] = [bad_modifier]
	bad_equipment.modifiers = bad_modifiers
	equipment_table.equipment = [bad_equipment, bad_equipment]
	var equipment_errors := M7CContent.validate_equipment(equipment_table)
	_check(_has_error(equipment_errors, "duplicate equipment id")
		and _has_error(equipment_errors, "illegal slot")
		and _has_error(equipment_errors, "unknown ownership upgrade")
		and _has_error(equipment_errors, "no comparison tags")
		and _has_error(equipment_errors, "starting fallbacks")
		and _has_error(equipment_errors, "modifier with illegal kind")
		and _has_error(equipment_errors, "modifier with illegal operation")
		and _has_error(equipment_errors, "non-finite magnitude"),
		"equipment/modifier validation rejects duplicate, unknown, uncomparable and unsafe rows")


func _test_three_bough_skill_ui() -> void:
	GameState.reset_to_defaults()
	var hud: Control = load("res://scenes/2d_management/yard_hud.tscn").instantiate()
	add_child(hud)
	await get_tree().process_frame
	hud.get_node("QuickMenu/SkillsButton").pressed.emit()
	await get_tree().process_frame

	var panel: PanelContainer = hud.get_node("SkillPanel")
	var boughs: HBoxContainer = hud.get_node("SkillPanel/Column/SkillBody/BoughScroll/Boughs")
	var detail_title: Label = hud.get_node("SkillPanel/Column/SkillBody/DetailPanel/Column/Title")
	var detail_status: Label = hud.get_node("SkillPanel/Column/SkillBody/DetailPanel/Column/Status")
	_check(panel.visible and boughs.get_child_count() == 4,
		"Skills opens as four native boughs over the chopping view")
	var branch_ids: Array[StringName] = []
	for bough: Control in boughs.get_children():
		branch_ids.append(StringName(bough.get_meta("branch_id", &"")))
	_check(branch_ids == [&"strength", &"speed", &"technique", &"frontier"],
		"bough order and identity come from the authored branch table")
	_check(panel.position.x >= 0.0 and panel.position.y >= 0.0
		and panel.position.x + panel.size.x <= 1280.0
		and panel.position.y + panel.size.y <= 720.0,
		"the full skill window fits inside the shipping 1280x720 viewport (%s / %s)"
			% [panel.position, panel.size])

	var strong := _find_skill_button(hud, &"strong_arms")
	var ready := _find_skill_button(hud, &"ready_stance")
	var study := _find_skill_button(hud, &"quick_study")
	_check(strong != null and ready != null and study != null,
		"all three boughs expose their typed live nodes")
	_check(strong.get_meta("skill_state") == "insufficient"
		and ready.get_meta("skill_state") == "locked"
		and study.get_meta("skill_state") == "insufficient",
		"fresh-state cards distinguish insufficient points from prerequisites")

	_check(hud.debug_select_skill(&"ready_stance"), "a locked node can be selected for explanation")
	_check(detail_title.text == "Ready Stance" and detail_status.text.contains("prerequisite"),
		"selected-node detail explains the lock instead of hiding the node")

	var curve := GameConfig.current().level_curve
	GameState.add_xp(curve.total_xp_for_level(2))
	await get_tree().process_frame
	strong = _find_skill_button(hud, &"strong_arms")
	_check(strong.get_meta("skill_state") == "available",
		"earning one point repaints Strong Arms as available")
	hud.debug_select_skill(&"strong_arms")
	var detail_buy: Button = hud.get_node("SkillPanel/Column/SkillBody/DetailPanel/Column/BuyButton")
	_check(not detail_buy.disabled and detail_buy.text.contains("Learn rank 1"),
		"selected-node detail offers the affordable rank")
	detail_buy.pressed.emit()
	await get_tree().process_frame
	strong = _find_skill_button(hud, &"strong_arms")
	_check(SkillTree.get_level(&"strong_arms") == 1
		and strong.get_meta("skill_state") == "learned",
		"buying through detail records and repaints the learned state")

	var respec_notice: Label = hud.get_node("SkillPanel/Column/RespecNotice")
	_check(respec_notice.text.contains("confirmation") and respec_notice.text.contains("pending"),
		"free respec is disclosed without inventing unapproved confirmation copy")
	hud.queue_free()
	await get_tree().process_frame
	GameState.reset_to_defaults()


func _find_skill_button(hud: Control, id: StringName) -> Button:
	for candidate: Node in hud.find_children("*", "Button", true, false):
		if candidate.get_meta("skill_id", &"") == id:
			return candidate as Button
	return null


# ------------------------------------------------- M7C Slice 5: Double Strike
## Routes every skill purchase through the REAL GameState.add_xp + SkillTree.buy
## path, never a direct set_skill_level poke — a test can never grant a rank
## the actual game could not have sold.
func _grant_double_strike_chain(with_modifier: bool) -> void:
	var curve := GameConfig.current().level_curve
	GameState.add_xp(curve.total_xp_for_level(7))
	_check(SkillTree.buy(&"strong_arms") == 1, "test setup: Strong Arms bought")
	_check(SkillTree.buy(&"double_strike") == 1, "test setup: Double Strike bought")
	if with_modifier:
		_check(SkillTree.buy(&"steady_continuation") == 1, "test setup: Steady Continuation bought")


func _make_double_strike_minigame() -> Node3D:
	var mg: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	mg.debug_forced_species = 0
	mg.debug_split_roll = 1      # the primary swing always cleaves — tests the proc, not the roll
	mg.debug_force_proc = 1      # Double Strike always fires when it is rolled at all
	mg.auto_sell = false
	add_child(mg)
	await get_tree().process_frame
	return mg


## Group 1 of the brief's acceptance matrix: forced Double Strike performs
## exactly the announced valid slicer operations, stops at the learned AND the
## global safety cap, and refuses a continuation with no valid geometry left —
## all without ever rolling (no fairness state spent) when there is nothing to
## roll for.
func _test_double_strike_forced_geometry_and_caps() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	_grant_double_strike_chain(false)

	var mg := await _make_double_strike_minigame()
	var before: int = mg.piece_count()
	var split: bool = mg.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
	await get_tree().process_frame
	_check(split, "test setup: the primary swing splits the fresh log")
	_check(mg.debug_last_double_strike_cuts() == 1,
		"a forced, owned Double Strike performs exactly one bonus cut on a fresh log")
	_check(mg.piece_count() == before + 2,
		"...two real slices landed this swing, not one (%d -> %d)" % [before, mg.piece_count()])
	mg.queue_free()
	await get_tree().process_frame

	# Global safety cap, independent of the learned chain_cap (already 1 in the
	# shipping data): zeroing it must refuse every bonus cut even forced+owned.
	var mg2 := await _make_double_strike_minigame()
	mg2.global_proc_chain_cap = 0
	var before2: int = mg2.piece_count()
	mg2.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
	await get_tree().process_frame
	_check(mg2.debug_last_double_strike_cuts() == 0,
		"a zeroed global cap refuses every bonus cut even though the proc is forced on")
	_check(mg2.piece_count() == before2 + 1,
		"...only the primary split landed (%d -> %d)" % [before2, mg2.piece_count()])
	mg2.queue_free()
	await get_tree().process_frame

	# No useful geometry: force BOTH halves of the primary split to classify as
	# firewood (fly off) rather than staying on the block, so the continuation
	# has nothing left to target.
	var mg3 := await _make_double_strike_minigame()
	mg3.min_vol = 1000.0   # every piece, however large, reads as firewood
	var streak_before := GameState.get_proc_dry_streak(&"double_strike")
	mg3.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
	await get_tree().process_frame
	_check(mg3.cuttable_count() == 0,
		"test setup: the primary split left nothing on the block to continue onto")
	_check(mg3.debug_last_double_strike_cuts() == 0,
		"the absence of useful geometry stops the chain before any bonus cut")
	_check(GameState.get_proc_dry_streak(&"double_strike") == streak_before,
		"...and it was never even rolled — no fairness state spent on a cut that could not execute")
	mg3.queue_free()
	await get_tree().process_frame

	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})


## Group 5 of the brief's acceptance matrix: the precision guard suppresses
## bonus cuts with no penalty and no fairness spend, and does not touch the
## base swing — unless an owned modifier (Steady Continuation) explicitly
## makes Double Strike safe during precision work, exactly as the brief's
## fairness contract specifies.
func _test_double_strike_precision_guard() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	_grant_double_strike_chain(false)   # owns Double Strike, NOT the modifier

	var mg := await _make_double_strike_minigame()
	mg.debug_set_precision_guard(true)
	var streak_before := GameState.get_proc_dry_streak(&"double_strike")
	var before: int = mg.piece_count()
	mg.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
	await get_tree().process_frame
	_check(mg.debug_last_double_strike_cuts() == 0,
		"the precision guard suppresses the bonus cut even with the proc forced on")
	_check(mg.piece_count() == before + 1,
		"...the base swing itself still landed normally, untouched by the guard")
	_check(GameState.get_proc_dry_streak(&"double_strike") == streak_before,
		"...and suppression spent no fairness state — the roll never happened")
	mg.queue_free()
	await get_tree().process_frame
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})

	# An owned modifier explicitly makes it safe again.
	_grant_double_strike_chain(true)
	var mg2 := await _make_double_strike_minigame()
	mg2.debug_set_precision_guard(true)
	var before2: int = mg2.piece_count()
	mg2.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
	await get_tree().process_frame
	_check(mg2.debug_last_double_strike_cuts() == 1,
		"Steady Continuation lets Double Strike proceed even during precision work")
	_check(mg2.piece_count() == before2 + 2,
		"...both the primary and the bonus cut landed (%d -> %d)" % [before2, mg2.piece_count()])
	mg2.queue_free()
	await get_tree().process_frame
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})


## Group 6 of the brief's acceptance matrix: bounded bad-luck protection
## reaches its bound, persists across save/load (so a reload cannot cheaply
## reroll it), and a save whose streak now exceeds the CURRENT bound is
## reclamped rather than left in an impossible state. Pure ProcResolver/
## GameState logic — no scene needed, so RNG is only ever exercised for the
## single "a real roll at the bound is guaranteed" assertion.
func _test_double_strike_bad_luck_bound_and_persistence() -> void:
	GameState.reset_to_defaults()
	var proc_def: ProcDef = M7CContent.procs().by_id(&"double_strike")
	_check(proc_def != null, "test setup: the double_strike proc is registered")
	if proc_def == null:
		return

	for i in range(proc_def.bad_luck_bound - 1):
		var fired: bool = ProcResolver.should_proc(proc_def, 0)   # forced fail; still recorded
		_check(not fired, "forced-fail roll %d of %d does not fire" % [i + 1, proc_def.bad_luck_bound - 1])
	_check(GameState.get_proc_dry_streak(&"double_strike") == proc_def.bad_luck_bound - 1,
		"the dry streak climbed to one short of the bound (%d)" % (proc_def.bad_luck_bound - 1))

	var pity: bool = ProcResolver.should_proc(proc_def)   # a REAL roll, not forced
	_check(pity, "a real roll at the bad-luck bound is guaranteed to fire (pity)")
	_check(GameState.get_proc_dry_streak(&"double_strike") == 0,
		"...and firing resets the streak")

	for i in range(proc_def.bad_luck_bound - 2):
		ProcResolver.should_proc(proc_def, 0)
	var streak_before := GameState.get_proc_dry_streak(&"double_strike")
	_check(streak_before == proc_def.bad_luck_bound - 2, "rebuilt streak before save (%d)" % streak_before)

	var saved := GameState.to_save_dict()
	GameState.reset_to_defaults()
	_check(GameState.get_proc_dry_streak(&"double_strike") == 0, "a fresh save starts with no streak")
	GameState.apply_save_dict(saved)
	_check(GameState.get_proc_dry_streak(&"double_strike") == streak_before,
		"loading the save restores the exact streak — reload cannot cheaply reroll it")

	# A streak beyond the CURRENT bound (e.g. a retuned-down bound, or a
	# corrupted field) is reclamped on load, never left impossible.
	var tampered := saved.duplicate(true)
	tampered["proc_dry_streak"] = {"double_strike": 999}
	GameState.apply_save_dict(tampered)
	_check(GameState.get_proc_dry_streak(&"double_strike") == proc_def.bad_luck_bound,
		"an oversized streak is clamped to the current bound on load, never left impossible")

	GameState.reset_to_defaults()


## Group 3 of the brief's acceptance matrix: the same skill points spent in a
## different branch produce measurably different eligible behavior. Double
## Strike is available only when OWNED — forcing the proc without owning it
## must never fire, whether the player has spent no points at all or has spent
## the identical number of points entirely in Speed instead.
func _test_double_strike_requires_ownership() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})

	_check(SkillTree.get_level(&"double_strike") == 0, "test setup: Double Strike starts unowned")
	var mg := await _make_double_strike_minigame()
	var before: int = mg.piece_count()
	mg.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
	await get_tree().process_frame
	_check(mg.debug_last_double_strike_cuts() == 0,
		"an unlearned Double Strike never fires, however hard the proc is forced")
	_check(mg.piece_count() == before + 1, "...only the ordinary split landed")
	_check(GameState.get_proc_dry_streak(&"double_strike") == 0,
		"...and an unowned proc is never even rolled — no fairness state spent")
	mg.queue_free()
	await get_tree().process_frame
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})

	# The SAME number of points (4), spent entirely in Speed instead.
	var curve := GameConfig.current().level_curve
	GameState.add_xp(curve.total_xp_for_level(5))
	for i in range(4):
		SkillTree.buy(&"quick_hands")
	_check(SkillTree.get_level(&"quick_hands") == 4, "test setup: 4 points spent entirely in Speed")
	_check(SkillTree.get_level(&"double_strike") == 0,
		"spending points off-branch does not grant an unlearned Strength proc")

	var mg2 := await _make_double_strike_minigame()
	var before2: int = mg2.piece_count()
	mg2.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
	await get_tree().process_frame
	_check(mg2.debug_last_double_strike_cuts() == 0,
		"...so the identical forced proc still performs zero bonus cuts")
	_check(mg2.piece_count() == before2 + 1, "...only the ordinary split landed")
	mg2.queue_free()
	await get_tree().process_frame

	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})


# --------------------------------------------- M7C Slice 6: Technique vertical
func _grant_quick_study() -> void:
	var curve := GameConfig.current().level_curve
	GameState.add_xp(curve.total_xp_for_level(4))
	_check(SkillTree.buy(&"quick_study") == 1, "test setup: Quick Study bought")


func _quick_study_multiplier() -> float:
	return _manual_xp_multiplier_for(&"quick_study")


## The gold grain mark's own payout multiplier (proc_table.tres's separate
## `grain_read` proc) — DELIBERATELY NOT the same helper call as Quick Study's
## multiplier: they are two distinct procs with two distinct authored numbers
## (2x vs 3x today), and conflating them would let a test pass while reading the
## wrong data.
func _grain_read_multiplier() -> float:
	return _manual_xp_multiplier_for(&"grain_read")


func _manual_xp_multiplier_for(proc_id: StringName) -> float:
	var proc_def: ProcDef = M7CContent.procs().by_id(proc_id)
	if proc_def == null:
		return 1.0
	for modifier: GameplayModifierDef in proc_def.modifiers:
		if modifier != null \
				and modifier.kind == GameplayModifierDef.Kind.MANUAL_XP \
				and modifier.operation == GameplayModifierDef.Operation.MULTIPLY:
			return modifier.magnitude
	return 1.0


func _make_quick_study_minigame(owns_skill := true) -> Node3D:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	if owns_skill:
		_grant_quick_study()
	var mg: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	mg.debug_forced_species = 0
	mg.debug_forced_mesh = 0
	mg.debug_split_roll = 1
	mg.debug_force_proc = 1
	# NEVER by default: the grain-cue tests flip this to 1 themselves, after
	# construction, on whichever fresh piece they want marked. Left at the real
	# roll's negligible base_chance here would make the Quick Study tests below
	# flaky, and forcing it ON by default would silently add a second, unwanted
	# XP transaction on top of every Quick Study assertion's exact XP delta.
	mg.debug_force_grain = 0
	mg.auto_sell = true
	mg.orbs_enabled = false
	add_child(mg)
	await get_tree().process_frame
	return mg


## Group 7 of the brief's acceptance matrix: one forced, owned Quick Study is a
## multiplier on ONE manual completed-log root. The award is one transaction,
## the corresponding ProcBurst uses Technique's authored branch colour, and an
## unowned skill can neither roll nor add bonus XP.
func _test_quick_study_manual_completion_event() -> void:
	var multiplier := _quick_study_multiplier()
	_check(multiplier > 1.0,
		"Quick Study's manual-XP multiplier is typed placeholder data, not a code literal")

	var mg := await _make_quick_study_minigame(true)
	var has_seams := mg.has_method("debug_last_quick_study_bonus") \
		and mg.has_method("debug_last_quick_study_root_id")
	_check(has_seams, "Quick Study exposes the completed root/bonus receipt for acceptance")
	var base: int = SpeciesTable.at(0).xp_reward
	var before := GameState.get_xp()
	mg.min_vol = 1000.0   # one split empties the block: one manually completed log
	mg.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
	await get_tree().process_frame
	var expected_total := int(round(float(base) * multiplier))
	_check(GameState.get_xp() - before == expected_total,
		"forced Quick Study multiplies the base XP once (%d x %.3f = %d)"
			% [base, multiplier, expected_total])
	_check(has_seams and mg.debug_last_quick_study_bonus() == expected_total - base,
		"the receipt separates base XP from the one non-recursive Quick Study bonus")
	_check(has_seams and mg.debug_last_quick_study_root_id() != &"",
		"the manual completion owns one explicit root event id")
	var technique := SkillTree.branch_for_proc(&"quick_study")
	_check(technique != null and mg.debug_last_proc_burst_color().is_equal_approx(technique.color),
		"Quick Study announces through ProcBurst in the authored Technique branch colour")
	mg.queue_free()
	await get_tree().process_frame

	var unowned := await _make_quick_study_minigame(false)
	base = SpeciesTable.at(0).xp_reward
	before = GameState.get_xp()
	unowned.min_vol = 1000.0
	unowned.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
	await get_tree().process_frame
	_check(GameState.get_xp() - before == base,
		"an unowned Quick Study awards ordinary base XP only")
	_check(GameState.get_proc_dry_streak(&"quick_study") == 0,
		"an unowned Quick Study is never rolled and spends no fairness state")
	unowned.queue_free()
	await get_tree().process_frame
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})


## Eligibility/root guards are driven through a narrow debug seam over the SAME
## completion transaction used by live play. Every excluded source must do
## literally nothing: no XP, no ProcResolver fairness mutation, no announcement.
func _test_quick_study_source_and_once_guards() -> void:
	var mg := await _make_quick_study_minigame(true)
	var has_seam := mg.has_method("debug_award_log_xp_event")
	_check(has_seam, "acceptance can inject typed manual/automation/restore completion roots")
	if not has_seam:
		_check(false, "one root id cannot award or roll Quick Study twice")
		_check(false, "Quick Study cannot recurse from its own bonus event")
		_check(false, "automation cannot award or multiply Axeman XP")
		_check(false, "a loaded/restored log cannot award or trigger Quick Study")
		_check(false, "incomplete work cannot award or trigger Quick Study")
		mg.queue_free()
		await get_tree().process_frame
		return

	var base: int = SpeciesTable.at(0).xp_reward
	var multiplier := _quick_study_multiplier()
	var before := GameState.get_xp()
	mg.debug_award_log_xp_event(&"manual", &"acceptance_manual_root", true, false, base)
	var after_once := GameState.get_xp()
	var streak_once := GameState.get_proc_dry_streak(&"quick_study")
	mg.debug_award_log_xp_event(&"manual", &"acceptance_manual_root", true, false, base)
	_check(after_once - before == int(round(float(base) * multiplier))
		and GameState.get_xp() == after_once
		and GameState.get_proc_dry_streak(&"quick_study") == streak_once,
		"one root id cannot award or roll Quick Study twice")

	before = GameState.get_xp()
	var streak_before := GameState.get_proc_dry_streak(&"quick_study")
	mg.debug_award_log_xp_event(&"manual", &"acceptance_bonus", true, true, base)
	_check(GameState.get_xp() == before
		and GameState.get_proc_dry_streak(&"quick_study") == streak_before,
		"Quick Study cannot recurse from its own bonus event")

	for excluded: Dictionary in [
		{"source": &"automation", "root": &"acceptance_auto", "label": "automation cannot award or multiply Axeman XP"},
		{"source": &"restored", "root": &"acceptance_restore", "label": "a loaded/restored log cannot award or trigger Quick Study"},
	]:
		before = GameState.get_xp()
		streak_before = GameState.get_proc_dry_streak(&"quick_study")
		mg.debug_award_log_xp_event(excluded.source, excluded.root, true, false, base)
		_check(GameState.get_xp() == before
			and GameState.get_proc_dry_streak(&"quick_study") == streak_before,
			excluded.label)
	before = GameState.get_xp()
	streak_before = GameState.get_proc_dry_streak(&"quick_study")
	mg.debug_award_log_xp_event(&"manual", &"acceptance_restore", true, false, base)
	_check(GameState.get_xp() == before
		and GameState.get_proc_dry_streak(&"quick_study") == streak_before,
		"a restored root cannot be resubmitted later wearing a manual source")

	before = GameState.get_xp()
	streak_before = GameState.get_proc_dry_streak(&"quick_study")
	mg.debug_award_log_xp_event(&"manual", &"acceptance_incomplete", false, false, base)
	_check(GameState.get_xp() == before
		and GameState.get_proc_dry_streak(&"quick_study") == streak_before,
		"incomplete work cannot award or trigger Quick Study")

	mg.queue_free()
	await get_tree().process_frame
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})


## Group 11, REWORKED 2026-08-04 (Creative Director call): the grain opportunity
## is no longer an ephemeral cue that forces a camera turn and pops for ~150ms.
## It is a PERMANENT gold mark, rolled ONCE per log through the same ProcResolver
## every other named chance event uses, that cuts exactly along its own
## preflighted plane with no forced turn, always splits, and pays a big XP bonus
## plus a Technique-green ProcBurst. This group first ran red against the
## pre-rework code (recorded below) before any fix landed.
func _test_grain_cue_validity_and_cleanup() -> void:
	var mg := await _make_quick_study_minigame(true)
	var methods := [
		"debug_has_grain_cue", "debug_grain_plane_valid", "debug_grain_top_mark_count",
		"debug_grain_cue_color", "debug_invalidate_grain_candidate", "debug_grain_clear_reason",
		"debug_last_grain_bonus", "debug_grain_offer_count", "debug_hold_grain_cue",
	]
	var has_seams := true
	for method: String in methods:
		has_seams = has_seams and mg.has_method(method)
	_check(has_seams, "grain-cue acceptance seams expose geometry, colour, latch and reward receipts")
	if not has_seams:
		_check(false, "a forced offer places a slicer-valid candidate on a fresh piece")
		_check(false, "the mark is three raised layers: dark outline, glow, gold core")
		_check(false, "the mark's authored gold differs from the Technique branch colour")
		_check(false, "no screen-space overlay exists any more")
		_check(false, "the mark is PERMANENT — it outlives the old ceiling and any animator settle")
		_check(false, "clicking the mark never fires the forced cross-axis camera turn")
		_check(false, "the cut lands on the mark's own preflighted plane, not a re-biased one")
		_check(false, "taking the mark always splits, banks a multiplied XP bonus, and reads consumed")
		_check(false, "a gold swing splits even when the ordinary roll would have failed")
		_check(false, "debug_force_grain = 0 never offers a mark, across several fresh logs")
		_check(false, "the offer latches off after the first placement — no second mark this log")
		_check(false, "a forced offer still spends real ProcResolver fairness state")
		_check(false, "invalid/piece_changed/block_exit clears still work on the new cue")
		mg.queue_free()
		await get_tree().process_frame
		return

	_check(_grain_read_multiplier() > 1.0,
		"the gold mark's XP multiplier is typed placeholder data, not a code literal")

	# --- placement: forced offer, real preflight, three layers, authored gold ---
	mg.debug_force_grain = 1
	mg._spawn_fresh_log()
	await get_tree().process_frame
	_check(mg.debug_has_grain_cue() and mg.debug_grain_plane_valid(),
		"a forced offer places a slicer-valid candidate on a fresh piece")
	_check(mg.debug_grain_top_mark_count() == 3,
		"the mark is three raised layers: dark outline, glow, gold core")
	var grain_cfg: GrainCueDef = GameConfig.current().grain_cue
	var technique := SkillTree.branch_for_proc(&"quick_study")
	_check(mg.debug_grain_cue_color().is_equal_approx(grain_cfg.mark_color),
		"the mark reads the authored gold from game_config.tres, not a code literal")
	_check(technique != null and not mg.debug_grain_cue_color().is_equal_approx(technique.color),
		"the mark's authored gold differs from the Technique branch colour")
	_check(not mg.has_method("debug_grain_overlay_visible")
		and not mg.has_method("debug_grain_cue_copy")
		and mg.get_node_or_null("GrainCueCanvas") == null,
		"no screen-space overlay exists any more — the mark on the wood is the whole tell")

	# --- permanence: the direct regression for the reported "brief pop" bug ---
	var hold_deadline := Time.get_ticks_msec() + 1500   # well past the old 0.8s duration_sec
	while Time.get_ticks_msec() < hold_deadline:
		await get_tree().process_frame
	_check(mg.debug_has_grain_cue(),
		"the mark is PERMANENT — it outlives the old ceiling and any animator settle")
	mg.queue_free()
	await get_tree().process_frame

	# --- no forced turn: the direct regression for the reported "auto turn" bug ---
	# A whole log never trips the cross-axis check (is_whole_log gates it out), so
	# the mark has to sit on a genuine SPLIT piece to exercise the bypass this
	# tests. One unconditional cut (debug_slice_world, no roll involved) leaves
	# real on-block geometry to mark.
	var turn_mg := await _make_quick_study_minigame(true)
	turn_mg.debug_slice_world(Plane(Vector3.RIGHT, 0.0))
	await get_tree().process_frame
	_check(not turn_mg._on_block.is_empty(),
		"(setup) the first split leaves at least one real on-block piece")
	turn_mg.debug_force_grain = 1
	turn_mg._try_show_grain_cue(turn_mg._pick_grain_target(turn_mg._on_block))
	await get_tree().process_frame
	var marked: Area3D = turn_mg._grain_target
	_check(marked != null and not marked.get_meta("is_whole_log", false),
		"(setup) the marked piece is a real split piece, not the whole log")

	# Search the fixed 30-deg orbit grid for a camera angle where THIS piece's
	# cross-axis ratio would normally trip _turn_cross_axis — the same maths
	# _on_click uses, run here only to choose a fair camera angle rather than to
	# duplicate the feature under test.
	var found_yaw := false
	var target_steps := 0
	if marked != null:
		for step in range(12):
			turn_mg._pivot.rotation.y = deg_to_rad(step * turn_mg.camera_step_deg)
			var cam_basis: Basis = turn_mg._camera.global_transform.basis
			var normal: Vector3 = cam_basis.x
			normal.y = 0.0
			var cross: Vector3 = cam_basis.z
			cross.y = 0.0
			if normal.length() < 0.0001 or cross.length() < 0.0001:
				continue
			normal = normal.normalized()
			cross = cross.normalized()
			var along: float = turn_mg._piece_extent_along(marked, normal)
			var across: float = turn_mg._piece_extent_along(marked, cross)
			if across > along * turn_mg.long_axis_bias and across >= turn_mg.min_cut_width:
				found_yaw = true
				target_steps = step
				break
	_check(found_yaw,
		"(setup) the marked piece has a camera angle where the cross-axis turn would normally fire")

	turn_mg._yaw_steps = target_steps
	turn_mg._pivot.rotation.y = deg_to_rad(target_steps * turn_mg.camera_step_deg)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var before_yaw: float = turn_mg._pivot.rotation.y
	var before_xp := GameState.get_xp()
	var screen_pos: Vector2 = turn_mg._camera.unproject_position(
		marked.to_global(turn_mg._grain_local_anchor))
	turn_mg._on_click(screen_pos)
	await get_tree().process_frame
	_check(is_equal_approx(turn_mg._pivot.rotation.y, before_yaw) and turn_mg._axe.is_swinging(),
		"clicking the mark swings at it without ever firing the forced cross-axis turn")

	var resolve_deadline := Time.get_ticks_msec() + 3000
	while turn_mg.debug_has_grain_cue() and Time.get_ticks_msec() < resolve_deadline:
		await get_tree().process_frame
	_check(is_equal_approx(turn_mg._pivot.rotation.y, before_yaw),
		"...and the camera is still exactly where it was once the cut lands")
	_check(turn_mg.debug_grain_clear_reason() == &"consumed",
		"the cut plane is the mark's own preflighted candidate — taking it clears as consumed")
	var species := SpeciesTable.at(0)
	var grain_multiplier := _grain_read_multiplier()
	var expected_bonus := maxi(1, int(round(float(species.xp_reward) * grain_multiplier)))
	_check(turn_mg.debug_last_grain_bonus() == expected_bonus
		and GameState.get_xp() - before_xp >= expected_bonus,
		"the cut lands on the mark: it always splits, banks a multiplied XP bonus (%d), and reads consumed"
			% expected_bonus)
	turn_mg.queue_free()
	await get_tree().process_frame

	# --- reward VFX/orbs, with the economy left on so the whole transaction runs ---
	var reward_mg := await _make_quick_study_minigame(true)
	reward_mg.orbs_enabled = true
	reward_mg.debug_force_grain = 1
	reward_mg._spawn_fresh_log()
	await get_tree().process_frame
	var before_orb_children := 0
	for c in reward_mg.get_children():
		if c is XPOrb:
			before_orb_children += 1
	var before_reward_xp := GameState.get_xp()
	reward_mg._resolve_strike(reward_mg._grain_target, reward_mg._grain_target.global_position,
		Vector3.RIGHT, Enums.ChopDirection.RIGHT, reward_mg._grain_local_plane)
	await get_tree().process_frame
	# Guards the XP-delta check below against a second, unrelated XP transaction:
	# if this one cut happened to empty the block, _award_log_xp (plus this
	# helper's forced Quick Study) would ALSO fire and inflate the delta.
	_check(not reward_mg._on_block.is_empty(),
		"(setup) the gold cut leaves real geometry on the block — no incidental log-completion XP")
	_check(reward_mg.debug_last_proc_burst_color().is_equal_approx(technique.color),
		"the reward's ProcBurst reads Technique green — a proc announcement, not the mark's own gold")
	_check(GameState.get_xp() - before_reward_xp == reward_mg.debug_last_grain_bonus(),
		"the reward's XP write matches its own receipt exactly")
	# Same sqrt(xp) * density shape, just a HIGHER clamp — assert the actual orb
	# count matches the grain-clamped formula, and that it beats what the ROUTINE
	# clamp would have produced for this exact bonus (a fixed >= threshold would
	# be wrong: the two clamp ranges overlap, so "bigger than the biggest routine
	# burst" isn't guaranteed — "bigger than what THIS bonus would routinely get"
	# is the real, provable claim).
	var bonus: int = reward_mg.debug_last_grain_bonus()
	var raw_count := int(round(sqrt(float(bonus)) * reward_mg.orb_density))
	var routine_count := clampi(raw_count, reward_mg.orb_count_min, reward_mg.orb_count_max)
	var grain_count := clampi(raw_count, reward_mg.grain_orb_count_min, reward_mg.grain_orb_count_max)
	var after_orb_children := 0
	for c in reward_mg.get_children():
		if c is XPOrb:
			after_orb_children += 1
	_check(after_orb_children - before_orb_children == grain_count
		and grain_count > routine_count,
		"the gold reward's orb burst (%d) outsizes what this same bonus would get under the routine ceiling (%d)"
			% [grain_count, routine_count])
	reward_mg.queue_free()
	await get_tree().process_frame

	# --- gold swings always split, even against the REAL per-swing chance ---
	# debug_split_roll = 0 deliberately means "the strongest override says fail",
	# per the acceptance matrix's OTHER half below — so proving the bypass has to
	# leave the roll UNFORCED (-1) and call _roll_splits directly, deterministically,
	# rather than rely on a single random trial that might have split anyway.
	var fail_mg := await _make_quick_study_minigame(true)
	fail_mg.debug_split_roll = -1   # the REAL roll — not the helper's forced pass
	fail_mg.debug_force_grain = 1
	fail_mg._spawn_fresh_log()
	await get_tree().process_frame
	var gold_piece: Area3D = fail_mg._grain_target
	_check(gold_piece != null, "(setup) a gold mark is live under the real, unforced split roll")
	_check(fail_mg._roll_splits(gold_piece),
		"a gold swing always splits, bypassing the real per-swing chance entirely")

	# ...and the debug seam stays the STRONGEST override — a suite can still force
	# a failure even on wood that happens to be marked (e.g. to test the scar path).
	fail_mg.debug_split_roll = 0
	_check(not fail_mg._roll_splits(gold_piece),
		"debug_split_roll = 0 still wins over the gold bypass")
	fail_mg.queue_free()
	await get_tree().process_frame

	# --- rarity: never offers when forced off, across several fresh logs ---
	var rare_mg := await _make_quick_study_minigame(true)
	rare_mg.debug_force_grain = 0
	var any_offered := false
	for i in range(6):
		rare_mg._spawn_fresh_log()
		await get_tree().process_frame
		any_offered = any_offered or rare_mg.debug_has_grain_cue()
	_check(not any_offered,
		"debug_force_grain = 0 never offers a mark, across several fresh logs")

	# --- the once-per-log latch: no second mark after the first placement ---
	rare_mg.debug_force_grain = 1
	rare_mg._spawn_fresh_log()
	await get_tree().process_frame
	_check(rare_mg.debug_grain_offer_count() == 1,
		"(setup) exactly one mark placed on this log")
	# The marked whole log IS _on_block[0], so this cut both TAKES the mark (the
	# reward path) and creates fresh split halves — a second piece-creation event
	# on the same log, exactly the moment acceptance item 11 cares about: taking
	# the mark must not reopen the latch for the pieces left behind.
	rare_mg.debug_slice_world(Plane(Vector3.RIGHT, 0.5))
	await get_tree().process_frame
	_check(rare_mg.debug_grain_offer_count() == 1,
		"the offer latches off after the first placement — no second mark, even after taking it")
	rare_mg.queue_free()
	await get_tree().process_frame

	# --- fairness: forced rolls (hit or miss) still spend real ProcResolver state ---
	# Starting from a fresh reset the dry streak is already 0, so proving a FORCED
	# HIT "changed" it is not observable by itself (0 stays 0 on a fire — a fire
	# ERASES the entry). Build a real, nonzero streak with forced MISSES first, so
	# the later forced HIT's reset from nonzero back to 0 is an unambiguous signal
	# that ProcResolver.note_proc_result really ran on the forced path too, not
	# just the real-roll one — the same contract Double Strike and Quick Study hold.
	var fair_mg := await _make_quick_study_minigame(true)
	fair_mg.debug_force_grain = 0
	for i in range(3):
		fair_mg._spawn_fresh_log()
		await get_tree().process_frame
	_check(GameState.get_proc_dry_streak(&"grain_read") >= 3,
		"(setup) forced-off offers on real, preflight-valid pieces still count as dry rolls")
	fair_mg.debug_force_grain = 1
	fair_mg._spawn_fresh_log()
	await get_tree().process_frame
	_check(GameState.get_proc_dry_streak(&"grain_read") == 0 and fair_mg.debug_has_grain_cue(),
		"a forced offer still spends real ProcResolver fairness state — the streak resets on a hit")
	fair_mg.queue_free()
	await get_tree().process_frame

	# --- existing clears: invalid / piece_changed / block_exit still work ---
	var clear_mg := await _make_quick_study_minigame(true)
	clear_mg.debug_force_grain = 1
	clear_mg._spawn_fresh_log()
	await get_tree().process_frame
	clear_mg.debug_invalidate_grain_candidate()
	await get_tree().process_frame
	_check(not clear_mg.debug_has_grain_cue() and clear_mg.debug_grain_clear_reason() == &"invalid",
		"an invalid candidate clears every grain visual immediately")

	clear_mg.debug_force_grain = 1
	clear_mg._spawn_fresh_log()
	await get_tree().process_frame
	clear_mg._spawn_fresh_log()
	await get_tree().process_frame
	_check(clear_mg.debug_grain_clear_reason() == &"piece_changed",
		"fresh-log piece change removes the previous candidate cleanly")
	clear_mg.queue_free()
	await get_tree().process_frame

	var exit_mg := await _make_quick_study_minigame(true)
	exit_mg.debug_force_grain = 1
	exit_mg._spawn_fresh_log()
	await get_tree().process_frame
	_check(exit_mg.debug_has_grain_cue(), "test setup: block-exit cue is live")
	remove_child(exit_mg)   # triggers the real _exit_tree while leaving state inspectable
	_check(not exit_mg.debug_has_grain_cue()
		and exit_mg.debug_grain_clear_reason() == &"block_exit",
		"leaving the chopping block clears the mark through the shared owner")
	exit_mg.free()
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})


# --------------------------------------- M7C Slice 7: Speed vertical (2026-08-05)
## Routes every skill purchase through the REAL GameState.add_xp + SkillTree.buy
## path, same discipline as _grant_double_strike_chain/_grant_quick_study.
func _grant_follow_up() -> void:
	var curve := GameConfig.current().level_curve
	GameState.add_xp(curve.total_xp_for_level(6))
	_check(SkillTree.buy(&"quick_hands") == 1, "test setup: Quick Hands bought")
	_check(SkillTree.buy(&"follow_up") == 1, "test setup: Follow-Up bought")


func _make_follow_up_minigame(owns_skill := true) -> Node3D:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	if owns_skill:
		_grant_follow_up()
	var mg: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	mg.debug_forced_species = 0
	mg.debug_forced_mesh = 0
	mg.debug_split_roll = 1      # the primary swing always cleaves by default — cases override this
	mg.debug_force_proc = 1      # Follow-Up always fires when it is rolled at all
	mg.auto_sell = false
	add_child(mg)
	await get_tree().process_frame
	return mg


## Pure ProcResolver/GameState logic, mirroring
## _test_double_strike_bad_luck_bound_and_persistence exactly: bounded dry-streak
## protection reaches its bound and is guaranteed to fire there, and the streak
## survives a save/load round trip so a reload cannot cheaply reroll it.
func _test_follow_up_bad_luck_bound_and_persistence() -> void:
	GameState.reset_to_defaults()
	var proc_def: ProcDef = M7CContent.procs().by_id(&"follow_up")
	_check(proc_def != null, "test setup: the follow_up proc is registered")
	if proc_def == null:
		return

	for i in range(proc_def.bad_luck_bound - 1):
		var fired: bool = ProcResolver.should_proc(proc_def, 0)   # forced fail; still recorded
		_check(not fired, "forced-fail roll %d of %d does not fire" % [i + 1, proc_def.bad_luck_bound - 1])
	_check(GameState.get_proc_dry_streak(&"follow_up") == proc_def.bad_luck_bound - 1,
		"the dry streak climbed to one short of the bound (%d)" % (proc_def.bad_luck_bound - 1))

	var pity: bool = ProcResolver.should_proc(proc_def)   # a REAL roll, not forced
	_check(pity, "a real roll at the bad-luck bound is guaranteed to fire (pity)")
	_check(GameState.get_proc_dry_streak(&"follow_up") == 0, "...and firing resets the streak")

	for i in range(proc_def.bad_luck_bound - 2):
		ProcResolver.should_proc(proc_def, 0)
	var streak_before := GameState.get_proc_dry_streak(&"follow_up")
	_check(streak_before == proc_def.bad_luck_bound - 2, "rebuilt streak before save (%d)" % streak_before)

	var saved := GameState.to_save_dict()
	GameState.reset_to_defaults()
	_check(GameState.get_proc_dry_streak(&"follow_up") == 0, "a fresh save starts with no streak")
	GameState.apply_save_dict(saved)
	_check(GameState.get_proc_dry_streak(&"follow_up") == streak_before,
		"loading the save restores the exact streak — reload cannot cheaply reroll it")

	GameState.reset_to_defaults()


## Mirrors _test_double_strike_requires_ownership: forcing the proc without
## owning it must never fire, and spending the identical number of points
## entirely off-branch grants nothing either.
func _test_follow_up_requires_ownership() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})

	_check(SkillTree.get_level(&"follow_up") == 0, "test setup: Follow-Up starts unowned")
	var mg := await _make_follow_up_minigame(false)
	var before: int = mg.piece_count()
	mg.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
	await get_tree().process_frame
	_check(mg.debug_last_follow_up_swings() == 0,
		"an unlearned Follow-Up never fires, however hard the proc is forced")
	_check(mg.piece_count() == before + 1, "...only the ordinary root split landed")
	_check(GameState.get_proc_dry_streak(&"follow_up") == 0,
		"...and an unowned proc is never even rolled — no fairness state spent")
	mg.queue_free()
	await get_tree().process_frame
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})

	# The SAME number of points (4), spent entirely in Strength instead.
	# _make_follow_up_minigame() resets GameState internally (same shape as
	# _make_quick_study_minigame), so the purchases have to happen AFTER
	# construction, not before — buying them first would just be wiped.
	var mg2 := await _make_follow_up_minigame(false)
	var curve := GameConfig.current().level_curve
	GameState.add_xp(curve.total_xp_for_level(5))
	_check(SkillTree.buy(&"strong_arms") == 1, "test setup: Strong Arms bought")
	_check(SkillTree.buy(&"double_strike") == 1, "test setup: 4 points spent entirely off-branch")
	_check(SkillTree.get_level(&"follow_up") == 0,
		"spending points off-branch does not grant an unlearned Speed proc")

	var before2: int = mg2.piece_count()
	mg2.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
	await get_tree().process_frame
	_check(mg2.debug_last_follow_up_swings() == 0,
		"...so the identical forced proc still performs zero bonus swings")
	_check(mg2.piece_count() == before2 + 2, "...only the root split and Double Strike's owned cut landed")
	mg2.queue_free()
	await get_tree().process_frame

	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})


## Follow-Up's own defining difference from Double Strike: it rolls on a
## SCARRED root swing, not only a split one, and the bonus swing it spends is a
## REAL roll of its own that can also fail. With debug_split_roll forced to 0,
## every roll in this whole event fails — the root scars, and Follow-Up's own
## bonus swing (targeting the same still-whole piece, since it never left the
## block) scars it a second time rather than cutting it.
func _test_follow_up_fires_on_a_scar_and_can_itself_fail() -> void:
	var mg := await _make_follow_up_minigame(true)
	mg.debug_split_roll = 0
	var before: int = mg.piece_count()
	mg.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
	await get_tree().process_frame
	_check(mg.debug_last_follow_up_swings() == 1,
		"Follow-Up fires on a SCAR, not only on a successful split — unlike Double Strike")
	_check(mg.debug_scar_count() == 2,
		"...the root scar and Follow-Up's own (also forced-fail) bonus swing both mark the same piece")
	_check(mg.piece_count() == before,
		"a bonus SWING can fail too: nothing was cut, the piece is still whole")
	mg.queue_free()
	await get_tree().process_frame
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})


## Both signature procs owned and forced: a root swing may spawn AT MOST one
## chain of EACH kind, but a fired Follow-Up must never spawn a Double Strike
## chain of its own (the is_bonus recursion guard in _resolve_strike). Proven
## by the exact cut count — three, not four — which is the number that would
## grow if the guard were missing, and by each proc's own announcement colour
## surviving to the end of the same event.
func _test_follow_up_does_not_recurse_into_double_strike() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var curve := GameConfig.current().level_curve
	GameState.add_xp(curve.total_xp_for_level(10))
	_check(SkillTree.buy(&"strong_arms") == 1, "test setup: Strong Arms bought")
	_check(SkillTree.buy(&"double_strike") == 1, "test setup: Double Strike bought")
	_check(SkillTree.buy(&"quick_hands") == 1, "test setup: Quick Hands bought")
	_check(SkillTree.buy(&"follow_up") == 1, "test setup: Follow-Up bought")

	var mg: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	mg.debug_forced_species = 0
	mg.debug_split_roll = 1
	mg.debug_force_proc = 1
	mg.auto_sell = false
	add_child(mg)
	await get_tree().process_frame

	var before: int = mg.piece_count()
	mg.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
	await get_tree().process_frame
	_check(mg.debug_last_double_strike_cuts() == 1,
		"the root swing's own Double Strike chain still fires normally")
	_check(mg.debug_last_follow_up_swings() == 1,
		"...and the same root swing's Follow-Up chain fires too — a root swing may spawn ONE of EACH kind")
	_check(mg.piece_count() == before + 3,
		"exactly three real cuts landed this event: the root split, Double Strike's bonus cut, and " +
		"Follow-Up's bonus swing (%d -> %d) — a fourth would mean Follow-Up recursed into its own chain"
			% [before, mg.piece_count()])
	var speed := M7CContent.branches().by_id(&"speed")
	_check(speed != null and mg.debug_last_proc_burst_color().is_equal_approx(speed.color),
		"Follow-Up announces LAST in the event, through ProcBurst in the authored Speed branch colour")
	mg.queue_free()
	await get_tree().process_frame
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})


## Mirrors _test_double_strike_precision_guard's suppression half exactly.
## UNLIKE Double Strike, Follow-Up has no owned-modifier escape today — no
## Speed-side Steady Continuation equivalent exists yet (a Directive 3
## authoring gap this slice flags but does not fill).
func _test_follow_up_precision_guard_has_no_escape() -> void:
	var mg := await _make_follow_up_minigame(true)
	mg.debug_set_precision_guard(true)
	var streak_before := GameState.get_proc_dry_streak(&"follow_up")
	var before: int = mg.piece_count()
	mg.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
	await get_tree().process_frame
	_check(mg.debug_last_follow_up_swings() == 0,
		"the precision guard suppresses Follow-Up even with the proc forced on")
	_check(mg.piece_count() == before + 1,
		"...the base swing itself still landed normally, untouched by the guard")
	_check(GameState.get_proc_dry_streak(&"follow_up") == streak_before,
		"...and suppression spent no fairness state — the roll never happened")
	mg.queue_free()
	await get_tree().process_frame
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})


## A Follow-Up swing that happens to be the one to empty the block must still
## route through the SAME single-root XP transaction as any other completing
## swing — one manual root, exactly once, whichever swing in the chain
## actually finished it.
##
## Built as two separate clicks rather than tuned geometry: the first (default
## min_vol, Follow-Up still unowned) is nothing more than the ordinary "primary
## swing splits the fresh log" setup every other test in this file starts from.
## The second raises min_vol so high that any further split immediately flies
## off as firewood, THEN grants Follow-Up: that click's own root swing consumes
## one of the two remaining halves (both its new pieces fly off, but whichever
## OTHER half from the first click is still on the block, so the log is not yet
## finished) — it is specifically Follow-Up's bonus swing, targeting that last
## remaining half, whose _perform_split is what empties _on_block and fires
## _award_log_xp().
func _test_follow_up_can_complete_a_log() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var mg: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	mg.debug_forced_species = 0
	mg.debug_forced_mesh = 0
	mg.debug_split_roll = 1
	mg.debug_force_proc = 1
	mg.auto_sell = true
	mg.orbs_enabled = false
	add_child(mg)
	await get_tree().process_frame

	mg.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
	await get_tree().process_frame
	_check(mg.cuttable_count() == 2,
		"test setup: the fresh log's primary split leaves two ordinary chunky halves on the block")

	_grant_follow_up()
	mg.min_vol = 1000.0   # from here on, any further split immediately flies off as firewood
	var base: int = SpeciesTable.at(0).xp_reward
	var xp_before := GameState.get_xp()
	mg.debug_swing_world(Plane(Vector3.RIGHT, 0.0))
	await get_tree().process_frame

	_check(mg.cuttable_count() == 0, "the log is fully finished: nothing left on the block")
	_check(mg.debug_last_double_strike_cuts() == 0,
		"test isolation: Double Strike was never granted in this test")
	_check(mg.debug_last_follow_up_swings() == 1,
		"...it was Follow-Up's bonus swing, not the root, that consumed the last remaining half")
	_check(GameState.get_xp() - xp_before == base,
		"exactly one un-multiplied manual root XP award fired (%d), whichever swing in the chain finished the log"
			% base)
	_check(GameState.get_species_mastery_progress(SpeciesTable.at(0).id) == 1,
		"the proc-assisted finish credits exactly one player-started log to mastery")
	_check(mg.debug_last_quick_study_root_id() != &"",
		"the completing transaction still recorded one explicit root event id")

	mg.queue_free()
	await get_tree().process_frame
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})


## Ready Stance (Speed, SkillNodeDef.Effect.CHOP_SPEED) is authored as "fraction
## off the axe's wind-up" — the interval from swing start to the animation's
## contact key — but before this slice nothing outside skill_node_def.gd read
## CHOP_SPEED at all, so a player could spend real skill points on it and get
## nothing. This compares the SAME fixed click's contact_time()/swing_duration()
## at 0 ranks vs 5 (maxed): the wind-up must measurably shorten, and the
## authored post-contact follow-through's OWN duration must NOT change (Ready
## Stance speeds up the drop, never re-times Sam's follow-through keys).
func _test_ready_stance_shortens_the_windup_only() -> void:
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})
	var curve := GameConfig.current().level_curve
	GameState.add_xp(curve.total_xp_for_level(15))
	# Bought ONCE, before EITHER measurement, and never re-bought: Quick Hands
	# is Ready Stance's own prerequisite, but it is ALSO a SWING_SPEED node —
	# owning it changes current_swing_cooldown() and therefore the axe's
	# set_speed() ratio, which would shift BOTH segments of swing_duration(),
	# not just the wind-up. Owning it identically across both runs isolates
	# CHOP_SPEED as the only thing that differs.
	_check(SkillTree.buy(&"quick_hands") == 1, "test setup: Quick Hands bought")

	var mg: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	mg.debug_forced_species = 0
	mg.auto_sell = false
	add_child(mg)
	await get_tree().process_frame
	var axe: Node = mg.get_node_or_null("CameraPivot/Camera3D/AxeViewmodelAnchor")
	_check(axe != null, "test setup: the axe viewmodel is present")
	if axe == null:
		mg.queue_free()
		await get_tree().process_frame
		return
	mg._on_click(Vector2(640.0, 360.0))
	var base_contact: float = axe.contact_time()
	var base_duration: float = axe.swing_duration()
	_check(base_contact > 0.0 and base_duration > base_contact,
		"test setup: the baseline swing (Quick Hands owned, Ready Stance not) has a measurable wind-up and follow-through")
	mg.queue_free()
	await get_tree().process_frame

	for i in range(5):
		SkillTree.buy(&"ready_stance")
	_check(SkillTree.get_level(&"ready_stance") == 5, "test setup: Ready Stance maxed")

	var mg2: Node3D = load("res://scenes/3d_action/chopping_minigame.tscn").instantiate()
	mg2.debug_forced_species = 0
	mg2.auto_sell = false
	add_child(mg2)
	await get_tree().process_frame
	var axe2: Node = mg2.get_node_or_null("CameraPivot/Camera3D/AxeViewmodelAnchor")
	mg2._on_click(Vector2(640.0, 360.0))
	var boosted_contact: float = axe2.contact_time()
	var boosted_duration: float = axe2.swing_duration()
	_check(boosted_contact < base_contact,
		("Ready Stance shortens the wind-up (%.3fs -> %.3fs) — this is the exact " +
			"bug this slice exists to fix: CHOP_SPEED was authored but never read")
			% [base_contact, boosted_contact])
	_check(is_equal_approx(boosted_duration - boosted_contact, base_duration - base_contact),
		"...but leaves the authored post-contact follow-through's OWN duration untouched (%.3fs vs %.3fs)"
			% [boosted_duration - boosted_contact, base_duration - base_contact])
	mg2.queue_free()
	await get_tree().process_frame
	GameState.reset_to_defaults()
	InventoryManager.apply_save_dict({})


## The validator whose absence is exactly how `follow_up` sat dead in shipped
## proc_table.tres data since 2026-08-04: a proc no PROC node names is fully
## "valid" on its own terms (validate_procs is silent) yet can never be bought
## and can never fire. Also proves the SHIPPING data has zero such orphans.
func _test_orphan_proc_validator_rejects_unowned_procs() -> void:
	var orphan_tree := SkillTreeTable.new()
	orphan_tree.nodes = [_test_skill(&"acceptance_unrelated_skill")]
	var orphan_proc := ProcDef.new()
	orphan_proc.id = &"acceptance_orphan_proc"
	orphan_proc.display_name = "Acceptance Orphan"
	orphan_proc.announcement_key = orphan_proc.id
	orphan_proc.presentation_branch_id = &"strength"
	var orphan_table := ProcTable.new()
	orphan_table.procs = [orphan_proc]
	var orphan_errors := M7CContent.validate_skill_tree(
		orphan_tree, M7CContent.branches(), orphan_table)
	_check(_has_error(orphan_errors, "not owned by any skill tree node"),
		"a proc with neither a skill nor equipment source is flagged, not silently accepted")

	var live_errors := M7CContent.validate_all()
	_check(not _has_error(live_errors, "not owned by any skill tree node"),
		"the shipping proc_table.tres/skill_tree.tres data has zero orphaned procs")


func _test_skill(id: StringName) -> SkillNodeDef:
	var node := SkillNodeDef.new()
	node.id = id
	node.display_name = String(id)
	node.description = "test"
	node.branch_id = &"strength"
	node.node_type = SkillNodeDef.NodeType.FOUNDATION
	node.presentation_position = Vector2i.ZERO
	node.max_level = 1
	node.cost = 1
	return node


func _has_error(errors: PackedStringArray, needle: String) -> bool:
	for error: String in errors:
		if error.contains(needle):
			return true
	return false


func _stash_real_save() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if dir.file_exists(_BACKUP_PATH):
		dir.remove(_BACKUP_PATH)
	if dir.file_exists(SaveSystem.SAVE_PATH):
		dir.rename(SaveSystem.SAVE_PATH, _BACKUP_PATH)


func _restore_real_save() -> void:
	SaveSystem.delete_save()
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists(_BACKUP_PATH):
		dir.rename(_BACKUP_PATH, SaveSystem.SAVE_PATH)
